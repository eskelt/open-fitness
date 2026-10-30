import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'crypto.dart';
import 'login.dart';
import 'models.dart';

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

  /// POSTs to `/{basePath}/{endpoint}` with `data`=jsonData (plaintext), signed
  /// and encrypted, and returns the already-decrypted JSON response.
  /// Data endpoints use basePath `app/v1`; FDS uses `healthapp`.
  /// [signPath] is the path used inside the signature. The CloudInterceptor
  /// signs the path AFTER the service's Secret pathPrefix: data endpoints have
  /// an empty prefix (so it's the full `/app/v1/...` path), while FDS strips
  /// `healthapp/` and signs just `service/gen_download_url`.
  Future<Map<String, dynamic>> post(String endpoint, String jsonData,
      {String basePath = 'app/v1', String? signPath, bool debugLog = false}) async {
    final path = '/$basePath/$endpoint';
    final sp = signPath ?? path;

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

    // sig1 = SHA1("POST&signPath&data=<plaintext>&" + rc4Hash)
    final sig1 = sha1Base64('POST&$sp&data=$jsonData&$rc4Hash');

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
        sha1Base64('POST&$sp&data=$dataEnc&rc4_hash__=$sig1Enc&$rc4Hash');

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

    if (debugLog) {
      debugPrint('[FDS] POST https://$_host$path');
      debugPrint('[FDS] signPath=$sp');
      debugPrint('[FDS] data(plain)=$jsonData');
      debugPrint('[FDS] nonce=$nonce');
      debugPrint('[FDS] cookies: cUserId=${session.cUserId} '
          'serviceToken.len=${session.serviceToken.length}');
      debugPrint('[FDS] HTTP ${resp.statusCode}');
      debugPrint('[FDS] body=${resp.body}');
    }

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

  // --- FDS detail files (per-sample series, incl. per-km splits) ---

  /// URL-safe base64 without padding (Android flag URL_SAFE|NO_WRAP|NO_PADDING).
  static String _b64url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// The FDS object key for a running session's detail ("record") file, as
  /// FitnessFDSUploader builds it:
  ///   keyBytes (LE) = int32(startSec) + byte(tz15) + byte(128 + protoType*4)
  ///   objectKey = base64url(keyBytes) + "_" + base64url(SHA1(sid))
  static String fdsRecordObjectKey({
    required String sid,
    required int startSec,
    required int tz15,
    required int protoType,
  }) {
    final buf = Uint8List(6);
    ByteData.view(buf.buffer).setInt32(0, startSec, Endian.little);
    buf[4] = tz15 & 0xff;
    buf[5] = (128 + protoType * 4) & 0xff; // dataType=1, dailyType=0, fileType=0
    final suffix = _b64url(buf);
    final sidHash = _b64url(sha1Bytes(utf8.encode(sid)));
    return '${suffix}_$sidHash';
  }

  /// Server map key for the response (PreSignedUrlItem.toServerKey()).
  static String fdsServerKey(String objectKey, int startSec) =>
      '${objectKey}_$startSec';

  /// Requests FDS pre-signed download URLs for one or more records' detail
  /// files. All records must belong to the same watch (`sid`). Returns the raw
  /// decrypted response (so the caller can inspect it while we validate).
  Future<Map<String, dynamic>> getFDSDownloadUrls(List<SportRecord> records) {
    final sid = records.first.sid;
    final items = [
      for (final r in records)
        {
          'suffix': fdsRecordObjectKey(
            sid: r.sid,
            startSec: r.time,
            tz15: r.zoneOffsetSec ~/ 900,
            protoType: r.protoType,
          ),
          'timestamp': r.time,
        }
    ];
    return post('service/gen_download_url',
        json.encode({'did': sid, 'items': items}),
        basePath: 'healthapp',
        // CloudInterceptor signs the subpath after the Secret prefix, but
        // getEncryptedParams prepends "/" if missing -> "/service/gen_download_url".
        signPath: '/service/gen_download_url',
        debugLog: true);
  }

  /// Downloads a record's detail file from FDS and decrypts it (AESCoder):
  ///   GET url -> base64url body -> AES-128-CBC/PKCS7 (key=obj_key, fixed IV) -> bytes.
  /// Returns the raw decrypted blob (to be parsed into the per-sample series).
  Future<Uint8List> fetchRecordDetail(SportRecord r) async {
    final resp = await getFDSDownloadUrls([r]);
    final result = resp['result'];
    if (result is! Map || result.isEmpty) {
      throw Exception('FDS: no download url (${resp['message']})');
    }
    final entry = result.values.first;
    if (entry is! Map || entry['url'] == null || entry['obj_key'] == null) {
      throw Exception('FDS: no detail file for this run (entry=$entry)');
    }
    final url = entry['url'] as String;
    final objKey = entry['obj_key'] as String;
    var body = (await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30)))
        .body
        .trim();
    // The store returns the base64 ciphertext as a JSON string (quoted).
    if (body.startsWith('"') && body.endsWith('"')) {
      body = json.decode(body) as String;
    }
    final cipher = _b64any(body);
    final keyBytes = _b64any(objKey);
    final encrypter = enc.Encrypter(enc.AES(
        enc.Key(Uint8List.fromList(keyBytes)),
        mode: enc.AESMode.cbc,
        padding: 'PKCS7'));
    final iv = enc.IV(Uint8List.fromList(utf8.encode('1234567887654321')));
    final out = encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(cipher)),
        iv: iv);
    return Uint8List.fromList(out);
  }

  /// Base64 decode accepting url-safe and unpadded input.
  static Uint8List _b64any(String s) {
    var t = s.trim().replaceAll('-', '+').replaceAll('_', '/');
    t += '=' * ((4 - t.length % 4) % 4);
    return base64.decode(t);
  }
}
