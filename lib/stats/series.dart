import '../xiaomi/record_detail.dart';

/// A plottable series: parallel x/y lists, chart-library agnostic. x is the
/// cumulative distance in kilometers; y is the metric value in its base unit
/// (bpm for HR, seconds-per-km for pace, …). Unit conversion for display is
/// applied at the formatting layer, not here.
class MetricSeries {
  final List<double> x;
  final List<double> y;
  const MetricSeries(this.x, this.y);
  bool get isEmpty => x.length < 2;
}

/// Heart-rate against distance, dropping seconds with no reading (0 bpm).
/// Thinned with a peak-preserving pass so the drawn line still reaches the real
/// min/max (a plain stride-based thin would skip the single peak second and the
/// "max" reference line would float above the curve).
MetricSeries hrSeries(RecordTrack tr) {
  if (!tr.hasHr) return const MetricSeries([], []);
  final xs = <double>[], ys = <double>[];
  for (var i = 1; i < tr.d.length; i++) {
    final h = tr.hr[i];
    if (h <= 0) continue;
    xs.add(tr.d[i] / 1000.0);
    ys.add(h.toDouble());
  }
  return _downsampleMinMax(MetricSeries(xs, ys), 150);
}

/// Pace (seconds per km) against distance.
///
/// The per-second distance channel (byte +3) is noisy — at a steady speed it
/// jitters between e.g. 0 and 69 dm from one second to the next — so pace is
/// derived from a **centered** moving average of speed over [window] seconds.
/// This matches how Mi Fitness/Strava draw it: GPS jitter disappears but real
/// surges survive (on a verified run, a 2 km/h-wide centered window collapsed
/// the fastest point from a noise spike of 3:58 to 4:27 /km, which is the run's
/// official best pace of 4:30). Paused/implausible samples are dropped, then a
/// plain mean downsample thins it — unlike HR we do NOT keep per-bucket min/max,
/// because on a noisy signal that re-introduces the very spikes we smoothed out.
MetricSeries paceSeries(RecordTrack tr, {int window = 41}) {
  final d = tr.d;
  if (d.length < 3) return const MetricSeries([], []);
  // Per-second speed (m/s): distance covered during second i.
  final n = d.length;
  final speed = List<double>.filled(n, 0.0);
  for (var i = 1; i < n; i++) {
    final step = d[i] - d[i - 1];
    speed[i] = step > 0 ? step : 0.0;
  }
  final half = window ~/ 2;
  final xs = <double>[], ys = <double>[];
  for (var i = 1; i < n; i++) {
    final lo = (i - half) < 1 ? 1 : i - half;
    final hi = (i + half) >= n ? n - 1 : i + half;
    var sum = 0.0;
    for (var j = lo; j <= hi; j++) {
      sum += speed[j];
    }
    final avg = sum / (hi - lo + 1); // m/s, centered
    if (avg < 0.5) continue; // stopped / paused
    final paceSecPerKm = 1000.0 / avg;
    if (paceSecPerKm > 1200 || paceSecPerKm < 120) continue; // 20:00..2:00 /km
    xs.add(d[i] / 1000.0);
    ys.add(paceSecPerKm);
  }
  return _downsampleMean(MetricSeries(xs, ys), 150);
}

/// Mean thinning: splits the series into [buckets] windows and keeps each
/// window's average. Use for an already-smoothed signal (pace) where preserving
/// per-bucket extremes would only surface residual noise; the curve stays stable
/// and its average matches the summary.
MetricSeries _downsampleMean(MetricSeries s, int buckets) {
  final n = s.x.length;
  if (n <= buckets) return s;
  final xs = <double>[], ys = <double>[];
  final size = n / buckets;
  for (var b = 0; b < buckets; b++) {
    final start = (b * size).floor();
    final end = ((b + 1) * size).floor().clamp(start + 1, n);
    var sx = 0.0, sy = 0.0;
    for (var i = start; i < end; i++) {
      sx += s.x[i];
      sy += s.y[i];
    }
    final c = end - start;
    xs.add(sx / c);
    ys.add(sy / c);
  }
  return MetricSeries(xs, ys);
}

/// Peak-preserving thinning: splits the series into [buckets] windows and keeps
/// each window's min and max sample (in time order). The global minimum and
/// maximum always survive, so a reference line drawn at the real max lands on
/// the curve. For a slowly-varying signal like HR the min/max of a small window
/// are close together, so the line stays smooth.
MetricSeries _downsampleMinMax(MetricSeries s, int buckets) {
  final n = s.x.length;
  if (n <= buckets * 2) return s;
  final xs = <double>[], ys = <double>[];
  final size = n / buckets;
  for (var b = 0; b < buckets; b++) {
    final start = (b * size).floor();
    final end = ((b + 1) * size).floor().clamp(start + 1, n);
    var lo = start, hi = start;
    for (var i = start; i < end; i++) {
      if (s.y[i] < s.y[lo]) lo = i;
      if (s.y[i] > s.y[hi]) hi = i;
    }
    final first = lo < hi ? lo : hi;
    final second = lo < hi ? hi : lo;
    xs.add(s.x[first]);
    ys.add(s.y[first]);
    if (second != first) {
      xs.add(s.x[second]);
      ys.add(s.y[second]);
    }
  }
  return MetricSeries(xs, ys);
}
