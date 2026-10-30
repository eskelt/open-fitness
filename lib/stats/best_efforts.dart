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

/// Fastest continuous time (seconds) to cover [target] meters anywhere in the
/// track; null when the track is shorter than the target. O(n) two-pointer
/// sliding window; the finishing instant is interpolated inside the last second.
double? bestEffort(RecordTrack tr, double target) {
  final d = tr.d, t = tr.t;
  final n = d.length;
  if (n < 2 || d[n - 1] - d[0] < target) return null;
  var best = double.infinity;
  var j = 0;
  for (var i = 0; i < n; i++) {
    if (j <= i) j = i + 1;
    while (j < n && d[j] - d[i] < target) {
      j++;
    }
    if (j >= n) break;
    final need = d[i] + target - d[j - 1];
    final seg = d[j] - d[j - 1];
    final tEnd = t[j - 1] + (seg > 0 ? need / seg : 0) * (t[j] - t[j - 1]);
    final time = tEnd - t[i];
    if (time < best) best = time;
  }
  return best.isFinite ? best : null;
}

/// Best time for each of [bestEffortTargets] (null where too short).
List<double?> bestEfforts(RecordTrack tr) =>
    [for (final target in bestEffortTargets) bestEffort(tr, target)];
