import 'package:flutter/material.dart';

/// Formatting of sport metrics, language-independent except for units.

String fmtDistanceKm(int meters, {int decimals = 2}) =>
    (meters / 1000.0).toStringAsFixed(decimals);

/// Compact duration: 1:23:45 or 23:45.
String fmtDuration(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
}

/// Long readable duration: 2 h 15 min / 45 min.
String fmtDurationLong(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60;
  if (h > 0) return '$h h ${m.toString().padLeft(2, '0')} min';
  return '$m min';
}

/// Pace s/km -> 5:42 (no unit; the UI adds the unit via i18n).
String fmtPace(int secPerKm) {
  if (secPerKm <= 0) return '--';
  return '${secPerKm ~/ 60}:${(secPerKm % 60).toString().padLeft(2, '0')}';
}

/// Speed m/s -> km/h.
String fmtSpeedKmh(double mps) => (mps * 3.6).toStringAsFixed(1);

/// HR zone palette: a conventional intensity ramp (blue->red), ordered
/// warm-up < fat burn < aerobic < anaerobic < extreme.
/// Always paired with name+duration (identity is not encoded by color alone).
const hrZoneColors = <Color>[
  Color(0xFF5B8FF9), // warm up   (blue)
  Color(0xFF37C2A6), // fat burn  (teal)
  Color(0xFFF2C94C), // aerobic   (yellow)
  Color(0xFFF2994A), // anaerobic (orange)
  Color(0xFFEB5757), // extreme   (red)
];

/// Brand accent (orange), for single-series bars (magnitude).
const brandAccent = Color(0xFFFF6D00);
