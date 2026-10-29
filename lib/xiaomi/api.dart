import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'crypto.dart';
import 'login.dart';

/// Client for the Mi Fitness data API (FitnessApiService), replicating the
/// CloudInterceptor of 3.59.1i: signing + RC4-drop1024 + regional host.
class XiaomiApi {
  final XiaomiSession session;
  final _rng = Random.secure();

  XiaomiApi(this.session);

  /// Regional host: for region != cn, `region.` is prepended to the host
  /// (RegionUrlSwitcherImpl.getUrlWithRegionIfNeed).
  String get _host => (session.region.isNotEmpty && session.region != 'cn')
      ? '${session.region}.hlth.io.mi.com'
      : 'hlth.io.mi.com';

  /// POSTs to `/app/v1/{endpoint}` with `data`=jsonData (plaintext), signed and
  /// encrypted, and returns the already-decrypted JSON response.
  Future<Map<String, dynamic>> post(String endpoint, String jsonData) async {
    final path = '/app/v1/$endpoint';

    // nonce: 8 random bytes + 4 big-endian bytes of minutes since epoch.
    final nonceBytes = Uint8List(12);
    for (var i = 0; i < 8; i++) {
      nonceBytes[i] = _rng.nextInt(256);
    }
    final minutes = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    nonceBytes[8] = (minutes >> 24) & 0xff;
    nonceBytes[9] = (minutes >> 16) & 0xff;
    nonceBytes[10] = (minutes >> 8) & 0xff;
    nonceBytes[11] = minutes & 0xff;
    final nonce = base64.encode(nonceBytes);

    // key = SHA256(ssecurity_bytes || nonce_bytes). ssecurity first.
    final ssecBytes = base64.decode(session.ssecurity);
    final keyMaterial = Uint8List(ssecBytes.length + nonceBytes.length)
      ..setRange(0, ssecBytes.length, ssecBytes)
      ..setRange(ssecBytes.length, ssecBytes.length + nonceBytes.length,
          nonceBytes);
    final key = sha256Bytes(keyMaterial);
    final rc4Hash = base64.encode(key);

    // sig1 = SHA1("POST&path&data=<plaintext>&" + rc4Hash)
    final sig1 = sha1Base64('POST&$path&data=$jsonData&$rc4Hash');

    // encrypt data and then sig1 as a single continuous RC4-drop1024 stream.
    final dataBytes = utf8.encode(jsonData);
    final sig1Bytes = utf8.encode(sig1);
    final combined = Uint8List(dataBytes.length + sig1Bytes.length)
      ..setRange(0, dataBytes.length, dataBytes)
      ..setRange(dataBytes.length, dataBytes.length + sig1Bytes.length,
          sig1Bytes);
    final enc = rc4Drop(key, combined);
    final dataEnc = base64.encode(enc.sublist(0, dataBytes.length));
    final sig1Enc = base64.encode(enc.sublist(dataBytes.length));

    // final signature over the already-encrypted map.
    final signature =
        sha1Base64('POST&$path&data=$dataEnc&rc4_hash__=$sig1Enc&$rc4Hash');

    final uri = Uri.parse('https://$_host$path');
    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Cookie':
                'cUserId=${session.cUserId}; serviceToken=${session.serviceToken}',
          },
          body: {
            'data': dataEnc,
            'signature': signature,
            '_nonce': nonce,
            'rc4_hash__': sig1Enc,
          },
        )
        .timeout(const Duration(seconds: 20));

    // the response is a JSON string (encrypted base64). http already decodes the
    // body to text; strip quotes if the server wrapped it in "".
    var bodyStr = resp.body.trim();
    if (bodyStr.startsWith('"') && bodyStr.endsWith('"')) {
      bodyStr = json.decode(bodyStr) as String;
    }
    // If it looks like plain JSON (an unencrypted error), return it as-is.
    if (bodyStr.startsWith('{')) {
      return json.decode(bodyStr) as Map<String, dynamic>;
    }
    // decrypt: base64decode + RC4-drop1024 with the same key.
    final cipher = base64.decode(bodyStr);
    final plain = utf8.decode(rc4Drop(key, cipher));
    return json.decode(plain) as Map<String, dynamic>;
  }

  /// One page of sport sessions by time (includes running and others).
  /// The server caps `limit` (use <=50). Page with `nextKey` from the result.
  Future<Map<String, dynamic>> getSportRecordsByTime({
    int startTimeMs = 0,
    int? endTimeMs,
    int limit = 50,
    bool reverse = true,
    String? nextKey,
  }) {
    final end = endTimeMs ?? DateTime.now().millisecondsSinceEpoch;
    final data = json.encode({
      'startTime': startTimeMs,
      'endTime': end,
      'reverse': reverse,
      'limit': limit,
      if (nextKey != null && nextKey.isNotEmpty) 'nextKey': nextKey,
    });
    return post('data/get_sport_records_by_time', data);
  }

  Future<Map<String, dynamic>> getSportCategoryList({int limit = 100}) =>
      post('data/get_sport_category_list', json.encode({'limit': limit}));
}
