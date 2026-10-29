import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../stats/stats.dart';
import 'format.dart';

/// Weekly volume bars (single series = magnitude -> one brand color).
/// The current week is highlighted. [useDistance] toggles km vs minutes.
class WeeklyVolumeChart extends StatelessWidget {
  final List<WeekBucket> weeks;
  final bool useDistance;
  final String locale;
  const WeeklyVolumeChart({
    super.key,
    required this.weeks,
    required this.useDistance,
    required this.locale,
  });

  double _val(WeekBucket w) =>
      useDistance ? w.km : w.durationSec / 60.0; // km or min

  @override
  Widget build(BuildContext context) {
    final maxV = weeks.fold<double>(0, (m, w) => _val(w) > m ? _val(w) : m);
    final top = maxV <= 0 ? 1.0 : maxV * 1.2;
    final theme = Theme.of(context);
    final thisWeek = StatsTime.weekStart(DateTime.now());
    final df = DateFormat('d/M', locale);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: top,
          alignment: BarChartAlignment.spaceBetween,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.surfaceContainerHighest,
              getTooltipItem: (group, _, rod, __) {
                final w = weeks[group.x];
                final v = _val(w);
                final label = useDistance
                    ? '${v.toStringAsFixed(1)} km'
                    : '${v.round()} min';
                return BarTooltipItem(
                  '${df.format(w.weekStart)}\n$label  ·  ${w.count}',
                  TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: top / 3,
            getDrawingHorizontalLine: (_) => FlLine(
                color: theme.dividerColor.withValues(alpha: 0.25),
                strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: top / 3,
                getTitlesWidget: (v, _) => Text(
                  v >= 1000
                      ? '${(v / 1000).toStringAsFixed(0)}k'
                      : v.toStringAsFixed(0),
                  style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= weeks.length) return const SizedBox();
                  // show ~5 labels to avoid clutter
                  final step = (weeks.length / 5).ceil();
                  if (i % step != 0 && i != weeks.length - 1) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(df.format(weeks[i].weekStart),
                        style: TextStyle(
                            fontSize: 9,
                            color: theme.colorScheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < weeks.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: _val(weeks[i]),
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4)),
                  color: weeks[i].weekStart == thisWeek
                      ? brandAccent
                      : brandAccent.withValues(alpha: 0.55),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Horizontal stacked bar of HR zones + a legend with name and duration.
/// The color is the intensity ramp; identity is also carried by the label.
class HrZonesBar extends StatelessWidget {
  final HrZoneTotals zones;
  final List<String> names; // 5 i18n names in order
  const HrZonesBar({super.key, required this.zones, required this.names});

  @override
  Widget build(BuildContext context) {
    final total = zones.total;
    final theme = Theme.of(context);
    if (total <= 0) {
      return Text('--',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant));
    }
    final vals = zones.asList;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              for (var i = 0; i < 5; i++)
                if (vals[i] > 0)
                  Expanded(
                    flex: vals[i],
                    child: Container(
                      height: 16,
                      margin: EdgeInsets.only(right: i < 4 && vals[i] > 0 ? 2 : 0),
                      color: hrZoneColors[i],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < 5; i++)
          if (vals[i] > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: hrZoneColors[i],
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(names[i], style: const TextStyle(fontSize: 13))),
                  Text(fmtDuration(vals[i]),
                      style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 38,
                    child: Text('${(vals[i] * 100 / total).round()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
