import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../units_controller.dart';

/// Formatting of sport metrics, language-independent except for units.
///
/// Distance, pace and speed honour the global [unitsController] (metric vs
/// imperial), so flipping that one setting switches every screen at once.

const double _miPerKm = 0.621371192; // miles in 1 km
const double _kmPerMi = 1.609344; // km in 1 mile
const double _ftPerM = 3.28084; // feet in 1 meter
const double _inPerCm = 0.393700787; // inches in 1 cm

bool get _imperial => unitsController.imperial;

/// Distance number in the active unit (km or miles). No unit suffix.
String fmtDistance(int meters, {int decimals = 2}) {
  final km = meters / 1000.0;
  final v = _imperial ? km * _miPerKm : km;
  return v.toStringAsFixed(decimals);
}

/// Distance unit label for the active system.
String distanceUnit(L t) => _imperial ? t.unitMi : t.unitKm;

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

/// Pace s/km -> 5:42, converted to s/mile when imperial (no unit suffix; the
/// UI adds the unit via [paceUnit]).
String fmtPace(int secPerKm) {
  if (secPerKm <= 0) return '--';
  final sec = _imperial ? (secPerKm * _kmPerMi).round() : secPerKm;
  return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
}

/// Pace unit label for the active system.
String paceUnit(L t) => _imperial ? t.paceUnitMi : t.paceUnit;

/// Speed given by the server in km/h, formatted as km/h or mph depending on the
/// active system. (Mi Fitness' `avg_speed`/`max_speed` are already km/h — they
/// are not m/s, so they must not be multiplied by 3.6.)
String fmtSpeed(double kmh) {
  final v = _imperial ? kmh * _miPerKm : kmh;
  return v.toStringAsFixed(1);
}

/// Speed unit label for the active system.
String speedUnit(L t) => _imperial ? t.unitMph : t.unitKmh;

/// Elevation (meters) -> rounded value in the active unit (m or feet).
String fmtElevation(double meters) {
  final v = _imperial ? meters * _ftPerM : meters;
  return '${v.round()}';
}

/// Convert a distance in kilometers to the active unit's numeric value, for
/// chart axes/tooltips that keep their internal scale in km.
double distanceKmToUnit(double km) => _imperial ? km * _miPerKm : km;

/// Convert an elevation in meters to the active unit's numeric value.
double elevToUnit(double meters) => _imperial ? meters * _ftPerM : meters;

/// Elevation unit label for the active system.
String elevUnit(L t) => _imperial ? t.unitFt : t.unitM;

/// Stride length (cm) -> rounded value in the active unit (cm or inches).
String fmtStride(int cm) =>
    _imperial ? '${(cm * _inPerCm).round()}' : '$cm';

/// Stride unit label for the active system.
String strideUnit(L t) => _imperial ? t.unitIn : t.cmUnit;

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
