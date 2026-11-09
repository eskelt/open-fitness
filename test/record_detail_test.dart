// Locks the reverse-engineered byte layout of the record-detail blob
// (fileType=0): 30-byte header, int32-LE sample count at offset 17, 13-byte
// samples from offset 30 with distance (dm) at +3 and heart rate at +1.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_fitness/xiaomi/record_detail.dart';

/// Builds a synthetic blob from (distanceDm, hr) sample pairs.
Uint8List makeBlob(List<List<int>> samples, {int? declaredCount}) {
  const start = 30, rec = 13;
  final blob = Uint8List(start + samples.length * rec);
  final bd = ByteData.sublistView(blob);
  bd.setInt32(17, declaredCount ?? samples.length, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final off = start + i * rec;
    blob[off + 1] = samples[i][1]; // hr at +1
    blob[off + 3] = samples[i][0]; // distance (dm) at +3
  }
  return blob;
}

void main() {
  group('parseRecordTrack', () {
    test('accumulates distance (dm->m) and reads per-second HR', () {
      final tr = parseRecordTrack(makeBlob([
        [50, 120], // 5.0 m, 120 bpm
        [60, 130], // +6.0 m -> 11.0 m, 130 bpm
        [0, 0], //   +0.0 m -> 11.0 m, no reading
      ]));

      expect(tr.d, [0.0, 5.0, 11.0, 11.0]);
      expect(tr.hr, [0, 120, 130, 0]);
      expect(tr.hasHr, isTrue);
      expect(tr.seconds, 3);
      expect(tr.totalDistance, closeTo(11.0, 1e-9));
    });

    test('a declared count outside the valid range falls back to capacity', () {
      final tr = parseRecordTrack(makeBlob([
        [10, 100],
        [10, 100],
      ], declaredCount: 999)); // impossible: only 2 samples fit
      expect(tr.seconds, 2);
      expect(tr.d.last, closeTo(2.0, 1e-9));
    });

    test('a blob too short to hold one sample yields an empty track', () {
      final tr = parseRecordTrack(Uint8List(20));
      expect(tr.isEmpty, isTrue);
      expect(tr.d, [0.0]);
    });
  });
}
