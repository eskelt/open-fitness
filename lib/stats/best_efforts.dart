import '../xiaomi/record_detail.dart';

/// Standard best-effort distances (meters), Strava-style.
const bestEffortTargets = <double>[
  1000, // 1 km
  1609.344, // 1 mile
  5000, // 5 km
  10000, // 10 km
  21097.5, // half marathon
  42195, // marathon
];

/// Whole-km split durations (seconds) from a cumulative track: for each km, the
/// number of seconds until the cumulative distance first reaches that km mark.
/// Matches Mi Fitness' WholeKMPoint (integer-second per-km splits).
List<int> kmSplits(RecordTrack tr) {
  final d = tr.d;
  final splits = <int>[];
  var km = 1, prev = 0;
  for (var i = 1; i < d.length; i++) {
    if (d[i] >= km * 1000.0) {
      splits.add(i - prev);
      prev = i;
      km++;
    }
  }
  return splits;
}

/// Best time (seconds) for [targetM] meters, the way Mi Fitness computes it:
/// the fastest run of whole consecutive km splits, plus the fraction of the
/// next km (at its own pace) when the target isn't a whole number of km.
/// Null when the session is shorter than the target.
double? bestEffortFromSplits(List<int> splits, double targetM) {
  final full = targetM ~/ 1000;
  final fracM = targetM - full * 1000;
  final needsNext = fracM > 1e-6;
  final window = full + (needsNext ? 1 : 0);
  if (splits.length < window || full == 0 && !needsNext) return null;
  var best = double.infinity;
  for (var s = 0; s + window <= splits.length; s++) {
    var sum = 0.0;
    for (var k = s; k < s + full; k++) {
      sum += splits[k];
    }
    if (needsNext) sum += splits[s + full] * (fracM / 1000.0);
    if (sum < best) best = sum;
  }
  return best.isFinite ? best : null;
}

/// Best time for each of [bestEffortTargets] (null where too short).
List<double?> bestEfforts(RecordTrack tr) {
  final splits = kmSplits(tr);
  return [for (final t in bestEffortTargets) bestEffortFromSplits(splits, t)];
}
