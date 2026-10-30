import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:android_id/android_id.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../xiaomi/login.dart';
import '../xiaomi/api.dart';
import '../xiaomi/models.dart';

/// Global app instance.
final repo = Repository();

/// Orchestrates session + data. Persists deviceId and the session to avoid
/// re-logging in.
///
/// It is a [ChangeNotifier]: it calls [notifyListeners] whenever the session or
/// the records change, so any screen can rebuild from it with a
/// `ListenableBuilder(listenable: repo, ...)` without threading callbacks.
class Repository extends ChangeNotifier {
  static const _kDeviceId = 'device_id';
  static const _kSession = 'session';
  static const _kRunsCache = 'runs_cache';

  XiaomiSession? session;
  List<SportRecord> records = [];

  Future<String> _deviceId() async {
    final p = await SharedPreferences.getInstance();
    // 1. Prefer the ANDROID_ID: stable per device+app-signature, survives
    //    clearing data/cache and reinstalling. This stops Xiaomi from asking
    //    for verification on every data clear (like Mi Fitness does).
    if (Platform.isAndroid) {
      try {
        final aid = await const AndroidId().getId();
        if (aid != null && aid.isNotEmpty) {
          await p.setString(_kDeviceId, aid);
          return aid;
        }
      } catch (_) {
        // no ANDROID_ID available: fall back to the persisted/random id.
      }
    }
    // 2. Fallback: persisted id, or a random one the first time.
    var id = p.getString(_kDeviceId);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
      await p.setString(_kDeviceId, id);
    }
    return id;
  }

  Future<bool> restoreSession() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kSession);
    if (s == null) return false;
    try {
      session = XiaomiSession.fromJson(json.decode(s));
      final cached = p.getString(_kRunsCache);
      if (cached != null) {
        final list = json.decode(cached) as List;
        records = list
            .map((e) => SportRecord.fromItem(e as Map<String, dynamic>))
            .toList();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Current (stable) deviceId. The verification screen needs it to set the
  /// cookie in the WebView, so the verification binds to THIS device and the
  /// login retry recognizes it.
  Future<String> deviceId() => _deviceId();

  Future<void> login(String user, String password,
      {String region = 'de', Map<String, String> extraCookies = const {}}) async {
    final deviceId = await _deviceId();
    final s = await XiaomiLogin(deviceId: deviceId)
        .login(user, password, region: region, extraCookies: extraCookies);
    session = s;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSession, json.encode(s.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kSession);
    await p.remove(_kRunsCache);
    session = null;
    records = [];
    notifyListeners();
  }

  /// Downloads all sessions (every sport), paging, and caches them.
  /// [onProgress] is called after each page to refresh the UI incrementally.
  Future<void> refresh({void Function()? onProgress}) async {
    if (session == null) throw StateError('no session');
    final api = XiaomiApi(session!);
    // dedup by stable id (sid|key|time): paging can overlap pages.
    final byId = <String, Map<String, dynamic>>{};
    final seenKeys = <String>{};
    String? nextKey;
    for (var page = 0; page < 200; page++) {
      final resp =
          await api.getSportRecordsByTime(limit: 50, nextKey: nextKey);
      final code = resp['code'];
      if (code != 0) {
        throw Exception('API code=$code: ${resp['message']}');
      }
      final result = resp['result'];
      final list = (result?['sport_records'] as List?) ?? [];
      for (final item in list.whereType<Map<String, dynamic>>()) {
        final rec = SportRecord.fromItem(item);
        byId[rec.id] = item;
      }
      // live update so the UI starts showing data.
      records = byId.values.map(SportRecord.fromItem).toList();
      onProgress?.call();
      notifyListeners();

      final hasMore = result?['has_more'] == true;
      nextKey = (result?['next_key'] ?? '').toString();
      // stop if there is no more, or if the cursor does not advance (avoids an
      // infinite loop).
      if (!hasMore || nextKey.isEmpty || !seenKeys.add(nextKey)) break;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRunsCache, json.encode(byId.values.toList()));
  }

  List<SportRecord> get runs =>
      records.where((r) => r.isRunning).toList()
        ..sort((a, b) => b.time.compareTo(a.time));

  /// Testing: fetch FDS pre-signed download URLs for a record's detail file(s).
  Future<Map<String, dynamic>> fdsDownloadUrls(List<SportRecord> records) {
    if (session == null) throw StateError('no session');
    return XiaomiApi(session!).getFDSDownloadUrls(records);
  }

  /// Testing: download + decrypt a record's detail blob from FDS.
  Future<Uint8List> fdsRecordDetail(SportRecord r) {
    if (session == null) throw StateError('no session');
    return XiaomiApi(session!).fetchRecordDetail(r);
  }
}
