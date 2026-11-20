// لمّة تشتغل على نفس قاعدة بيانات طلبيتي
window.LAMMA = {
  SUPABASE_URL: "https://ohrfumsgokfsbqtuqnrn.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ocmZ1bXNnb2tmc2JxdHVxbnJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUxMjA1MzQsImV4cCI6MjExMDY5NjUzNH0.h24Nh01o7fk-afMIZG1Fy3uTHwO1-exO3AOKJAPNOBQ",
  // false = وضع تجريبي (بيانات وهمية بالمتصفح). true بعد تشغيل schema.sql
  LIVE: true,
};
// لوحة لمّة مبنية على لوحة طلبيتي وتقرا نفس الإعدادات
window.TALABITI = { SUPABASE_URL: window.LAMMA.SUPABASE_URL, SUPABASE_ANON_KEY: window.LAMMA.SUPABASE_ANON_KEY };
