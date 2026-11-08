import '../xiaomi/record_detail.dart';

/// One split of a run (a whole kilometer or mile, plus the final partial
/// segment): its speed and average heart rate, the way Mi Fitness shows them.
class KmSplit {
  /// 1-based segment number (1 = first km/mile).
  final int index;

  /// Length of this segment in meters: the full segment length for a whole
  /// split, or the remainder for the final partial segment.
  final double distanceM;

  /// Cumulative distance (meters) at the end of this segment.
  final double endDistanceM;

  /// Seconds spent covering this segment.
  final int durationSec;

  /// Average heart rate over this segment in bpm, or 0 when there is no reading.
  final int avgHr;

  /// Whether this is the final, shorter-than-a-full segment.
  final bool isPartial;

  const KmSplit({
    required this.index,
    required this.distanceM,
    required this.endDistanceM,
    required this.durationSec,
    required this.avgHr,
    required this.isPartial,
  });

  /// Average speed over the segment, in km/h.
  double get speedKmh =>
      durationSec > 0 ? (distanceM / 1000.0) / (durationSec / 3600.0) : 0;

  /// Pace normalized to seconds per full kilometer (unit conversion to per-mile
  /// happens at the formatting layer).
  int get paceSecPerKm =>
      distanceM > 0 ? (durationSec / (distanceM / 1000.0)).round() : 0;
}

/// Splits a cumulative per-second track into segments of [segmentM] meters
/// (1000 for kilometers, 1609.344 for miles).
///
/// A segment boundary is the first second at which the cumulative distance
/// reaches that mark (matching Mi Fitness' whole-split logic). The average HR of
/// a segment is the mean of the per-second readings inside it, ignoring zero
/// (missing) readings. [includePartial] adds the final, shorter segment when the
/// run doesn't end on a whole segment.
List<KmSplit> kmSplitStats(RecordTrack tr,
    {double segmentM = 1000, bool includePartial = true}) {
  final d = tr.d;
  if (d.length < 2 || segmentM <= 0) return const [];
  final hr = tr.hasHr ? tr.hr : null;

  final splits = <KmSplit>[];
  var seg = 1; // next segment mark to reach
  var prev = 0; // second index where the previous segment ended

  int avgHrBetween(int from, int to) {
    if (hr == null) return 0;
    var sum = 0, n = 0;
    for (var i = from + 1; i <= to; i++) {
      if (i < hr.length && hr[i] > 0) {
        sum += hr[i];
        n++;
      }
    }
    return n > 0 ? (sum / n).round() : 0;
  }

  for (var i = 1; i < d.length; i++) {
    if (d[i] >= seg * segmentM) {
      splits.add(KmSplit(
        index: seg,
        distanceM: segmentM,
        endDistanceM: seg * segmentM,
        durationSec: i - prev,
        avgHr: avgHrBetween(prev, i),
        isPartial: false,
      ));
      prev = i;
      seg++;
    }
  }

  if (includePartial) {
    final last = d.length - 1;
    final remainder = d[last] - (seg - 1) * segmentM;
    if (last > prev && remainder > 1.0) {
      splits.add(KmSplit(
        index: seg,
        distanceM: remainder,
        endDistanceM: d[last],
        durationSec: last - prev,
        avgHr: avgHrBetween(prev, last),
        isPartial: true,
      ));
    }
  }

  return splits;
}
