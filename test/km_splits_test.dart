// Per-kilometer / per-mile split segmentation.
import 'package:flutter_test/flutter_test.dart';
import 'package:open_fitness/stats/km_splits.dart';
import 'package:open_fitness/xiaomi/record_detail.dart';

/// Constant-speed track of [meters] run at [mps] m/s, HR fixed at [hr].
RecordTrack steadyTrack(int meters, {double mps = 1.0, int hr = 150}) {
  final secs = (meters / mps).round();
  final d = <double>[0.0];
  final h = <int>[0];
  for (var i = 1; i <= secs; i++) {
    d.add(i * mps);
    h.add(hr);
  }
  return RecordTrack(d, h);
}

void main() {
  group('kmSplitStats', () {
    test('a 2.5 km run at 1 m/s -> two full km + a 500 m partial', () {
      final splits = kmSplitStats(steadyTrack(2500));
      expect(splits.length, 3);

      expect(splits[0].index, 1);
      expect(splits[0].isPartial, isFalse);
      expect(splits[0].durationSec, 1000);
      expect(splits[0].paceSecPerKm, 1000);
      expect(splits[0].avgHr, 150);

      expect(splits[1].endDistanceM, 2000);

      expect(splits[2].isPartial, isTrue);
      expect(splits[2].distanceM, closeTo(500, 1e-6));
      expect(splits[2].durationSec, 500);
    });

    test('includePartial:false drops the trailing partial segment', () {
      final splits = kmSplitStats(steadyTrack(2500), includePartial: false);
      expect(splits.length, 2);
      expect(splits.every((s) => !s.isPartial), isTrue);
    });

    test('a run shorter than one segment yields only a partial', () {
      final splits = kmSplitStats(steadyTrack(600));
      expect(splits.length, 1);
      expect(splits.single.isPartial, isTrue);
      expect(splits.single.distanceM, closeTo(600, 1e-6));
    });

    test('mile segments use 1609.344 m boundaries', () {
      final splits = kmSplitStats(steadyTrack(2000), segmentM: 1609.344);
      expect(splits.first.endDistanceM, closeTo(1609.344, 1e-3));
      expect(splits.first.isPartial, isFalse);
    });

    test('zero HR readings are ignored when averaging', () {
      // Half the seconds report 0 (no reading); avg must use only real beats.
      final d = <double>[0.0];
      final h = <int>[0];
      for (var i = 1; i <= 1000; i++) {
        d.add(i.toDouble());
        h.add(i.isEven ? 160 : 0);
      }
      final splits = kmSplitStats(RecordTrack(d, h));
      expect(splits.first.avgHr, 160);
    });

    test('too-short track returns no splits', () {
      expect(kmSplitStats(const RecordTrack([0.0])), isEmpty);
    });
  });
}
