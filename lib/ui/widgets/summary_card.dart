import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../sports/sport.dart';
import '../../stats/stats.dart';
import '../format.dart';

/// The overview hero card for the selected [range]: a big primary metric
/// (distance for runs, else time) with a delta vs the previous period, over a
/// row of secondary stats (runs, time, pace, HR, calories). Presentational:
/// the screen computes the totals and passes them in.
class SummaryCard extends StatelessWidget {
  final Sport sport;
  final StatsRange range;
  final Totals totals;
  final Totals? previous; // previous equivalent period; null for "all"
  const SummaryCard({
    super.key,
    required this.sport,
    required this.range,
    required this.totals,
    this.previous,
  });

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurfaceVariant;

    final rangeLabel = switch (range) {
      StatsRange.week => t.rangeThisWeek,
      StatsRange.month => t.rangeThisMonth,
      StatsRange.year => t.rangeThisYear,
      StatsRange.all => t.rangeAllTime,
    };

    // Primary metric: distance for distance sports, otherwise time.
    final useDistance = sport.hasDistance;
    final heroValue = useDistance
        ? fmtDistanceKm(totals.distanceM, decimals: 1)
        : fmtDurationLong(totals.durationSec);
    final heroUnit = useDistance ? t.unitKm : '';
    final cur = useDistance ? totals.distanceM : totals.durationSec;
    final prev = previous == null
        ? null
        : (useDistance ? previous!.distanceM : previous!.durationSec);

    final secondary = <Widget>[
      _mini(context, t.statRuns(totals.count), ''),
      if (useDistance)
        _mini(context, fmtDurationLong(totals.durationSec), ''),
      if (sport.hasPace && totals.avgPace > 0)
        _mini(context, fmtPace(totals.avgPace), t.paceUnit),
      if (totals.avgHr > 0) _mini(context, '${totals.avgHr}', t.unitBpm),
      _mini(context, '${totals.calories}', t.unitKcal),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rangeLabel,
                  style: TextStyle(
                      fontSize: 12,
                      color: muted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(heroValue,
                            style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                                color: cs.onSurface)),
                        if (heroUnit.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(heroUnit,
                              style: TextStyle(fontSize: 16, color: muted)),
                        ],
                      ],
                    ),
                  ),
                  _DeltaChip(
                      current: cur, previous: prev, label: t.deltaVsPrevious),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 22, runSpacing: 12, children: secondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(BuildContext context, String value, String unit) {
    final cs = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface)),
        if (unit.isNotEmpty)
          TextSpan(
              text: ' $unit',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

/// A small "▲ 12% vs previous" pill. Hidden when there is no comparable
/// previous value. Green when the metric went up, red when it went down.
class _DeltaChip extends StatelessWidget {
  final int current;
  final int? previous;
  final String label;
  const _DeltaChip(
      {required this.current, required this.previous, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = previous;
    if (p == null || p == 0) return const SizedBox.shrink();
    final pct = ((current - p) / p * 100).round();
    if (pct == 0) return const SizedBox.shrink();
    final up = pct > 0;
    final color = up ? const Color(0xFF37C2A6) : const Color(0xFFEB5757);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                size: 14, color: color),
            const SizedBox(width: 2),
            Text('${pct.abs()}%',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
