import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:android_id/android_id.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../stats/best_efforts.dart';
import '../xiaomi/login.dart';
import '../xiaomi/api.dart';
import '../xiaomi/models.dart';
import '../xiaomi/record_detail.dart';

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

  /// Download + decrypt a record's detail blob from FDS.
  Future<Uint8List> fdsRecordDetail(SportRecord r) {
    if (session == null) throw StateError('no session');
    return XiaomiApi(session!).fetchRecordDetail(r);
  }

  // --- Best efforts across runs (records by distance) ---
  static const _kBeCache = 'best_efforts_cache_v1';
  Map<String, List<double?>?>? _beCache;

  Future<Map<String, List<double?>?>> _loadBeCache() async {
    if (_beCache != null) return _beCache!;
    final p = await SharedPreferences.getInstance();
    final out = <String, List<double?>?>{};
    final s = p.getString(_kBeCache);
    if (s != null) {
      final m = json.decode(s) as Map<String, dynamic>;
      for (final e in m.entries) {
        out[e.key] = e.value == null
            ? null
            : (e.value as List).map((x) => (x as num?)?.toDouble()).toList();
      }
    }
    return _beCache = out;
  }

  Future<void> _saveBeCache() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBeCache, json.encode(_beCache));
  }

  /// Runs that can have a detail file (long enough + a server version).
  List<SportRecord> get _beRuns =>
      runs.where((r) => r.distanceM >= 1000 && r.version > 0).toList();

  /// Best efforts for one run (cached; null when it has no detail file).
  Future<List<double?>?> runBestEfforts(SportRecord r) async {
    final cache = await _loadBeCache();
    if (cache.containsKey(r.id)) return cache[r.id];
    List<double?>? result;
    try {
      result = bestEfforts(parseRecordTrack(await fdsRecordDetail(r)));
    } catch (_) {
      result = null; // no detail / error: cache so we don't refetch
    }
    cache[r.id] = result;
    await _saveBeCache();
    return result;
  }

  /// Computes + caches best efforts for every run still missing from the cache.
  Future<void> computeAllBestEfforts(
      {void Function(int done, int total)? onProgress}) async {
    final rs = _beRuns;
    final cache = await _loadBeCache();
    var done = 0;
    for (final r in rs) {
      if (!cache.containsKey(r.id)) {
        try {
          cache[r.id] = bestEfforts(parseRecordTrack(await fdsRecordDetail(r)));
        } catch (_) {
          cache[r.id] = null;
        }
        await _saveBeCache();
      }
      onProgress?.call(++done, rs.length);
    }
  }

  /// How many runs still need their detail fetched for the records screen.
  Future<int> pendingBestEfforts() async {
    final cache = await _loadBeCache();
    return _beRuns.where((r) => !cache.containsKey(r.id)).length;
  }

  /// For each best-effort target, the runs that have a time, fastest first.
  Future<List<List<MapEntry<SportRecord, double>>>> rankedRecords() async {
    final cache = await _loadBeCache();
    final byId = {for (final r in records) r.id: r};
    final out = List.generate(
        bestEffortTargets.length, (_) => <MapEntry<SportRecord, double>>[]);
    for (final e in cache.entries) {
      final efforts = e.value;
      final r = byId[e.key];
      if (efforts == null || r == null) continue;
      for (var i = 0; i < out.length && i < efforts.length; i++) {
        final tm = efforts[i];
        if (tm != null) out[i].add(MapEntry(r, tm));
      }
    }
    for (final list in out) {
      list.sort((a, b) => a.value.compareTo(b.value));
    }
    return out;
  }
}
