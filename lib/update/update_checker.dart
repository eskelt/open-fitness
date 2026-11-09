import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A newer release discovered on GitHub.
class UpdateInfo {
  final String version; // normalized tag, e.g. "0.5.0"
  final String url; // release page (html_url)
  final String notes; // release body (may be empty)
  const UpdateInfo(
      {required this.version, required this.url, required this.notes});
}

/// Checks GitHub Releases for a newer version of the app.
///
/// No backend: it reads the public "latest release" endpoint. Because the app
/// ships as a GitHub-release APK (no Play Store), this is how users learn about
/// updates without checking the repo. Network results are cached in
/// shared_preferences and the lookup is throttled to once a day, so a pending
/// update keeps showing across launches without hammering the API. It never
/// throws — any network/parse error just yields null (no update shown).
class UpdateChecker {
  UpdateChecker._();

  static const repo = 'eskelt/open-fitness';
  static const _kCheckedMs = 'update_checked_ms';
  static const _kTag = 'update_tag';
  static const _kUrl = 'update_url';
  static const _kNotes = 'update_notes';
  static const _kDismissed = 'update_dismissed_tag';
  static const _minInterval = Duration(hours: 24);

  /// Current app version (e.g. "0.5.0"), from the package metadata.
  static Future<String> currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  /// Returns a newer release if one exists, else null (up to date or any error).
  /// Throttled to once per 24h unless [force]; between network checks it returns
  /// the cached result so a pending update keeps showing.
  static Future<UpdateInfo?> check({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await currentVersion();
      final now = DateTime.now().millisecondsSinceEpoch;
      final last = prefs.getInt(_kCheckedMs) ?? 0;

      if (force || now - last >= _minInterval.inMilliseconds) {
        final fresh = await _fetch();
        if (fresh != null) {
          prefs.setInt(_kCheckedMs, now);
          prefs.setString(_kTag, fresh.version);
          prefs.setString(_kUrl, fresh.url);
          prefs.setString(_kNotes, fresh.notes);
        }
      }

      final tag = prefs.getString(_kTag) ?? '';
      if (tag.isEmpty || !isNewer(tag, current)) return null;
      return UpdateInfo(
        version: tag,
        url: prefs.getString(_kUrl) ??
            'https://github.com/$repo/releases/latest',
        notes: prefs.getString(_kNotes) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether the user has dismissed the banner for [version].
  static Future<bool> isDismissed(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDismissed) == version;
  }

  /// Hide the banner until a newer version than [version] appears.
  static Future<void> dismiss(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDismissed, version);
  }

  static Future<UpdateInfo?> _fetch() async {
    final resp = await http.get(
      Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final tag =
        (json['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
    if (tag.isEmpty) return null;
    return UpdateInfo(
      version: tag,
      url: json['html_url'] as String? ??
          'https://github.com/$repo/releases/latest',
      notes: json['body'] as String? ?? '',
    );
  }

  /// true if dotted-numeric [a] is a higher version than [b] (build metadata
  /// after '+' ignored; missing parts treated as 0). e.g. "0.5.0" > "0.4.0".
  static bool isNewer(String a, String b) {
    List<int> parts(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final pa = parts(a), pb = parts(b);
    for (var i = 0; i < 3; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
