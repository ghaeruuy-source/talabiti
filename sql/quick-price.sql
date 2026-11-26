-- التسعير السريع: الزبون يلصق رابط السلة ← حامد يوصله إشعار (لوحة + واتساب) ← يكتب المجموع ← السعر يطلع للزبون.
-- نُفّذ على Supabase باسم migration: price_requests_and_wa_alerts
-- (نفس النص اللي انطبق على القاعدة؛ مرجع فقط)

create table if not exists public.price_requests (
  id bigint generated always as identity (start with 101) primary key,
  code text not null unique default upper(substr(encode(extensions.gen_random_bytes(5),'hex'),1,8)),
  link text not null,
  phone text not null default '',
  status text not null default 'pending' check (status in ('pending','priced','rejected')),
  total_aed numeric, pieces int,
  admin_note text not null default '',
  used boolean not null default false,
  created_at timestamptz not null default now(),
  priced_at timestamptz
);
create index if not exists price_requests_status_idx on public.price_requests (status, created_at desc);
alter table public.price_requests enable row level security;
drop policy if exists pr_admin on public.price_requests;
create policy pr_admin on public.price_requests for all to authenticated using (public.is_admin()) with check (public.is_admin());
revoke all on public.price_requests from anon;
grant select, update, delete on public.price_requests to authenticated;

create or replace function public.request_price(p_link text, p_phone text default '')
returns table(code text) language plpgsql security definer set search_path to 'public' as $$
declare v_link text := trim(coalesce(p_link,'')); v_phone text := public.norm_phone(p_phone); r public.price_requests;
begin
  if v_link !~* '^https?://([a-z0-9-]+\.)*shein\.(com|top)/' or length(v_link) > 600 then raise exception 'الصق رابط سلتك من شي ان'; end if;
  if v_phone <> '' and v_phone !~ '^07\d{9}$' then raise exception 'رقم الموبايل غير صحيح'; end if;
  if (select count(*) from public.price_requests where created_at > now() - interval '1 hour') > 300 then raise exception 'ضغط طلبات، جرّب بعد شوي'; end if;
  select * into r from public.price_requests p where p.link = v_link and p.status = 'pending' and p.created_at > now() - interval '1 day' limit 1;
  if found then return query select r.code; return; end if;
  return query insert into public.price_requests (link, phone) values (v_link, v_phone) returning price_requests.code;
end $$;

create or replace function public.check_price(p_code text)
returns table(status text, total_aed numeric, pieces int, admin_note text, used boolean)
language sql stable security definer set search_path to 'public' as $$
  select status, total_aed, pieces, admin_note, used from public.price_requests where code = upper(trim(coalesce(p_code,'')))
$$;

create or replace function public.set_price(p_id bigint, p_total_aed numeric, p_pieces int)
returns public.price_requests language plpgsql security definer set search_path to 'public' as $$
declare r public.price_requests;
begin
  if not public.is_admin() then raise exception 'غير مسموح'; end if;
  if coalesce(p_total_aed,0) <= 0 then raise exception 'اكتب مجموع السلة'; end if;
  if coalesce(p_pieces,0) < 1 or p_pieces > 500 then raise exception 'اكتب عدد القطع'; end if;
  update public.price_requests set status='priced', total_aed=round(p_total_aed,2), pieces=p_pieces, priced_at=now()
  where id = p_id returning * into r;
  return r;
end $$;

revoke all on function public.request_price(text,text), public.check_price(text), public.set_price(bigint,numeric,int) from public;
grant execute on function public.request_price(text,text), public.check_price(text) to anon, authenticated;
grant execute on function public.set_price(bigint,numeric,int) to authenticated;

