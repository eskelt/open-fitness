import 'dart:convert';
import 'package:http/http.dart' as http;
import 'crypto.dart';

/// Result of a successful login against Xiaomi Passport (sid=miothealth).
class XiaomiSession {
  final String ssecurity; // base64, key used to sign/encrypt
  final String cUserId;
  final String userId;
  final String passToken;
  final String serviceToken;
  final String region; // data-center code: cn/de/sg/in/ru/i2...

  XiaomiSession({
    required this.ssecurity,
    required this.cUserId,
    required this.userId,
    required this.passToken,
    required this.serviceToken,
    required this.region,
  });

  Map<String, dynamic> toJson() => {
        'ssecurity': ssecurity,
        'cUserId': cUserId,
        'userId': userId,
        'passToken': passToken,
        'serviceToken': serviceToken,
        'region': region,
      };

  factory XiaomiSession.fromJson(Map<String, dynamic> j) => XiaomiSession(
        ssecurity: j['ssecurity'],
        cUserId: j['cUserId'],
        userId: j['userId'],
        passToken: j['passToken'],
        serviceToken: j['serviceToken'],
        region: j['region'],
      );
}

/// Thrown when Xiaomi requires verifying the device (e.g. by email).
/// Carries the notification URL that must be opened in a WebView with the
/// deviceId cookie, so the verification binds to THIS device.
class XiaomiVerificationRequired implements Exception {
  final String notificationUrl;
  XiaomiVerificationRequired(this.notificationUrl);
  @override
  String toString() =>
      'Verification required. Confirm the sign-in:\n$notificationUrl';
}

class XiaomiLoginException implements Exception {
  final String message;
  XiaomiLoginException(this.message);
  @override
  String toString() => message;
}

/// Password login against Xiaomi Passport. Replicates XMPassport.loginByPassword
/// from Mi Fitness 3.59.1i. The password is only used for the local MD5; it is
/// never stored.
class XiaomiLogin {
  static const _sid = 'miothealth';
  final String deviceId;

  XiaomiLogin({required this.deviceId});

  /// [extraCookies] are added next to the deviceId cookie in serviceLoginAuth2.
  /// After passing verification in the WebView, the login is retried with the
  /// credential cookies it left behind (passToken/passInfo/userId/cUserId),
  /// which makes the server return securityStatus=0 + ssecurity.
  Future<XiaomiSession> login(String user, String password,
      {String region = 'de', Map<String, String> extraCookies = const {}}) async {
    final client = http.Client();
    try {
      // --- 1. serviceLoginAuth2 ---
      final hash = md5UpperHex(password);
      final cookiePairs = <String, String>{'deviceId': deviceId, ...extraCookies};
      final cookieHeader =
          cookiePairs.entries.map((e) => '${e.key}=${e.value}').join('; ');
      final resp = await client.post(
        Uri.parse('https://account.xiaomi.com/pass/serviceLoginAuth2'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Cookie': cookieHeader,
        },
        body: {
          'user': user,
          'hash': hash,
          'sid': _sid,
          '_json': 'true',
        },
      );
      final raw = resp.body;
      final jsonStr =
          raw.startsWith('&&&START&&&') ? raw.substring(11) : raw;
      final Map<String, dynamic> m = json.decode(jsonStr);

      // securityStatus != 0 => the device must be verified. Xiaomi prepends
      // account.xiaomi.com when the url is not absolute (see XMPassport).
      final securityStatus = m['securityStatus'] ?? 0;
      if (m['notificationUrl'] != null && securityStatus != 0) {
        var url = m['notificationUrl'].toString();
        if (!url.startsWith('http')) {
          url = 'https://account.xiaomi.com$url';
        }
        throw XiaomiVerificationRequired(url);
      }
      final code = m['code'];
      if (code != 0) {
        throw XiaomiLoginException(
            'Login failed (code=$code): ${m['description'] ?? m['desc'] ?? raw}');
      }
      if (securityStatus != 0) {
        throw XiaomiLoginException('securityStatus=$securityStatus (no 0)');
      }

      final ssecurity = m['ssecurity'] as String;
      final cUserId = (m['cUserId'] ?? '').toString();
      final userId = (m['userId'] ?? '').toString();
      final passToken = (m['passToken'] ?? '').toString();
      final location = m['location'] as String?;
      if (location == null || location.isEmpty) {
        throw XiaomiLoginException('No location in the login response');
      }

      // --- 2. follow location (STS) and capture the serviceToken cookie ---
      final serviceToken =
          await _followForServiceToken(client, location, deviceId);
      if (serviceToken == null) {
        throw XiaomiLoginException(
            'Did not obtain serviceToken when following the STS URL');
      }

      return XiaomiSession(
        ssecurity: ssecurity,
        cUserId: cUserId,
        userId: userId,
        passToken: passToken,
        serviceToken: serviceToken,
        region: region,
      );
    } finally {
      client.close();
    }
  }

  /// Follows the STS redirect chain accumulating cookies, and returns the
  /// serviceToken cookie value.
  Future<String?> _followForServiceToken(
      http.Client client, String startUrl, String deviceId) async {
    final cookies = <String, String>{'deviceId': deviceId};
    var url = Uri.parse(startUrl);
    for (var hop = 0; hop < 10; hop++) {
      final cookieHeader =
          cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
      final req = http.Request('GET', url)..followRedirects = false;
      req.headers['Cookie'] = cookieHeader;
      final streamed = await client.send(req);
      await streamed.stream.drain();
      _collectCookies(streamed.headers['set-cookie'], cookies);
      if (cookies.containsKey('serviceToken')) return cookies['serviceToken'];
      final loc = streamed.headers['location'];
      if (streamed.isRedirect && loc != null) {
        url = loc.startsWith('http') ? Uri.parse(loc) : url.resolve(loc);
        continue;
      }
      break;
    }
    return cookies['serviceToken'];
  }

  /// Parses a Set-Cookie header (which package:http joins with commas) into
  /// name=value pairs. A lenient parse, good enough for serviceToken.
  void _collectCookies(String? setCookie, Map<String, String> into) {
    if (setCookie == null) return;
    for (final part in setCookie.split(RegExp(r',(?=[^ ;]+=)'))) {
      final seg = part.split(';').first.trim();
      final eq = seg.indexOf('=');
      if (eq > 0) {
        final name = seg.substring(0, eq).trim();
        final value = seg.substring(eq + 1).trim();
        if (name.isNotEmpty && value.isNotEmpty) into[name] = value;
      }
    }
  }
}
