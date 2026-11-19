package com.talabiti.app;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ProgressBar;

public class MainActivity extends Activity {
  static final int SHOP = 1;
  WebView web;
  ProgressBar bar;

  @Override protected void onCreate(Bundle b) {
    super.onCreate(b);
    FrameLayout root = new FrameLayout(this);
    web = new WebView(this);
    bar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
    bar.setIndeterminate(true);
    root.addView(web, new FrameLayout.LayoutParams(-1, -1));
    root.addView(bar, new FrameLayout.LayoutParams(-1, 12));
    setContentView(root);
    Web.setup(web, " TalabitiApp/1.0");
    web.setWebViewClient(new WebViewClient() {
      @Override public boolean shouldOverrideUrlLoading(WebView v, WebResourceRequest r) { return route(r.getUrl()); }
      @Override public void onPageStarted(WebView v, String u, Bitmap f) { bar.setVisibility(View.VISIBLE); }
      @Override public void onPageFinished(WebView v, String u) { bar.setVisibility(View.GONE); }
    });
    if (b != null) web.restoreState(b);
    else web.loadUrl(Web.SITE + sharedQuery(getIntent()));
  }

  boolean route(Uri u) {
    String scheme = u.getScheme() == null ? "" : u.getScheme();
    if (Web.isShein(u.getHost())) { openShop(u.toString()); return true; }
    if (u.toString().startsWith(Web.SITE)) return false;
    try { startActivity(new Intent(Intent.ACTION_VIEW, u)); } catch (Exception ignored) { }
    return true;
  }

  void openShop(String url) {
    Intent i = new Intent(this, ShopActivity.class);
    i.putExtra("url", url);
    startActivityForResult(i, SHOP);
  }

  String sharedQuery(Intent i) {
    if (i != null && Intent.ACTION_SEND.equals(i.getAction())) {
      String t = i.getStringExtra(Intent.EXTRA_TEXT);
      if (t != null) return "?text=" + Uri.encode(t);
    }
    return "";
  }

  @Override protected void onNewIntent(Intent i) {
    super.onNewIntent(i);
    String q = sharedQuery(i);
    if (!q.isEmpty()) web.loadUrl(Web.SITE + q);
  }

  @Override protected void onActivityResult(int req, int res, Intent data) {
    super.onActivityResult(req, res, data);
    if (req == SHOP && res == RESULT_OK && data != null) {
      String q = data.getStringExtra("query");
      if (q != null) web.loadUrl(Web.SITE + "?" + q);
    }
  }

  @Override protected void onSaveInstanceState(Bundle o) { super.onSaveInstanceState(o); web.saveState(o); }

  @Override public void onBackPressed() {
    if (web.canGoBack()) web.goBack(); else super.onBackPressed();
  }
}
