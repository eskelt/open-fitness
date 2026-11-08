import 'dart:typed_data';

/// Cumulative distance (meters) at each whole second of a session, starting at
/// 0. `d[i]` is the distance covered after `i` seconds.
///
/// [hr] (when present) is aligned to [d]: `hr[i]` is the heart rate (bpm) during
/// second `i`, with `hr[0] == 0` and `hr.length == d.length`. A value of 0 means
/// "no reading" for that second.
class RecordTrack {
  final List<double> d;
  final List<int> hr;
  const RecordTrack(this.d, [this.hr = const []]);
  double get totalDistance => d.isEmpty ? 0 : d.last;
  int get seconds => d.isEmpty ? 0 : d.length - 1;
  bool get isEmpty => d.length < 2;
  bool get hasHr => hr.length == d.length;
}

/// Parses a Mi Fitness "record" detail blob (fileType=0, already AES-decrypted)
/// into a per-second cumulative distance track.
///
/// Layout (reverse-engineered, outdoor running), verified against a real 12 km
/// run (per-km splits and 10 km record matched Mi Fitness exactly):
///   - 30-byte header; sample count = little-endian int32 at offset 17.
///   - `count` samples of 13 bytes each, from offset 30, one per second.
///   - within a sample, byte +3 = distance covered that second, in decimeters
///     (0.1 m); bytes +11..12 (LE uint16) = pace (s/km), +10 = HR, +1 = cadence.
RecordTrack parseRecordTrack(Uint8List blob) {
  const start = 30, rec = 13, distOffset = 3, hrOffset = 10;
  if (blob.length < start + rec) return const RecordTrack([0.0]);
  final bd = ByteData.sublistView(blob);
  final declared = bd.getInt32(17, Endian.little);
  final capacity = (blob.length - start) ~/ rec;
  final samples = (declared > 0 && declared <= capacity) ? declared : capacity;

  final d = List<double>.filled(samples + 1, 0.0);
  final hr = List<int>.filled(samples + 1, 0);
  var cum = 0.0;
  for (var i = 0; i < samples; i++) {
    final off = start + i * rec;
    cum += blob[off + distOffset] / 10.0; // decimeters -> meters
    d[i + 1] = cum;
    hr[i + 1] = blob[off + hrOffset];
  }
  return RecordTrack(d, hr);
}
