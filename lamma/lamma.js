// طبقة البيانات: Supabase لو LIVE، وإلا وضع تجريبي بالمتصفح
const C = window.LAMMA;
const db = (C.LIVE && window.supabase) ? supabase.createClient(C.SUPABASE_URL, C.SUPABASE_ANON_KEY) : null;
const $ = id => document.getElementById(id);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const iqd = n => Math.round(+n || 0).toLocaleString("en-US") + " د.ع";
const store = { get(k, d) { try { return JSON.parse(localStorage.getItem(k)) ?? d } catch { return d } }, set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)) } catch {} } };
const normPhone = p => { let d = String(p || "").replace(/\D/g, ""); if (d.startsWith("9647")) d = "0" + d.slice(3); else if (d.startsWith("7") && d.length === 10) d = "0" + d; return d };
const LINK_RE = /^https?:\/\/([a-z0-9-]+\.)*shein\.(com|top)/i;
// الزبونة تكتب بالدولار (مثل تطبيق شي ان)، ونخزن بالدرهم حتى يمشي ويا تسعير طلبيتي
const USD_AED = 3.6725;
const usd = i => "$" + (+(i.usd ?? (+i.sale / USD_AED))).toFixed(2).replace(/\.00$/, "");
const STAGES = ["انطلب من شي ان", "بالطريق للعراق", "وصل المخزن", "بالتوصيل", "تسلّم"];

// الإعدادات تجي من جدول settings مال طلبيتي (الأرقام الافتراضية تقديرية)
let S = { rate_aed: 462.9, ship_per_kg: 15000, ship_sea_per_cbm: 350000, lamma_half_at: 150000, lamma_free_at: 300000, lamma_hours: 48, whatsapp: "" };
const toIqd = aed => Math.round((+aed || 0) * S.rate_aed / 250) * 250;
const tiers = () => [
  { at: 0, pct: 0, label: "شحن عادي" },
  { at: +S.lamma_half_at, pct: 50, label: "الشحن بالنص" },
  { at: +S.lamma_free_at, pct: 100, label: "شحن مجاني" }];
function tierOf(total) { let t = tiers()[0]; for (const x of tiers()) if (total >= x.at) t = x; return t }
function nextTier(total) { return tiers().find(x => x.at > total) || null }
const shipEst = pct => Math.round(S.ship_per_kg * (100 - pct) / 100); // تقدير: كيلو لكل وحدة
function groupTotal(members) { return members.reduce((a, m) => a + toIqd(m.sale_aed), 0) }
function timeLeft(l) { const ms = new Date(l.closes_at) - Date.now(); if (ms <= 0) return "انقفلت"; const h = Math.floor(ms / 36e5), m = Math.floor(ms % 36e5 / 6e4); return h ? `${h} ساعة و${m} دقيقة` : `${m} دقيقة` }
const code6 = () => Math.random().toString(36).slice(2, 8).toUpperCase();
const err = e => (e && (e.message || e.error_description)) || "صار خطأ، جربي مرة ثانية.";

// ---------- وضع تجريبي ----------
const demo = {
  all() { let d = store.get("lamma_demo4", null); if (!d) { d = seed(); store.set("lamma_demo4", d) } return d },
  save(d) { store.set("lamma_demo4", d) },
};
function seed() {
  const now = Date.now(), H = 36e5;
  const mk = (code, title, owner, city, hAgo, status, members) => ({ code, title, owner_name: owner, city, status, created_at: new Date(now - hAgo * H).toISOString(), closes_at: new Date(now - hAgo * H + 48 * H).toISOString(), members });
  const m = (name, phone, items) => ({ name, phone, address: "", items, sale_aed: items.reduce((a, i) => a + i.sale * i.qty, 0), created_at: new Date().toISOString() });
  const it = (name, u, size = "M", qty = 1) => ({ link: "https://ar.shein.com/item-p-" + Math.floor(Math.random() * 9e6) + ".html", name, usd: u, sale: +(u * USD_AED).toFixed(2), size, qty });
  const bag = (n, u) => ({ link: "https://m.shein.com/ar/cart/share?code=" + code6(), name: `سلة شي ان (${n} قطعة)`, size: "—", qty: 1, count: n, usd: u, sale: +(u * USD_AED).toFixed(2), basket: true });
  return { orders: [], lammas: [
    mk("BNT7Q2", "لمّة بنات الكلية", "زينب", "بغداد", 20, "open", [
      m("زينب", "07701234567", [bag(3, 36)]), m("مريم", "07801112233", [it("بلوزة ستان", 14, "S"), it("بنطرون واسع", 19, "S")]), m("نور", "07507778899", [it("كارديكن", 20, "L")])]),
    mk("ARB9K1", "لمّة العيد", "سارة", "البصرة", 30, "open", [
      m("سارة", "07709998877", [bag(2, 33)]), m("هبة", "07812223344", [it("حذاء رياضي", 30, "38"), it("جواريب ×5", 5, "-")]),
      m("رسل", "07723334455", [bag(2, 31)]), m("آية", "07734445566", [it("جاكيت جينز", 26, "M")]), m("دعاء", "07745556677", [bag(4, 38)])]),
    mk("FAM3X8", "لمّة العائلة", "أم علي", "أربيل", 70, "locked", [
      m("أم علي", "07750001122", [it("ملابس أطفال ×3", 23, "4Y")]), m("فاطمة", "07761112233", [it("عباية", 33, "52")])]),
  ] };
}

