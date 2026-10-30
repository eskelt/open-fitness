import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../stats/stats.dart';
import '../format.dart';

/// A Strava-like activity calendar: a Monday-first grid of weeks (one row each)
/// with active days highlighted (intensity by distance). A left gutter labels
/// the month at each month boundary so the days don't blur together. Shows the
/// last 4 weeks, expandable to 12. Active days are tappable via [onSelectDay].
/// Presentational: pass the per-day distance map in.
class ActivityCalendar extends StatefulWidget {
  final Map<DateTime, int> byDay;
  final String locale;
  final void Function(DateTime day)? onSelectDay;
  const ActivityCalendar({
    super.key,
    required this.byDay,
    required this.locale,
    this.onSelectDay,
  });

  @override
  State<ActivityCalendar> createState() => _ActivityCalendarState();
}

class _ActivityCalendarState extends State<ActivityCalendar> {
  bool _expanded = false;
  static const _collapsedWeeks = 4;
  static const _expandedWeeks = 12;
  static const _gutter = 34.0;

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
      final box = Container(
        height: 34,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: isToday ? Border.all(color: cs.onSurface, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child: Text('${day.day}',
            style: TextStyle(
                fontSize: 11,
                color: fg,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
      );
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: (active && widget.onSelectDay != null)
              ? InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => widget.onSelectDay!(day),
                  child: box,
                )
              : box,
        ),
      );
    }

    // A week "belongs" to the month of its Thursday (ISO convention); label it
    // on the left only when that month changes from the previous row.
    final rows = <Widget>[];
    (int, int)? prevKey;
    for (var i = weeks - 1; i >= 0; i--) {
      final ws = DateTime(
          curWeekStart.year, curWeekStart.month, curWeekStart.day - 7 * i);
      final thu = DateTime(ws.year, ws.month, ws.day + 3);
      final key = (thu.year, thu.month);
      final showLabel = prevKey == null || key != prevKey;
      prevKey = key;
      final label = showLabel
          ? DateFormat('MMM', widget.locale).format(thu).replaceAll('.', '')
          : '';
      rows.add(Row(children: [
        SizedBox(
          width: _gutter,
          child: Text(
            label.isEmpty ? '' : '${label[0].toUpperCase()}${label.substring(1)}',
            style: TextStyle(
                fontSize: 10,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600),
          ),
        ),
        for (var d = 0; d < 7; d++)
          cell(DateTime(ws.year, ws.month, ws.day + d)),
      ]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: _gutter),
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
