import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../sports/sport.dart';
import '../../xiaomi/models.dart';
import '../format.dart';

/// A list of activities rendered as [ActivityTile]s. Presentational: pass the
/// records and an [onSelect] callback. Reused by Home (recent) and, later, by a
/// full History screen.
class ActivityList extends StatelessWidget {
  final List<SportRecord> records;
  final void Function(SportRecord) onSelect;
  const ActivityList({
    super.key,
    required this.records,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final r in records) ActivityTile(record: r, onSelect: onSelect),
        ],
      );
}

/// A single activity row: sport icon, headline (distance·pace or duration),
/// and a subtitle with date·duration·HR. Tapping calls [onSelect].
class ActivityTile extends StatelessWidget {
  final SportRecord record;
  final void Function(SportRecord) onSelect;
  const ActivityTile({
    super.key,
    required this.record,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final r = record;
    final sport = Sports.of(r.category);
    final locale = Localizations.localeOf(context).toString();
    final d = DateFormat('EEE d MMM, HH:mm', locale).format(r.localStart);
    final main = sport.hasDistance
        ? '${fmtDistanceKm(r.distanceM)} ${t.unitKm}  ·  ${fmtPace(r.avgPace)} ${t.paceUnit}'
        : fmtDuration(r.durationSec);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(sport.icon),
      title: Text(main),
      subtitle: Text('$d  ·  ${fmtDuration(r.durationSec)}'
          '${r.avgHr > 0 ? '  ·  ${t.hr} ${r.avgHr}' : ''}'),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => onSelect(r),
    );
  }
}
