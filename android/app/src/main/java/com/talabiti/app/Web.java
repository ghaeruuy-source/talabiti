package com.talabiti.app;

import android.webkit.CookieManager;
import android.webkit.WebSettings;
import android.webkit.WebView;

final class Web {
  static final String SITE = "https://ghaeruuy-source.github.io/talabiti/";
  static final String SHEIN = "https://ar.shein.com/";

  static boolean isShein(String host) {
    if (host == null) return false;
    host = host.toLowerCase();
    return host.equals("shein.com") || host.endsWith(".shein.com") || host.equals("shein.top") || host.endsWith(".shein.top");
  }

  static void setup(WebView w, String uaSuffix) {
    WebSettings s = w.getSettings();
    s.setJavaScriptEnabled(true);
    s.setDomStorageEnabled(true);
    s.setDatabaseEnabled(true);
    s.setLoadWithOverviewMode(true);
    s.setUseWideViewPort(true);
    s.setSupportMultipleWindows(false);
    s.setJavaScriptCanOpenWindowsAutomatically(false);
    s.setMediaPlaybackRequiresUserGesture(true);
    // Shein treats the embedded-browser marker differently; present as the regular mobile browser.
    String ua = s.getUserAgentString().replace("; wv)", ")").replaceAll("Version/\\d+\\.\\d+ ", "");
    s.setUserAgentString(ua + uaSuffix);
    CookieManager.getInstance().setAcceptCookie(true);
    CookieManager.getInstance().setAcceptThirdPartyCookies(w, true);
  }
}
