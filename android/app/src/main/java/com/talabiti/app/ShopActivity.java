package com.talabiti.app;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.util.JsonReader;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.StringReader;

public class ShopActivity extends Activity {
  static final int PINK = Color.parseColor("#C2185B");
  WebView web;
  ProgressBar bar;
  Button add;

  // Reads the product the customer is looking at: name, image and prices from the page's own metadata.
  static final String EXTRACT =
    "(function(){try{" +
    "function m(p){var e=document.querySelector('meta[property=\"'+p+'\"],meta[name=\"'+p+'\"]');return e?e.content:''}" +
    "function n(t){t=(t||'').replace(/,/g,'');var r=t.match(/\\d+(\\.\\d+)?/);return r?r[0]:''}" +
    "var name=m('og:title')||document.title,img=m('og:image'),sale=n(m('product:price:amount')),orig='';" +
    "document.querySelectorAll('script[type=\"application/ld+json\"]').forEach(function(s){try{var j=JSON.parse(s.textContent);(Array.isArray(j)?j:[j]).forEach(function(o){if(o&&o['@type']==='Product'){name=o.name||name;img=(Array.isArray(o.image)?o.image[0]:o.image)||img;var f=Array.isArray(o.offers)?o.offers[0]:o.offers;if(f&&f.price)sale=n(String(f.price));}})}catch(e){}});" +
    "if(!sale){var el=document.querySelector('.product-intro__head-mainprice .from,[class*=\"mainprice\"] [class*=\"from\"],[class*=\"sale-price\"],[class*=\"productPrice\"]');if(el)sale=n(el.textContent);}" +
    "var d=document.querySelector('.product-intro__head-mainprice del,[class*=\"del-price\"],[class*=\"retail\"] del,del');if(d)orig=n(d.textContent);" +
    "var sz='';var a=document.querySelector('[class*=\"size-radio\"][class*=\"active\"],[class*=\"sizes-item\"][class*=\"active\"],[class*=\"size\"] [aria-checked=\"true\"]');if(a)sz=(a.textContent||'').trim().slice(0,20);" +
    "return JSON.stringify({url:location.href,name:name,img:img,sale:sale,orig:orig,size:sz});" +
    "}catch(e){return JSON.stringify({url:location.href})}})()";

  int dp(int v) { return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, getResources().getDisplayMetrics()); }

  @Override protected void onCreate(Bundle b) {
    super.onCreate(b);
    LinearLayout col = new LinearLayout(this);
    col.setOrientation(LinearLayout.VERTICAL);

    LinearLayout top = new LinearLayout(this);
    top.setBackgroundColor(PINK);
    top.setGravity(Gravity.CENTER_VERTICAL);
    top.setPadding(dp(12), dp(8), dp(12), dp(8));
    TextView title = new TextView(this);
    title.setText("تسوّق من شي ان");
    title.setTextColor(Color.WHITE);
    title.setTextSize(16);
    Button back = new Button(this);
    back.setText("رجوع لطلبيتي");
    back.setAllCaps(false);
    back.setTextColor(PINK);
    GradientDrawable wb = new GradientDrawable(); wb.setColor(Color.WHITE); wb.setCornerRadius(dp(20));
    back.setBackground(wb);
    back.setPadding(dp(14), 0, dp(14), 0);
    back.setOnClickListener(v -> finish());
    top.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
    top.addView(back, new LinearLayout.LayoutParams(-2, dp(36)));

    FrameLayout frame = new FrameLayout(this);
    web = new WebView(this);
    bar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
    bar.setIndeterminate(true);
    add = new Button(this);
    add.setText("＋ أضف لطلبي");
    add.setAllCaps(false);
    add.setTextColor(Color.WHITE);
    add.setTextSize(17);
    GradientDrawable pb = new GradientDrawable(); pb.setColor(PINK); pb.setCornerRadius(dp(28));
    add.setBackground(pb);
    add.setElevation(dp(8));
    add.setPadding(dp(28), 0, dp(28), 0);
    add.setOnClickListener(v -> grab());
    FrameLayout.LayoutParams ap = new FrameLayout.LayoutParams(-2, dp(56), Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
    ap.bottomMargin = dp(84);
    frame.addView(web, new FrameLayout.LayoutParams(-1, -1));
    frame.addView(bar, new FrameLayout.LayoutParams(-1, 10));
    frame.addView(add, ap);

    col.addView(top, new LinearLayout.LayoutParams(-1, -2));
    col.addView(frame, new LinearLayout.LayoutParams(-1, 0, 1));
    setContentView(col);

    Web.setup(web, "");
    web.setWebViewClient(new WebViewClient() {
      @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) {
        Uri u = r.getUrl();
        String s = u.getScheme() == null ? "" : u.getScheme();
        if (!s.equals("http") && !s.equals("https")) return true; // ignore app deep links (intent://, sheinlink://)
        return false;
      }
      @Override public void onPageStarted(WebView v, String u, Bitmap f) { bar.setVisibility(View.VISIBLE); }
      @Override public void onPageFinished(WebView v, String u) { bar.setVisibility(View.GONE); }
    });
    String url = getIntent().getStringExtra("url");
    if (b != null) web.restoreState(b); else web.loadUrl(url != null ? url : Web.SHEIN);
  }

  static boolean isProduct(String url) {
    return url != null && (url.matches(".*-p-\\d+.*") || url.contains("/goods") || url.contains("goods_id"));
  }

  void grab() {
    String url = web.getUrl();
    if (!isProduct(url)) {
      Toast.makeText(this, "افتح صفحة القطعة أول، بعدين اضغط «أضف لطلبي»", Toast.LENGTH_LONG).show();
      return;
    }
    web.evaluateJavascript(EXTRACT, raw -> {
      try {
        JsonReader r = new JsonReader(new StringReader(raw));
        r.setLenient(true);
        JSONObject o = new JSONObject(r.nextString());
        StringBuilder q = new StringBuilder("app=1");
        String[] keys = {"url", "name", "img", "sale", "orig", "size"};
        for (String k : keys) {
          String v = o.optString(k, "");
          if (k.equals("url") && v.isEmpty()) v = url;
          if (!v.isEmpty()) q.append('&').append(k.equals("url") ? "link" : k).append('=').append(Uri.encode(v));
        }
        Intent res = new Intent();
        res.putExtra("query", q.toString());
        setResult(RESULT_OK, res);
        finish();
      } catch (Exception e) {
        Intent res = new Intent();
        res.putExtra("query", "app=1&link=" + Uri.encode(url));
        setResult(RESULT_OK, res);
        finish();
      }
    });
  }

  @Override protected void onSaveInstanceState(Bundle o) { super.onSaveInstanceState(o); web.saveState(o); }

  @Override public void onBackPressed() {
    if (web.canGoBack()) web.goBack(); else super.onBackPressed();
  }
}
