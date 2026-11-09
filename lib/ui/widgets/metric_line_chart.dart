import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// A labelled horizontal reference line drawn across a [MetricLineChart] (e.g.
/// average or max heart rate). Its value is in the same base unit as the series.
class ChartRefLine {
  final double value;
  final Color color;
  final String? label;
  const ChartRefLine(this.value, {required this.color, this.label});
}

/// A reusable single-series line chart for any per-second metric plotted against
/// distance/time (heart rate, pace, elevation, speed, cadence, …).
///
/// The widget is deliberately unit-agnostic: the caller supplies the raw samples
/// plus [xLabel] / [yLabel] / [tooltip] closures that format values (applying
/// any metric/imperial conversion). Set [invertY] for metrics where a lower
/// value is "better" and should sit higher on the chart (pace): it flips the
/// axis internally while the label/tooltip closures still receive the original
/// value.
class MetricLineChart extends StatelessWidget {
  /// Parallel sample lists. x is typically cumulative distance (km).
  final List<double> x;
  final List<double> y;
  final Color color;

  /// Formats a y value for an axis tick (receives the original, un-inverted
  /// value).
  final String Function(double value) yLabel;

  /// Formats an x value for an axis tick.
  final String Function(double value) xLabel;

  /// Builds the tooltip text for a hovered sample (original x and y).
  final String Function(double x, double y) tooltip;

  final bool invertY;
  final bool fill;
  final double height;

  /// Optional horizontal reference lines (e.g. average / max).
  final List<ChartRefLine> refLines;

  const MetricLineChart({
    super.key,
    required this.x,
    required this.y,
    required this.color,
    required this.yLabel,
    required this.xLabel,
    required this.tooltip,
    this.invertY = false,
    this.fill = true,
    this.height = 160,
    this.refLines = const [],
  });

  double _ty(double v) => invertY ? -v : v;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (x.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('—',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
      );
    }

    final maxX = x.last <= 0 ? 1.0 : x.last;
    var tMin = double.infinity, tMax = -double.infinity;
    for (final v in y) {
      final t = _ty(v);
      if (t < tMin) tMin = t;
      if (t > tMax) tMax = t;
    }
    // Keep reference lines within the visible range so they're never clipped.
    for (final r in refLines) {
      final t = _ty(r.value);
      if (t < tMin) tMin = t;
      if (t > tMax) tMax = t;
    }
    final span = (tMax - tMin).clamp(1.0, double.infinity);
    final pad = span * 0.15;
    final minY = tMin - pad, maxY = tMax + pad;
    final yStep = ((maxY - minY) / 3).clamp(1.0, double.infinity);

    final spots = [
      for (var i = 0; i < x.length; i++) FlSpot(x[i], _ty(y[i])),
    ];

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
              getTooltipItems: (touched) => [
                for (final s in touched)
                  LineTooltipItem(
                    tooltip(x[s.spotIndex], y[s.spotIndex]),
                    TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
              ],
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yStep,
            getDrawingHorizontalLine: (_) => FlLine(
                color: theme.dividerColor.withValues(alpha: 0.25),
                strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              for (final r in refLines)
                HorizontalLine(
                  y: _ty(r.value),
                  color: r.color,
                  strokeWidth: 1,
                  dashArray: const [5, 4],
                  label: r.label == null
                      ? HorizontalLineLabel(show: false)
                      : HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 4, bottom: 2),
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: r.color),
                          labelResolver: (_) => r.label!,
                        ),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: yStep,
                getTitlesWidget: (v, _) => Text(yLabel(_ty(v)),
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (maxX / 4).clamp(0.5, double.infinity),
                getTitlesWidget: (v, _) {
                  if (v <= 0 || v >= maxX) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(xLabel(v),
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: fill,
                color: color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
