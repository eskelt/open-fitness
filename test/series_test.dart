// Chart series math. The pace test is a REGRESSION LOCK for the fix made when
// the pace chart was jagged: deriving pace from a centered moving average and a
// MEAN downsample (not min/max) must keep the drawn line stable.
import 'package:flutter_test/flutter_test.dart';
import 'package:open_fitness/stats/series.dart';
import 'package:open_fitness/xiaomi/record_detail.dart';

/// Mean absolute change between consecutive plotted points — the stability
/// metric. A jagged (noisy) line has a high jag; a smooth one is near zero.
double jag(List<double> y) {
  if (y.length < 2) return 0;
  var sum = 0.0;
  for (var i = 1; i < y.length; i++) {
    sum += (y[i] - y[i - 1]).abs();
  }
  return sum / (y.length - 1);
}

void main() {
  group('paceSeries', () {
    test('a steady 1 m/s run plots a flat ~1000 s/km line', () {
      final d = <double>[0.0];
      for (var i = 1; i <= 1200; i++) {
        d.add(i.toDouble());
      }
      final s = paceSeries(RecordTrack(d));
      expect(s.isEmpty, isFalse);
      final mean = s.y.reduce((a, b) => a + b) / s.y.length;
      expect(mean, closeTo(1000, 20));
    });

    test('GPS-jittery distance is smoothed into a stable line (regression)', () {
      // Per-second distance alternates 0 m / 2 m (avg 1 m/s) — exactly the
      // byte+3 jitter. Raw per-second pace would swing wildly; the centered
      // window + mean downsample must collapse it to a near-flat ~1000 s/km.
      final d = <double>[0.0];
      for (var i = 1; i <= 1200; i++) {
        d.add(d.last + (i.isEven ? 2.0 : 0.0));
      }
      final s = paceSeries(RecordTrack(d));
      expect(s.isEmpty, isFalse);

      final mean = s.y.reduce((a, b) => a + b) / s.y.length;
      expect(mean, closeTo(1000, 40)); // tracks the true average pace

      // The whole point of the fix: the drawn line is stable, not a zigzag.
      expect(jag(s.y), lessThan(20));
    });

    test('a track with too few points is empty', () {
      expect(paceSeries(const RecordTrack([0.0, 1.0])).isEmpty, isTrue);
    });
  });

  group('hrSeries', () {
    test('no HR channel -> empty series', () {
      final d = <double>[for (var i = 0; i <= 100; i++) i.toDouble()];
      expect(hrSeries(RecordTrack(d)).isEmpty, isTrue);
    });

    test('peak-preserving thinning keeps the true max on the curve', () {
      final d = <double>[0.0];
      final h = <int>[0];
      for (var i = 1; i <= 1000; i++) {
        d.add(i.toDouble());
        h.add(i == 500 ? 190 : 150); // a single 1-second peak
      }
      final s = hrSeries(RecordTrack(d, h));
      expect(s.isEmpty, isFalse);
      final max = s.y.reduce((a, b) => a > b ? a : b);
      expect(max, 190); // the spike survives downsampling
    });

    test('seconds with no reading (0 bpm) are dropped', () {
      final d = <double>[0.0];
      final h = <int>[0];
      for (var i = 1; i <= 300; i++) {
        d.add(i.toDouble());
        h.add(i.isEven ? 0 : 140);
      }
      final s = hrSeries(RecordTrack(d, h));
      expect(s.y.every((v) => v > 0), isTrue);
    });
  });
}