-- الطلب: السلة المسعّرة من حامد تنحسب بالسيرفر (مو من المتصفح)
create or replace function public.place_order(p_name text, p_phone text, p_city text, p_address text, p_note text, p_items jsonb, p_ship_mode text default 'air')
returns table(id bigint, code text) language plpgsql security definer set search_path to 'public' as $function$
declare v_orig numeric := 0; v_sale numeric := 0; it jsonb; v_phone text := public.norm_phone(p_phone); v_o numeric; v_s numeric; pr public.price_requests;
begin
  if length(trim(coalesce(p_name,''))) < 2 then raise exception 'الاسم مطلوب'; end if;
  if v_phone !~ '^07\d{9}$' then raise exception 'رقم الموبايل غير صحيح'; end if;
  if coalesce(p_ship_mode,'air') not in ('air','sea') then raise exception 'طريقة الشحن غير صحيحة'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 40 then
    raise exception 'السلة فارغة أو كبيرة'; end if;
  for it in select * from jsonb_array_elements(p_items) loop
    if coalesce(it->>'link','') !~* '^https?://([a-z0-9-]+\.)*shein\.(com|top)' then raise exception 'رابط غير صحيح'; end if;
    if coalesce((it->>'basket')::boolean, false) then
      if coalesce((it->>'count')::int,0) < 1 or (it->>'count')::int > 500 then raise exception 'عدد قطع السلة غير صحيح'; end if;
      if coalesce(it->>'req','') <> '' then
        select * into pr from public.price_requests p where p.code = upper(it->>'req') and p.status = 'priced' and not p.used for update;
        if found then
          v_orig := v_orig + pr.total_aed; v_sale := v_sale + pr.total_aed;
          update public.price_requests set used = true where price_requests.id = pr.id;
        end if;
      end if;
      continue;
    end if;
    v_o := coalesce(nullif(it->>'orig','')::numeric, 0);
    v_s := coalesce(nullif(it->>'sale','')::numeric, v_o);
    if (it->>'qty')::int < 1 or (it->>'qty')::int > 20 or v_o < 0 or v_s < 0 then raise exception 'بيانات قطعة غير صحيحة'; end if;
    v_orig := v_orig + v_o * (it->>'qty')::int;
    v_sale := v_sale + least(v_s, v_o) * (it->>'qty')::int;
  end loop;
  return query
    insert into public.orders (customer_name, phone, city, address, note, items, orig_aed, sale_aed, ship_mode)
    values (trim(p_name), v_phone, trim(p_city), trim(coalesce(p_address,'')), left(coalesce(p_note,''),500), p_items, v_orig, v_sale, coalesce(p_ship_mode,'air'))
    returning orders.id, orders.code;
end $function$;

-- إشعار واتساب لحامد (CallMeBot). المفتاح بجدول خاص ما ينقرا من المتصفح
create table if not exists public.private_kv (k text primary key, v text not null);
alter table public.private_kv enable row level security;
revoke all on public.private_kv from anon, authenticated;

create or replace function public.set_wa_alert(p_phone text, p_key text)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.is_admin() then raise exception 'غير مسموح'; end if;
  if coalesce(trim(p_key),'') = '' then delete from public.private_kv where k in ('wa_phone','wa_key'); return; end if;
  insert into public.private_kv values ('wa_phone', regexp_replace(p_phone,'\D','','g')), ('wa_key', trim(p_key))
  on conflict (k) do update set v = excluded.v;
end $$;

create or replace function public.wa_alert_status()
returns text language sql stable security definer set search_path to 'public' as $$
  select case when public.is_admin() then (select v from public.private_kv where k='wa_phone' and exists(select 1 from public.private_kv where k='wa_key')) end
$$;

create or replace function public.wa_send(p_text text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare v_phone text; v_key text;
begin
  select v into v_phone from public.private_kv where k='wa_phone';
  select v into v_key from public.private_kv where k='wa_key';
  if v_phone is null or v_key is null then return; end if;
  perform net.http_get(url := 'https://api.callmebot.com/whatsapp.php',
    params := jsonb_build_object('phone', '+'||v_phone, 'text', p_text, 'apikey', v_key));
exception when others then null;
end $$;

create or replace function public.wa_test()
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not public.is_admin() then raise exception 'غير مسموح'; end if;
  perform public.wa_send('✓ إشعارات طلبيتي اشتغلت. يوصلك هنا كل طلب تسعير وكل طلب جديد.');
end $$;

revoke all on function public.set_wa_alert(text,text), public.wa_alert_status(), public.wa_test(), public.wa_send(text) from public, anon;
grant execute on function public.set_wa_alert(text,text), public.wa_alert_status(), public.wa_test() to authenticated;
revoke all on function public.wa_send(text) from authenticated;

create or replace function public.trg_wa_price_request() returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  perform public.wa_send('🔔 طلب تسعير جديد #'||new.id||E'\n'||new.link||case when new.phone<>'' then E'\nرقم الزبون: '||new.phone else '' end||E'\nسعّره من اللوحة.');
  return new;
end $$;
drop trigger if exists wa_price_request on public.price_requests;
create trigger wa_price_request after insert on public.price_requests for each row execute function public.trg_wa_price_request();

create or replace function public.trg_wa_order() returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  perform public.wa_send('🛍️ طلب جديد #'||new.id||' من '||new.customer_name||' ('||new.city||')'||E'\nرقمه: '||new.phone);
  return new;
end $$;
drop trigger if exists wa_order on public.orders;
create trigger wa_order after insert on public.orders for each row execute function public.trg_wa_order();

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='price_requests') then
    alter publication supabase_realtime add table public.price_requests;
  end if;
end $$;