const api = {
  async settings() {
    if (!db) return;
    const { data } = await db.from("settings").select("*").eq("id", 1).single();
    if (data) S = { ...S, ...data };
  },
  async create({ title, name, phone, city }) {
    if (db) { const { data, error } = await db.rpc("create_lamma", { p_title: title, p_name: name, p_phone: phone, p_city: city }); if (error) throw error; return data }
    const d = demo.all(), code = code6(), now = Date.now();
    d.lammas.unshift({ code, title, owner_name: name, owner_phone: normPhone(phone), city, status: "open", created_at: new Date(now).toISOString(), closes_at: new Date(now + S.lamma_hours * 36e5).toISOString(), members: [] });
    demo.save(d); return code;
  },
  async get(code, phone) {
    if (db) { const { data, error } = await db.rpc("get_lamma", { p_code: code, p_phone: phone || null }); if (error) throw error; return data }
    const l = demo.all().lammas.find(x => x.code === code); if (!l) return null;
    return { ...l, members: l.members.map(m => ({ name: m.name, sale_aed: m.sale_aed, n: m.items.reduce((a, i) => a + (+i.count || i.qty), 0), mine: m.phone === normPhone(phone) })) };
  },
  async join(code, { name, phone, address, ship, items }) {
    if (db) { const { error } = await db.rpc("join_lamma", { p_code: code, p_name: name, p_phone: phone, p_address: address, p_items: items, p_ship_mode: ship }); if (error) throw error; return }
    const d = demo.all(), l = d.lammas.find(x => x.code === code); if (!l || l.status !== "open") throw new Error("اللمّة مقفولة");
    const ph = normPhone(phone), sale = items.reduce((a, i) => a + i.sale * i.qty, 0);
    const ex = l.members.find(m => m.phone === ph);
    if (ex) { ex.items.push(...items); ex.sale_aed += sale; ex.ship_mode = ship } else l.members.push({ name, phone: ph, address, ship_mode: ship, items, sale_aed: sale, created_at: new Date().toISOString() });
    demo.save(d);
  },
  async myOrders(phone, codes) {
    if (!phone || !codes.length) return [];
    if (db) { const { data, error } = await db.rpc("my_lamma_orders", { p_phone: phone, p_codes: codes }); if (error) throw error; return data || [] }
    return demo.all().orders.filter(o => o.phone === normPhone(phone) && codes.includes(o.lamma_code));
  },
  async accept(phone, code) {
    if (db) { const { error } = await db.rpc("accept_order", { p_phone: phone, p_code: code }); if (error) throw error; return }
    const d = demo.all(), o = d.orders.find(x => x.code === code); o.status = "accepted"; demo.save(d);
  },
  // للأدمن
  async list() {
    if (db) { const { data, error } = await db.from("lammas").select("*, members:lamma_members(*)").order("created_at", { ascending: false }); if (error) throw error; return data }
    return demo.all().lammas;
  },
  async lock(code) {
    if (db) { const { data, error } = await db.rpc("lock_lamma", { p_code: code }); if (error) throw error; return data }
    const d = demo.all(), l = d.lammas.find(x => x.code === code), pct = tierOf(groupTotal(l.members)).pct;
    l.status = "locked"; l.ship_off_pct = pct;
    l.members.forEach((m, i) => d.orders.push({ id: 2000 + d.orders.length, code: code6(), customer_name: m.name, phone: m.phone, items: m.items, sale_aed: m.sale_aed, lamma_code: code, ship_off_pct: pct, ship_mode: m.ship_mode || "air", status: "pending", stage: 0, note: `🛍️ لمّة «${l.title}»` }));
    demo.save(d); return l.members.length;
  },
  async cancel(code) {
    if (db) { const { error } = await db.from("lammas").update({ status: "cancelled" }).eq("code", code); if (error) throw error; return }
    const d = demo.all(); d.lammas.find(x => x.code === code).status = "cancelled"; demo.save(d);
  },
  async saveSettings(v) {
    if (db) { const { error } = await db.from("settings").update(v).eq("id", 1); if (error) throw error }
    S = { ...S, ...v };
  },
};
