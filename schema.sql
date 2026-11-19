-- طلبيتي: قاعدة بيانات موقع وسيط طلبات شي ان الإمارات
-- الزبون ما يسجل دخول: يرسل طلبه ويتابعه برقم موبايله وكود الطلب، عن طريق دوال آمنة فقط.
-- أبو البيج يسجل دخول (Supabase Auth) وإيميله لازم يكون بجدول admins.

create extension if not exists pgcrypto with schema extensions;

-- الإعدادات (صف واحد)
create table if not exists public.settings (
  id int primary key default 1 check (id = 1),
  shop_name text not null default 'طلبيتي',
  whatsapp text not null default '',
  shein_url text not null default 'https://ar.shein.com/',
  rate_aed numeric not null default 410,        -- دينار لكل درهم
  ship_per_kg numeric not null default 12000,   -- دينار لكل كيلو
  commission_pct numeric not null default 10,
  delivery numeric not null default 5000,
  deposit_pct numeric not null default 30,
  updated_at timestamptz not null default now()
);
insert into public.settings (id) values (1) on conflict do nothing;

create table if not exists public.coupons (
  id bigint generated always as identity primary key,
  code text not null,
  pct numeric not null check (pct > 0 and pct < 100),
  min_aed numeric not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

create table if not exists public.orders (
  id bigint generated always as identity (start with 1001) primary key,
  code text not null unique default upper(substr(encode(extensions.gen_random_bytes(6),'hex'),1,6)),
  customer_name text not null,
  phone text not null,
  city text not null,
  address text not null default '',
  note text not null default '',
  items jsonb not null,                 -- [{link,name,size,qty,orig,sale}]
  orig_aed numeric not null,
  sale_aed numeric not null,
  status text not null default 'pending'
    check (status in ('pending','quoted','accepted','rejected','cancelled')),
  stage int not null default 0 check (stage between 0 and 4),
  kg numeric,
  coupon_code text, coupon_pct numeric,
  goods_iqd numeric, ship_iqd numeric, comm_iqd numeric, delivery_iqd numeric,
  total_iqd numeric, saved_iqd numeric, deposit_iqd numeric,
  deposit_paid boolean not null default false,
  admin_note text not null default '',
  created_at timestamptz not null default now(),
  quoted_at timestamptz, accepted_at timestamptz
);
create index if not exists orders_phone_idx on public.orders (phone);
create index if not exists orders_status_idx on public.orders (status, created_at desc);

-- صلاحيات
alter table public.settings enable row level security;
alter table public.coupons  enable row level security;
alter table public.admins   enable row level security;
alter table public.orders   enable row level security;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as
$$ select exists (select 1 from public.admins where user_id = auth.uid()) $$;

drop policy if exists settings_read on public.settings;
create policy settings_read on public.settings for select using (true);
drop policy if exists settings_admin on public.settings;
create policy settings_admin on public.settings for update using (public.is_admin()) with check (public.is_admin());

drop policy if exists coupons_read on public.coupons;
create policy coupons_read on public.coupons for select using (active or public.is_admin());
drop policy if exists coupons_admin on public.coupons;
create policy coupons_admin on public.coupons for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists admins_self on public.admins;
create policy admins_self on public.admins for select using (user_id = auth.uid());

drop policy if exists orders_admin on public.orders;
create policy orders_admin on public.orders for all using (public.is_admin()) with check (public.is_admin());

-- توحيد رقم الموبايل: 07xxxxxxxxx
create or replace function public.norm_phone(p text) returns text
language sql immutable set search_path = public as $$
  select case
    when d like '9647%' then '0' || substr(d,4)
    when d like '7%' and length(d)=10 then '0' || d
    else d end
  from (select regexp_replace(coalesce(p,''),'\D','','g') as d) x
$$;

-- الزبون يرسل طلب
create or replace function public.place_order(p_name text, p_phone text, p_city text, p_address text, p_note text, p_items jsonb)
returns table (id bigint, code text)
language plpgsql security definer set search_path = public as $$
declare v_orig numeric := 0; v_sale numeric := 0; it jsonb; v_phone text := public.norm_phone(p_phone);
begin
  if length(trim(coalesce(p_name,''))) < 2 then raise exception 'الاسم مطلوب'; end if;
  if v_phone !~ '^07\d{9}$' then raise exception 'رقم الموبايل غير صحيح'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 40 then
    raise exception 'السلة فارغة أو كبيرة'; end if;
  for it in select * from jsonb_array_elements(p_items) loop
    if coalesce(it->>'link','') !~* '^https?://([a-z0-9-]+\.)*shein\.(com|top)' then raise exception 'رابط غير صحيح'; end if;
    if (it->>'qty')::int < 1 or (it->>'qty')::int > 20 or (it->>'orig')::numeric <= 0 then raise exception 'بيانات قطعة غير صحيحة'; end if;
    v_orig := v_orig + (it->>'orig')::numeric * (it->>'qty')::int;
    v_sale := v_sale + least((it->>'sale')::numeric, (it->>'orig')::numeric) * (it->>'qty')::int;
  end loop;
  return query
    insert into public.orders (customer_name, phone, city, address, note, items, orig_aed, sale_aed)
    values (trim(p_name), v_phone, trim(p_city), trim(coalesce(p_address,'')), left(coalesce(p_note,''),500), p_items, v_orig, v_sale)
    returning orders.id, orders.code;
end $$;

-- الزبون يشوف طلباته (برقمه + أكواد طلباته)
create or replace function public.track_orders(p_phone text, p_codes text[])
returns setof public.orders
language sql stable security definer set search_path = public as $$
  select * from public.orders
  where phone = public.norm_phone(p_phone) and code = any(p_codes)
  order by created_at desc limit 50
$$;

-- الزبون يوافق على السعر
create or replace function public.accept_order(p_phone text, p_code text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.orders set status = 'accepted', accepted_at = now()
  where code = p_code and phone = public.norm_phone(p_phone) and status = 'quoted';
  if not found then raise exception 'الطلب غير موجود أو مو بانتظار موافقتك'; end if;
end $$;

-- أبو البيج يسعّر: يحسب كل شي من الإعدادات وأحسن كوبون
create or replace function public.quote_order(p_id bigint, p_kg numeric, p_sale_aed numeric default null)
returns public.orders language plpgsql security definer set search_path = public as $$
declare s public.settings; o public.orders; c public.coupons; v_sale numeric; v_cpn numeric := 0; v_net numeric; r public.orders;
begin
  if not public.is_admin() then raise exception 'غير مسموح'; end if;
  select * into s from public.settings where id = 1;
  select * into o from public.orders where id = p_id for update;
  v_sale := coalesce(p_sale_aed, o.sale_aed);
  select * into c from public.coupons where active and min_aed <= v_sale order by pct desc limit 1;
  if found then v_cpn := v_sale * c.pct / 100; end if;
  v_net := v_sale - v_cpn;
  update public.orders set
    sale_aed = v_sale, kg = p_kg, status = 'quoted', quoted_at = now(),
    coupon_code = c.code, coupon_pct = c.pct,
    goods_iqd = round(v_net * s.rate_aed),
    ship_iqd = round(p_kg * s.ship_per_kg),
    comm_iqd = round(v_net * s.rate_aed * s.commission_pct / 100),
    delivery_iqd = s.delivery,
    total_iqd = round(v_net * s.rate_aed) + round(p_kg * s.ship_per_kg) + round(v_net * s.rate_aed * s.commission_pct / 100) + s.delivery,
    saved_iqd = round((o.orig_aed - v_net) * s.rate_aed),
    deposit_iqd = round(((round(v_net * s.rate_aed) + round(p_kg * s.ship_per_kg) + round(v_net * s.rate_aed * s.commission_pct / 100) + s.delivery) * s.deposit_pct / 100) / 1000) * 1000
  where id = p_id returning * into r;
  return r;
end $$;

revoke all on function public.place_order, public.track_orders, public.accept_order, public.quote_order, public.is_admin from public, anon, authenticated;
grant execute on function public.place_order, public.track_orders, public.accept_order, public.is_admin to anon, authenticated;
grant execute on function public.quote_order to authenticated;

-- بعد ما يسوي أبو البيج حساب من صفحة الإدارة، أضفه كمدير:
-- insert into public.admins (user_id) select id from auth.users where email = 'EMAIL_HERE';

-- تحديث لوحة الإدارة مباشرة لما يوصل طلب جديد
do $$ begin
  alter publication supabase_realtime add table public.orders;
exception when others then null; end $$;
