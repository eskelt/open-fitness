import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../stats/stats.dart';
import '../format.dart';

/// A Strava-like activity calendar: a Monday-first grid of days with active
/// days highlighted (intensity by distance). Shows the last 4 weeks, expandable
/// to 12. Presentational: pass the per-day distance map in.
class ActivityCalendar extends StatefulWidget {
  final Map<DateTime, int> byDay;
  final String locale;
  const ActivityCalendar({
    super.key,
    required this.byDay,
    required this.locale,
  });

  @override
  State<ActivityCalendar> createState() => _ActivityCalendarState();
}

class _ActivityCalendarState extends State<ActivityCalendar> {
  bool _expanded = false;
  static const _collapsedWeeks = 4;
  static const _expandedWeeks = 12;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final cs = Theme.of(context).colorScheme;
    final weeks = _expanded ? _expandedWeeks : _collapsedWeeks;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final curWeekStart = StatsTime.weekStart(now);
    final maxD = widget.byDay.values.isEmpty
        ? 0
        : widget.byDay.values.reduce((a, b) => a > b ? a : b);

    final headers = [
      for (var d = 0; d < 7; d++)
        DateFormat('EEEEE', widget.locale).format(DateTime(
            curWeekStart.year, curWeekStart.month, curWeekStart.day + d))
    ];

    Widget cell(DateTime day) {
      final active = widget.byDay.containsKey(day);
      final isFuture = day.isAfter(today);
      final isToday = day == today;
      Color bg;
      Color fg;
      if (active) {
        final dist = widget.byDay[day] ?? 0;
        final shade = maxD <= 0 ? 0.8 : (0.3 + 0.7 * (dist / maxD));
        bg = brandAccent.withValues(alpha: shade.clamp(0.3, 1.0).toDouble());
        fg = Colors.white;
      } else if (isFuture) {
        bg = Colors.transparent;
        fg = cs.onSurfaceVariant.withValues(alpha: 0.35);
      } else {
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
      }
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border:
                  isToday ? Border.all(color: cs.onSurface, width: 1.5) : null,
            ),
            alignment: Alignment.center,
            child: Text('${day.day}',
                style: TextStyle(
                    fontSize: 11,
                    color: fg,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = weeks - 1; i >= 0; i--) {
      final ws = DateTime(
          curWeekStart.year, curWeekStart.month, curWeekStart.day - 7 * i);
      rows.add(Row(children: [
        for (var d = 0; d < 7; d++)
          cell(DateTime(ws.year, ws.month, ws.day + d)),
      ]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final h in headers)
              Expanded(
                child: Center(
                  child: Text(h.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ...rows,
        const SizedBox(height: 2),
        Align(
          child: TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? t.showLess : t.showMore),
          ),
        ),
      ],
    );
  }
}
