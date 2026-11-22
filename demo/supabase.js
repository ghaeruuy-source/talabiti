/* قاعدة بيانات وهمية للنسخة التجريبية: تقلّد واجهة supabase-js وتحفظ بـ localStorage */
(function(){
const KEY="talabiti_demo_v2",USD_AED=3.6725;
const now=Date.now(),ago=h=>new Date(now-h*3600e3).toISOString(),day=d=>new Date(now-d*864e5).toISOString().slice(0,10);
function seed(){return{seq:1006,
 settings:[{id:1,shop_name:"متجرك (تجريبي)",whatsapp:"",shein_url:"https://ar.shein.com/",rate_aed:410,ship_per_kg:15000,ship_sea_per_cbm:350000,commission_pct:10,delivery:5000,deposit_pct:30,updated_at:ago(1)}],
 coupons:[{id:1,code:"SHEIN20",pct:20,min_aed:146.9,active:true,created_at:ago(50)},{id:2,code:"NEW10",pct:10,min_aed:0,active:true,created_at:ago(40)}],
 expenses:[{id:1,title:"شحنة الأسبوع",category:"شحن",amount_iqd:120000,spent_on:day(2),created_at:ago(48)},{id:2,title:"أكياس تغليف",category:"تغليف",amount_iqd:15000,spent_on:day(1),created_at:ago(24)}],
 orders:[
  {id:1001,code:"DEMO01",customer_name:"سارة أحمد",phone:"07701111111",city:"بغداد",address:"المنصور",note:"",items:[{link:"https://ar.shein.com/demo-p-1.html",name:"سلة شي ان كاملة (5 قطعة)",size:"—",qty:1,orig:0,sale:0,img:"",basket:true,count:5}],orig_aed:0,sale_aed:0,status:"pending",stage:0,ship_mode:"air",created_at:ago(2),payments:[],paid_iqd:0,deposit_paid:false,admin_note:""},
  {id:1002,code:"DEMO02",customer_name:"مريم علي",phone:"07702222222",city:"البصرة",address:"العشار",note:"",items:[{link:"https://ar.shein.com/demo-p-2.html",name:"فستان أسود",size:"M",qty:1,orig:120,sale:89,img:""}],orig_aed:120,sale_aed:89,status:"quoted",stage:0,ship_mode:"air",kg:0.5,goods_iqd:36490,ship_iqd:7500,comm_iqd:3649,delivery_iqd:5000,total_iqd:52639,saved_iqd:12710,deposit_iqd:16000,created_at:ago(20),quoted_at:ago(18),payments:[],paid_iqd:0,deposit_paid:false,admin_note:""},
  {id:1003,code:"DEMO03",customer_name:"زينب حسين",phone:"07703333333",city:"بابل",address:"الحلة",note:"",items:[{link:"https://ar.shein.com/demo-p-3.html",name:"سلة شي ان كاملة (8 قطعة)",size:"—",qty:1,orig:0,sale:0,img:"",basket:true,count:8}],orig_aed:300,sale_aed:300,status:"accepted",stage:1,ship_mode:"air",kg:2.8,coupon_code:"SHEIN20",coupon_pct:20,goods_iqd:98400,ship_iqd:42000,comm_iqd:9840,delivery_iqd:5000,total_iqd:155240,saved_iqd:24600,deposit_iqd:47000,created_at:ago(72),quoted_at:ago(70),accepted_at:ago(69),eta:day(-6),payments:[{amount:47000,note:"عربون",date:day(2)}],paid_iqd:47000,deposit_paid:true,admin_note:""},
  {id:1004,code:"DEMO04",customer_name:"نور كريم",phone:"07704444444",city:"النجف",address:"",note:"",items:[{link:"https://ar.shein.com/demo-p-4.html",name:"سلة شي ان كاملة (3 قطعة)",size:"—",qty:1,orig:0,sale:0,img:"",basket:true,count:3}],orig_aed:150,sale_aed:150,status:"accepted",stage:4,ship_mode:"sea",cbm:0.05,goods_iqd:61500,ship_iqd:17500,comm_iqd:6150,delivery_iqd:5000,total_iqd:90150,saved_iqd:0,deposit_iqd:27000,created_at:ago(240),quoted_at:ago(238),accepted_at:ago(237),payments:[{amount:27000,note:"عربون",date:day(9)},{amount:63150,note:"عند الاستلام",date:day(1)}],paid_iqd:90150,deposit_paid:true,admin_note:""}
 ]}}
let D;try{D=JSON.parse(localStorage.getItem(KEY))}catch{}if(!D||!D.orders)D=seed();
const save=ev=>{try{localStorage.setItem(KEY,JSON.stringify(D));if(ev)localStorage.setItem(KEY+"_ev",JSON.stringify({...ev,t:Date.now()}))}catch{}};save();
const clone=x=>JSON.parse(JSON.stringify(x)),ok=d=>({data:d,error:null}),err=m=>({data:null,error:{message:m}});
const norm=p=>{const d=String(p||"").replace(/\D/g,"");return d.startsWith("9647")?"0"+d.slice(3):(d.startsWith("7")&&d.length===10?"0"+d:d)};
class Q{constructor(t){this.t=t;this.op="select";this.f=[];this.o=[];this.n=null;this.one=0}
 select(){if(this.op!=="insert"&&this.op!=="update")this.op="select";return this} insert(r){this.op="insert";this.row=r;return this}
 update(p){this.op="update";this.patch=p;return this} delete(){this.op="delete";return this}
 eq(c,v){this.f.push([c,v]);return this} order(c,o){this.o.push([c,!(o&&o.ascending===false)]);return this}
 limit(n){this.n=n;return this} single(){this.one=1;return this} maybeSingle(){this.one=2;return this}
 then(res,rej){try{res(this.run())}catch(e){rej?rej(e):res(err(e.message))}}
 run(){const t=this.t;
  if(t==="admins")return ok(this.one?{user_id:"demo"}:[{user_id:"demo"}]);
  const tb=D[t];if(!tb)return err("جدول غير موجود");
  const m=r=>this.f.every(([c,v])=>String(r[c])===String(v));
  if(this.op==="insert"){const r={id:Math.max(0,...tb.map(x=>x.id))+1,created_at:new Date().toISOString(),...this.row};if(t==="coupons"&&r.active===undefined)r.active=true;tb.push(r);save({table:t,eventType:"INSERT",new:r});return ok([r])}
  if(this.op==="update"){tb.filter(m).forEach(r=>Object.assign(r,this.patch));save({table:t,eventType:"UPDATE"});return ok(null)}
  if(this.op==="delete"){D[t]=tb.filter(r=>!m(r));save({table:t,eventType:"DELETE"});return ok(null)}
  let rs=tb.filter(m);this.o.slice().reverse().forEach(([c,asc])=>rs.sort((a,b)=>(a[c]>b[c]?1:a[c]<b[c]?-1:0)*(asc?1:-1)));
  if(this.n)rs=rs.slice(0,this.n);rs=clone(rs);
  if(this.one)return rs.length||this.one===2?ok(rs[0]||null):err("ما موجود");return ok(rs)}}
const rpc={
 place_order(a){const ph=norm(a.p_phone);if(String(a.p_name||"").trim().length<2)return err("الاسم مطلوب");if(!/^07\d{9}$/.test(ph))return err("رقم الموبايل غير صحيح");
  let o=0,s=0,pcs=0,all=true;for(const it of a.p_items||[]){const q=+it.qty||1,oo=+it.orig||0;pcs+=it.basket?(+it.count||1):q;if(!(oo>0)){all=false;continue}o+=oo*q;s+=Math.min(+it.sale||oo,oo)*q}
  const id=++D.seq,code=Math.random().toString(16).slice(2,8).toUpperCase();
  const r={id,code,customer_name:a.p_name.trim(),phone:ph,city:a.p_city,address:a.p_address||"",note:a.p_note||"",items:a.p_items,orig_aed:o,sale_aed:s,status:"pending",stage:0,ship_mode:a.p_ship_mode||"air",created_at:new Date().toISOString(),payments:[],paid_iqd:0,deposit_paid:false,admin_note:""};
  D.orders.push(r);
  // سعر نهائي تلقائي: إذا كل القطع مسعّرة والشحن جوي، ينحسب السعر وينقبل الطلب مباشرة
  if(all&&s>0&&r.ship_mode!=="sea"){rpc.quote_order({p_id:id,p_kg:Math.round(pcs*0.35*100)/100,p_sale_aed:s});r.status="accepted";r.accepted_at=r.quoted_at;r.admin_note="";}
  save({table:"orders",eventType:"INSERT",new:r});return ok([{id,code,status:r.status}])},
 track_orders(a){const ph=norm(a.p_phone);return ok(clone(D.orders.filter(r=>r.phone===ph&&(a.p_codes||[]).includes(r.code)).sort((x,y)=>x.created_at<y.created_at?1:-1)))},
 accept_order(a){const r=D.orders.find(r=>r.code===a.p_code&&r.phone===norm(a.p_phone)&&r.status==="quoted");if(!r)return err("الطلب غير موجود أو مو بانتظار موافقتك");r.status="accepted";r.accepted_at=new Date().toISOString();save({table:"orders",eventType:"UPDATE"});return ok(null)},
 quote_order(a){const S=D.settings[0],o=D.orders.find(r=>r.id===a.p_id);if(!o)return err("الطلب غير موجود");
  const sale=a.p_sale_aed!=null?+a.p_sale_aed:+o.sale_aed;if(!(sale>0))return err("اكتب مجموع السلة أول");
  const sea=o.ship_mode==="sea";if(sea&&!(+a.p_cbm>0))return err("اكتب قياسات الشحنة البحرية");
  const c=D.coupons.filter(x=>x.active&&+x.min_aed<=sale).sort((x,y)=>y.pct-x.pct)[0],net=sale-(c?sale*c.pct/100:0),orig=Math.max(+o.orig_aed||0,sale);
  const goods=Math.round(net*S.rate_aed),ship=Math.round(Math.round(sea?a.p_cbm*S.ship_sea_per_cbm:a.p_kg*S.ship_per_kg)*(100-(+o.ship_off_pct||0))/100),comm=Math.round(net*S.rate_aed*S.commission_pct/100),tot=goods+ship+comm+ +S.delivery;
  Object.assign(o,{orig_aed:orig,sale_aed:sale,kg:sea?null:a.p_kg,cbm:sea?a.p_cbm:null,status:"quoted",quoted_at:new Date().toISOString(),coupon_code:c?c.code:null,coupon_pct:c?c.pct:null,goods_iqd:goods,ship_iqd:ship,comm_iqd:comm,delivery_iqd:+S.delivery,total_iqd:tot,saved_iqd:Math.round((orig-net)*S.rate_aed),deposit_iqd:Math.round(tot*S.deposit_pct/100/1000)*1000});
  save({table:"orders",eventType:"UPDATE"});return ok(clone(o))}};
const handlers=[];
window.addEventListener("storage",e=>{if(e.key===KEY){try{D=JSON.parse(e.newValue)}catch{}}if(e.key===KEY+"_ev"){try{const ev=JSON.parse(e.newValue);handlers.forEach(h=>h(ev))}catch{}}});
const session={user:{id:"demo",email:"demo@example.com"}};
window.supabase={createClient(){return{
 from:t=>new Q(t),
 rpc:async(n,a)=>rpc[n]?rpc[n](a||{}):err("دالة غير موجودة"),
 auth:{getSession:async()=>({data:{session}}),signInWithPassword:async()=>({data:{session},error:null}),signOut:async()=>({error:null}),updateUser:async()=>err("بالنسخة التجريبية ما يتغير الحساب.")},
 channel(){const ch={on(_e,_f,h){handlers.push(h);return ch},subscribe(){return ch}};return ch}}}};
window.TALABITI_DEMO_RESET=()=>{localStorage.removeItem(KEY);location.reload()};
document.addEventListener("DOMContentLoaded",()=>{const b=document.createElement("div");
 b.style.cssText="background:#1D1622;color:#fff;font:600 12px/1.4 sans-serif;padding:6px 10px;display:flex;gap:8px;justify-content:center;align-items:center;direction:rtl";
 const other=/admin\.html/.test(location.pathname)?["index.html","صفحة الزبون"]:["admin.html","لوحة صاحب الصفحة"];
 b.innerHTML=`🧪 نسخة تجريبية · <a href="${other[0]}" style="color:#F8BBD0">${other[1]}</a> · <button style="background:none;border:1px solid #fff5;color:#fff;border-radius:6px;padding:2px 8px;font:inherit;cursor:pointer" onclick="TALABITI_DEMO_RESET()">صفّر</button>`;
 document.body.prepend(b)});
})();
