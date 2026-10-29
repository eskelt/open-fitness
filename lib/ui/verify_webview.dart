import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Device verification screen. Opens Xiaomi's notificationUrl in an in-app
/// WebView with the `deviceId` cookie already set (like Mi Fitness does), so the
/// verification binds to THIS device.
///
/// What actually happens (observed on a real new-device run): after the 2FA code
/// is accepted the flow goes authStart -> verifyEmail -> an STS URL
/// (`sts-hlth.io.mi.com/.../sts`) whose body is `ok`, and at that point the
/// `passToken`/`passInfo`/`userId`/`cUserId` cookies appear on account.xiaomi.com
/// (there is NO `passportsecurity_*` cookie in this flow). Once `passToken`
/// exists the device is verified, so retrying serviceLoginAuth2 with those
/// cookies returns securityStatus=0 + ssecurity.
///
/// Completion is detected automatically, so the user never taps anything after
/// entering the code: the `passToken` cookie appearing (polled + on every
/// navigation) is the primary signal, backed by the STS/`ok` success page and
/// the `login-end`/`auth-end` end URLs. The WebView then closes itself and the
/// login retry runs on its own.
class VerifyWebView extends StatefulWidget {
  final String notificationUrl;
  final String deviceId;
  const VerifyWebView({
    super.key,
    required this.notificationUrl,
    required this.deviceId,
  });

  @override
  State<VerifyWebView> createState() => _VerifyWebViewState();
}

class _VerifyWebViewState extends State<VerifyWebView> {
  final _cm = CookieManager.instance();
  bool _ready = false;
  bool _done = false;
  Timer? _poll;

  // Hosts the passportsecurity cookies may be scoped to. The notificationUrl's
  // origin and every visited page's origin are added at runtime, so a
  // regional/unknown host is covered too.
  final _accountUrls = <String>{
    'https://account.xiaomi.com',
    'https://api.account.xiaomi.com',
  };

  @override
  void initState() {
    super.initState();
    _accountUrls.add(_origin(widget.notificationUrl));
    _prepare();
  }

  String _origin(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.host.isEmpty) return url;
    return '${u.scheme}://${u.host}';
  }

  Future<void> _prepare() async {
    // Start from a clean cookie jar. Otherwise a passToken left over from a
    // previous verification (e.g. another account) would be detected instantly
    // and complete the flow without the user actually verifying anything.
    try {
      await _cm.deleteAllCookies();
    } catch (_) {}
    // Set the deviceId cookie on the account domain before loading, so the
    // verification is associated with this device.
    for (final domain in ['.xiaomi.com', '.account.xiaomi.com']) {
      await _cm.setCookie(
        url: WebUri('https://account.xiaomi.com'),
        name: 'deviceId',
        value: widget.deviceId,
        domain: domain,
        path: '/',
        isSecure: true,
      );
    }
    if (mounted) setState(() => _ready = true);
    // Backstop poll, in case the final step does not fire a navigation event.
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _checkDone());
  }

  Future<Map<String, String>> _harvest() async {
    final out = <String, String>{};
    for (final u in _accountUrls) {
      try {
        final cs = await _cm.getCookies(url: WebUri(u));
        for (final c in cs) {
          out[c.name] = c.value.toString();
        }
      } catch (_) {}
    }
    return out;
  }

  /// A URL that marks the end of the verification flow (same signals Mi Fitness
  /// watches for in CookieLoginUrlInterceptor).
  bool _isEndUrl(String? url) {
    if (url == null) return false;
    final u = url.toLowerCase();
    return u.contains('login-end') ||
        u.contains('auth-end') ||
        u.contains('passinfo=login-end');
  }

  /// The success payload Xiaomi shows once the code is accepted: the STS page
  /// body is basically `ok` (seen on a real run), sometimes `0`/`{"code":0}`.
  bool _isSuccessBody(String body) {
    final b = body.trim().toLowerCase();
    if (b.isEmpty || b.length > 400) return false;
    if (b == 'ok' || b == '0') return true;
    final compact = b.replaceAll(' ', '');
    return compact.contains('"code":0') || compact.contains("'code':0");
  }

  /// The STS success hop, e.g. https://sts-hlth.io.mi.com/healthapp/sts?...
  bool _isStsUrl(String? url) =>
      url != null && url.toLowerCase().contains('/sts');

  /// The credential cookies that mean verification succeeded and that the login
  /// retry needs. `passToken` is the definitive signal; the others ride along.
  static const _credKeys = {'passToken', 'passInfo', 'cUserId', 'userId'};

  bool _hasCreds(Map<String, String> c) =>
      c.containsKey('passToken') ||
      c.containsKey('passportsecurity_slh') ||
      c.containsKey('passportsecurity_ph');

  /// Called for every page load. Reads the body, widens the cookie hosts with
  /// the current origin, and completes if any success signal is present.
  Future<void> _onPage(InAppWebViewController c, String? url) async {
    if (_done) return;
    if (url != null) _accountUrls.add(_origin(url));
    String body = '';
    try {
      final r = await c.evaluateJavascript(
          source:
              "(document.body&&document.body.innerText)?document.body.innerText:''");
      if (r is String) body = r;
    } catch (_) {}
    final success = _isEndUrl(url) || _isSuccessBody(body);
    await _checkDone(url: url, successPage: success);
  }

  Future<void> _checkDone({String? url, bool successPage = false}) async {
    if (_done) return;
    var cookies = await _harvest();
    if (_hasCreds(cookies)) {
      _complete(cookies);
      return;
    }
    if (successPage || _isEndUrl(url) || _isStsUrl(url)) {
      // Verification signalled success but the cookies are not visible yet.
      // Retry the harvest a few times, widening with the current origin.
      for (var i = 0; i < 6 && !_hasCreds(cookies); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        cookies = await _harvest();
      }
      if (_hasCreds(cookies)) _complete(cookies);
    }
  }

  void _complete(Map<String, String> cookies) {
    if (_done || !mounted) return;
    _done = true;
    _poll?.cancel();
    // Pass the credential cookies the login retry needs (passToken is the key
    // one); the login adds the deviceId itself. passportsecurity_* is kept too
    // in case another region's flow uses it.
    final creds = <String, String>{
      for (final e in cookies.entries)
        if (_credKeys.contains(e.key) || e.key.startsWith('passportsecurity'))
          e.key: e.value,
    };
    Navigator.pop(context, creds);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.verifyTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : InAppWebView(
              initialUrlRequest:
                  URLRequest(url: WebUri(widget.notificationUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                thirdPartyCookiesEnabled: true,
                cacheEnabled: true,
              ),
              onLoadStop: (c, url) => _onPage(c, url?.toString()),
              onUpdateVisitedHistory: (c, url, __) =>
                  _onPage(c, url?.toString()),
            ),
    );
  }
}
