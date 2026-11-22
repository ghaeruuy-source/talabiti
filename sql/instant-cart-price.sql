-- تسعير فوري للسلة من صورة: الذكاء الاصطناعي يقرا الصورة بالسيرفر، والسعر ينحسب هنا
-- الطلب ينقبل لحاله إذا كل السلال مقروءة من صور والشحن جوي

create table if not exists public.cart_reads (
  id uuid primary key default gen_random_uuid(),
  total numeric not null,
  currency text not null,
  total_aed numeric not null,
  pieces int not null,
  used boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.cart_reads enable row level security;
revoke all on public.cart_reads from anon, authenticated;

create or replace function public.place_order(p_name text, p_phone text, p_city text, p_address text, p_note text, p_items jsonb, p_ship_mode text default 'air')
returns table(id bigint, code text)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_orig numeric := 0; v_sale numeric := 0; it jsonb; v_phone text := public.norm_phone(p_phone);
  v_o numeric; v_s numeric; v_pcs int := 0; v_all boolean := true; v_items jsonb := '[]'::jsonb;
  cr public.cart_reads; v_id bigint; v_code text;
  s public.settings; c public.coupons; v_has_c boolean := false; v_cpn numeric := 0; v_net numeric; v_kg numeric;
  v_goods numeric; v_ship numeric; v_comm numeric; v_tot numeric;
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
      cr := null;
      -- السعر ناخذه من قراءة السيرفر فقط، مو من الرقم اللي يدزه المتصفح
      if coalesce(it->>'read_id','') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        select * into cr from public.cart_reads r
         where r.id = (it->>'read_id')::uuid and not r.used and r.created_at > now() - interval '6 hours'
         for update;
      end if;
      if cr.id is not null then
        update public.cart_reads set used = true where cart_reads.id = cr.id;
        v_orig := v_orig + cr.total_aed; v_sale := v_sale + cr.total_aed; v_pcs := v_pcs + cr.pieces;
        it := it || jsonb_build_object('orig', cr.total_aed, 'sale', cr.total_aed, 'count', cr.pieces,
                                       'read_total', cr.total, 'read_currency', cr.currency);
      else
        v_all := false; v_pcs := v_pcs + (it->>'count')::int;
        it := (it - 'read_id') || jsonb_build_object('orig', 0, 'sale', 0);
      end if;
      v_items := v_items || jsonb_build_array(it);
      continue;
    end if;

    -- قطعة وحدة: سعرها من الزبون، فما ينقبل الطلب تلقائياً
    v_all := false;
    v_o := coalesce(nullif(it->>'orig','')::numeric, 0);
    v_s := coalesce(nullif(it->>'sale','')::numeric, v_o);
    if (it->>'qty')::int < 1 or (it->>'qty')::int > 20 or v_o < 0 or v_s < 0 then raise exception 'بيانات قطعة غير صحيحة'; end if;
    v_orig := v_orig + v_o * (it->>'qty')::int;
    v_sale := v_sale + least(v_s, v_o) * (it->>'qty')::int;
    v_items := v_items || jsonb_build_array(it);
  end loop;

  insert into public.orders (customer_name, phone, city, address, note, items, orig_aed, sale_aed, ship_mode)
  values (trim(p_name), v_phone, trim(p_city), trim(coalesce(p_address,'')), left(coalesce(p_note,''),500), v_items, v_orig, v_sale, coalesce(p_ship_mode,'air'))
  returning orders.id, orders.code into v_id, v_code;

  -- كل السلال مقروءة من صور والشحن جوي: نحسب السعر النهائي ونقبل الطلب
  if v_all and v_sale > 0 and coalesce(p_ship_mode,'air') = 'air' then
    select * into s from public.settings where settings.id = 1;
    select * into c from public.coupons cc where cc.active and cc.min_aed <= v_sale order by cc.pct desc limit 1;
    v_has_c := found;
    if v_has_c then v_cpn := v_sale * c.pct / 100; end if;
    v_net := v_sale - v_cpn;
    v_kg := round(v_pcs * 0.35, 2);
    v_goods := round(v_net * s.rate_aed);
    v_ship := round(v_kg * s.ship_per_kg);
    v_comm := round(v_net * s.rate_aed * s.commission_pct / 100);
    v_tot := v_goods + v_ship + v_comm + s.delivery;
    update public.orders o set
      kg = v_kg, status = 'accepted', quoted_at = now(), accepted_at = now(),
      coupon_code = case when v_has_c then c.code end, coupon_pct = case when v_has_c then c.pct end,
      goods_iqd = v_goods, ship_iqd = v_ship, comm_iqd = v_comm, delivery_iqd = s.delivery,
      total_iqd = v_tot, saved_iqd = round((v_orig - v_net) * s.rate_aed),
      deposit_iqd = round((v_tot * s.deposit_pct / 100) / 1000) * 1000
    where o.id = v_id;
  end if;

  return query select v_id, v_code;
end $function$;

grant execute on function public.place_order(text,text,text,text,text,jsonb,text) to anon, authenticated;

-- تنظيف بقايا الفحص القديم
drop schema if exists dbg cascade;
drop extension if exists pg_net;
