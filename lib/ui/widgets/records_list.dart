import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../sports/sport.dart';
import '../../stats/stats.dart';
import '../../xiaomi/models.dart';
import '../format.dart';

/// The personal-records list (longest distance/time, fastest pace, best VO2max,
/// most calories, best effect). Each row is tappable; [onSelect] is called with
/// the session that holds the record, so the widget stays navigation-agnostic.
class RecordsList extends StatelessWidget {
  final Sport sport;
  final PersonalRecords records;
  final void Function(SportRecord) onSelect;
  const RecordsList({
    super.key,
    required this.sport,
    required this.records,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final pr = records;
    final items = <Widget>[];
    void add(String label, Record? rec, String Function(Record) fmt) {
      if (rec == null) return;
      items.add(_RecordRow(
          label: label, value: fmt(rec), record: rec.record, onSelect: onSelect));
    }

    if (sport.hasDistance) {
      add(t.recLongestDist, pr.longestDistance,
          (r) => '${fmtDistanceKm(r.value.round())} ${t.unitKm}');
    }
    add(t.recLongestTime, pr.longestDuration,
        (r) => fmtDuration(r.value.round()));
    if (sport.hasPace) {
      add(t.recFastestPace, pr.fastestPace,
          (r) => '${fmtPace(r.value.round())} ${t.paceUnit}');
    }
    add(t.recBestVo2, pr.bestVo2max, (r) => '${r.value.round()}');
    add(t.recMostCal, pr.mostCalories,
        (r) => '${r.value.round()} ${t.unitKcal}');
    add(t.recBestEffect, pr.bestTrainEffect,
        (r) => r.value.toStringAsFixed(1));

    return Column(children: items);
  }
}

class _RecordRow extends StatelessWidget {
  final String label;
  final String value;
  final SportRecord record;
  final void Function(SportRecord) onSelect;
  const _RecordRow({
    required this.label,
    required this.value,
    required this.record,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final d = DateFormat('d MMM yyyy', locale).format(record.localStart);
    return InkWell(
      onTap: () => onSelect(record),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            SizedBox(
                width: 78,
                child: Text(d,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, color: Colors.grey))),
          ],
        ),
      ),
    );
  }
}
