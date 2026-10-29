import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as c;

/// Cryptographic primitives replicating Mi Fitness' CloudInterceptor (3.59.1i).
/// See the "How it works" section of the README.

/// Uppercase MD5 of the password (what serviceLoginAuth2 expects as `hash`).
String md5UpperHex(String s) =>
    c.md5.convert(utf8.encode(s)).toString().toUpperCase();

Uint8List sha256Bytes(List<int> data) =>
    Uint8List.fromList(c.sha256.convert(data).bytes);

Uint8List sha1Bytes(List<int> data) =>
    Uint8List.fromList(c.sha1.convert(data).bytes);

String sha1Base64(String s) => base64.encode(sha1Bytes(utf8.encode(s)));

/// RC4 with "drop": discards the first [drop] keystream bytes before
/// encrypting. Mi Fitness uses drop=1024 (class o9l: the constructor runs
/// this.b(1024 zeros) after the KSA). This is NOT plain RC4.
Uint8List rc4Drop(Uint8List key, Uint8List data, {int drop = 1024}) {
  final s = List<int>.generate(256, (i) => i);
  var j = 0;
  for (var i = 0; i < 256; i++) {
    j = (j + s[i] + key[i % key.length]) & 0xff;
    final t = s[i];
    s[i] = s[j];
    s[j] = t;
  }
  var a = 0, b = 0;
  for (var n = 0; n < drop; n++) {
    a = (a + 1) & 0xff;
    b = (b + s[a]) & 0xff;
    final t = s[a];
    s[a] = s[b];
    s[b] = t;
  }
  final out = Uint8List(data.length);
  for (var n = 0; n < data.length; n++) {
    a = (a + 1) & 0xff;
    b = (b + s[a]) & 0xff;
    final t = s[a];
    s[a] = s[b];
    s[b] = t;
    out[n] = data[n] ^ s[(s[a] + s[b]) & 0xff];
  }
  return out;
}
