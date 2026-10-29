import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Device verification screen. Opens Xiaomi's notificationUrl in an in-app
/// WebView with the `deviceId` cookie already set (like Mi Fitness does), so the
/// verification binds to THIS device. When it finishes, the server sets the
/// `passportsecurity_ph/slh` cookies; we harvest and return them to retry the
/// login, which then returns securityStatus=0.
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

  static const _accountUrls = [
    'https://account.xiaomi.com',
    'https://api.account.xiaomi.com',
  ];

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
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
    // Watch for the security cookies to appear, in case the final step does not
    // fire an onLoadStop.
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

  Future<void> _checkDone() async {
    if (_done) return;
    final cookies = await _harvest();
    if (cookies.containsKey('passportsecurity_slh') ||
        cookies.containsKey('passportsecurity_ph')) {
      _complete(cookies);
    }
  }

  void _complete(Map<String, String> cookies) {
    if (_done || !mounted) return;
    _done = true;
    _poll?.cancel();
    // Only pass the security cookies; the login adds deviceId itself.
    final security = <String, String>{
      for (final e in cookies.entries)
        if (e.key.startsWith('passportsecurity')) e.key: e.value,
    };
    Navigator.pop(context, security);
  }

  Future<void> _manualContinue() async {
    _complete(await _harvest());
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
          : Column(
              children: [
                Expanded(
                  child: InAppWebView(
                    initialUrlRequest:
                        URLRequest(url: WebUri(widget.notificationUrl)),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      thirdPartyCookiesEnabled: true,
                      cacheEnabled: true,
                    ),
                    onLoadStop: (_, __) => _checkDone(),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton(
                      onPressed: _manualContinue,
                      child: Text(t.verifyDone),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
