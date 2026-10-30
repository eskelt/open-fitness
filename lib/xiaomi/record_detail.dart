import 'dart:typed_data';

/// A per-second track (cumulative time in seconds, cumulative distance in
/// meters), both starting at 0. Used for best-effort (fastest-split) analysis.
class RecordTrack {
  final List<double> t;
  final List<double> d;
  const RecordTrack(this.t, this.d);
  double get totalDistance => d.isEmpty ? 0 : d.last;
  bool get isEmpty => d.length < 2;
}

/// Parses a Mi Fitness "record" detail blob (fileType=0) into a [RecordTrack].
///
/// Layout (reverse-engineered for outdoor running, blob already AES-decrypted):
///   - 30-byte header; sample count = little-endian int32 at offset 17.
///   - `count` samples of 13 bytes each, from offset 30, one per second.
///   - within a sample, bytes +11..+12 (LE uint16) = instantaneous pace (s/km);
///     bytes +10 = heart rate, +1 = cadence (not used here).
/// Distance is integrated from pace (speed = 1000/pace m/s); GPS jumps (>7 m/s)
/// are dropped. When [summaryDistanceM] is given the track is rescaled to it
/// (the integrated total is ~1-2% below the summary), matching Mi Fitness.
RecordTrack parseRecordTrack(Uint8List blob, {int? summaryDistanceM}) {
  const start = 30, rec = 13;
  if (blob.length < start + rec) return const RecordTrack([0.0], [0.0]);
  final bd = ByteData.sublistView(blob);
  final declared = bd.getInt32(17, Endian.little);
  final capacity = (blob.length - start) ~/ rec;
  final samples = (declared > 0 && declared <= capacity) ? declared : capacity;

  final t = <double>[0.0];
  final d = <double>[0.0];
  var cum = 0.0;
  for (var i = 0; i < samples; i++) {
    final off = start + i * rec;
    final pace = bd.getUint16(off + 11, Endian.little); // s/km
    var v = 0.0;
    if (pace >= 143) v = 1000.0 / pace; // clamp GPS jumps faster than 7 m/s
    cum += v;
    t.add((i + 1).toDouble());
    d.add(cum);
  }
  if (summaryDistanceM != null && summaryDistanceM > 0 && cum > 0) {
    final f = summaryDistanceM / cum;
    for (var i = 0; i < d.length; i++) {
      d[i] *= f;
    }
  }
  return RecordTrack(t, d);
}
