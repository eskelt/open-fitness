import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../data/repository.dart';
import '../stats/best_efforts.dart';
import '../stats/stats.dart';
import '../xiaomi/models.dart';
import '../xiaomi/record_detail.dart';
import '../sports/sport.dart';
import 'charts.dart';
import 'format.dart';
import 'i18n_helpers.dart';

class SessionDetailScreen extends StatelessWidget {
  final SportRecord r;
  const SessionDetailScreen(this.r, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final sport = Sports.of(r.category);
    final locale = Localizations.localeOf(context).toString();
    final date =
        DateFormat('EEEE d MMMM yyyy · HH:mm', locale).format(r.localStart);

    final metrics = <_M>[
      if (sport.hasDistance)
        _M(t.detDistance, '${fmtDistanceKm(r.distanceM)} ${t.unitKm}'),
      _M(t.detDuration, fmtDuration(r.durationSec)),
      if (sport.hasPace && r.avgPace > 0)
        _M(t.detAvgPace, '${fmtPace(r.avgPace)} ${t.paceUnit}'),
      if (sport.hasPace && r.maxPace > 0)
        _M(t.detMaxPace, '${fmtPace(r.maxPace)} ${t.paceUnit}'),
      if (r.avgSpeed > 0)
        _M(t.detAvgSpeed, '${fmtSpeedKmh(r.avgSpeed)} ${t.unitKmh}'),
      if (r.maxSpeed > 0)
        _M(t.detMaxSpeed, '${fmtSpeedKmh(r.maxSpeed)} ${t.unitKmh}'),
      _M(t.detCalories, '${r.calories} ${t.unitKcal}'),
      if (sport.hasSteps && r.steps > 0) _M(t.detSteps, '${r.steps}'),
      if (sport.hasCadence && r.avgCadence > 0)
        _M(t.detAvgCadence, '${r.avgCadence} ${t.unitSpm}'),
      if (sport.hasStride && r.avgStride > 0)
        _M(t.detStride, '${r.avgStride} ${t.cmUnit}'),
      if (r.vo2max > 0) _M(t.detVo2max, '${r.vo2max}'),
      if (r.trainEffect > 0)
        _M(t.detTrainEffect, r.trainEffect.toStringAsFixed(1)),
      if (r.anaerobicTrainEffect > 0)
        _M(t.detAnaerobicEffect, r.anaerobicTrainEffect.toStringAsFixed(1)),
      if (r.trainLoad > 0) _M(t.detTrainLoad, '${r.trainLoad}'),
      if (r.recoverTimeH > 0)
        _M(t.detRecoverTime, t.recoverHours(r.recoverTimeH)),
    ];

    final hr = <_M>[
      if (r.avgHr > 0) _M(t.detAvgHr, '${r.avgHr} ${t.unitBpm}'),
      if (r.maxHr > 0) _M(t.detMaxHr, '${r.maxHr} ${t.unitBpm}'),
      if (r.minHr > 0) _M(t.detMinHr, '${r.minHr} ${t.unitBpm}'),
    ];

    final preds = <_M>[
      if (r.pred5k > 0) _M(t.detPred5k, fmtDuration(r.pred5k)),
      if (r.pred10k > 0) _M(t.detPred10k, fmtDuration(r.pred10k)),
      if (r.predHalf > 0) _M(t.detPredHalf, fmtDuration(r.predHalf)),
      if (r.predFull > 0) _M(t.detPredFull, fmtDuration(r.predFull)),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(sportLabel(t, sport))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(sport.icon, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(date,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _section(context, t.detMetrics, _grid(metrics)),
          if (sport.hasDistance && r.distanceM >= 1000) ...[
            const SizedBox(height: 20),
            _section(context, t.secBestEfforts, _BestEffortsSection(r)),
          ],
          if (hr.isNotEmpty) ...[
            const SizedBox(height: 20),
            _section(
              context,
              t.detHeartRate,
              Column(
                children: [
                  _grid(hr),
                  if (HrZoneTotals.from([r]).total > 0) ...[
                    const SizedBox(height: 16),
                    HrZonesBar(
                        zones: HrZoneTotals.from([r]),
                        names: hrZoneNames(t)),
                  ],
                ],
              ),
            ),
          ],
          if (preds.isNotEmpty) ...[
            const SizedBox(height: 20),
            _section(context, t.detPredictions, _grid(preds)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }


  Widget _section(BuildContext context, String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ],
    );
  }

  Widget _grid(List<_M> items) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: _cell(items[i])),
                Expanded(
                    child: i + 1 < items.length
                        ? _cell(items[i + 1])
                        : const SizedBox()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(_M m) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.label,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(m.value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      );
}

class _M {
  final String label;
  final String value;
  _M(this.label, this.value);
}

/// Fetches this session's FDS detail blob, parses the per-second track and
/// shows the fastest split for each standard distance (Strava-style best
/// efforts). Loaded on demand with a spinner.
class _BestEffortsSection extends StatefulWidget {
  final SportRecord record;
  const _BestEffortsSection(this.record);
  @override
  State<_BestEffortsSection> createState() => _BestEffortsSectionState();
}

class _BestEffortsSectionState extends State<_BestEffortsSection> {
  late final Future<List<double?>> _future = _load();

  Future<List<double?>> _load() async {
    final bytes = await repo.fdsRecordDetail(widget.record);
    final track =
        parseRecordTrack(bytes, summaryDistanceM: widget.record.distanceM);
    return bestEfforts(track);
  }

  static const _labels = ['1 km', '1 mi', '5 km', '10 km', '21.1 km', '42.2 km'];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<double?>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        if (snap.hasError) {
          return Text('—',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant));
        }
        final efforts = snap.data!;
        final rows = <Widget>[];
        for (var i = 0; i < efforts.length; i++) {
          final e = efforts[i];
          if (e == null) continue; // run shorter than this distance
          rows.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                    child: Text(_labels[i],
                        style: const TextStyle(fontSize: 14))),
                Text(fmtDuration(e.round()),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ));
        }
        if (rows.isEmpty) {
          return Text('—',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant));
        }
        return Column(children: rows);
      },
    );
  }
}
