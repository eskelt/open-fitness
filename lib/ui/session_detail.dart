import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../data/repository.dart';
import '../stats/best_efforts.dart';
import '../stats/km_splits.dart';
import '../stats/stats.dart';
import '../units_controller.dart';
import '../xiaomi/models.dart';
import '../xiaomi/record_detail.dart';
import '../sports/sport.dart';
import 'charts.dart';
import 'format.dart';
import 'i18n_helpers.dart';
import 'route_map.dart';

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
        _M(t.detDistance, '${fmtDistance(r.distanceM)} ${distanceUnit(t)}'),
      _M(t.detDuration, fmtDuration(r.durationSec)),
      if (sport.hasPace && r.avgPace > 0)
        _M(t.detAvgPace, '${fmtPace(r.avgPace)} ${paceUnit(t)}'),
      if (sport.hasPace && r.maxPace > 0)
        _M(t.detMaxPace, '${fmtPace(r.maxPace)} ${paceUnit(t)}'),
      if (r.avgSpeed > 0)
        _M(t.detAvgSpeed, '${fmtSpeed(r.avgSpeed)} ${speedUnit(t)}'),
      if (r.maxSpeed > 0)
        _M(t.detMaxSpeed, '${fmtSpeed(r.maxSpeed)} ${speedUnit(t)}'),
      _M(t.detCalories, '${r.calories} ${t.unitKcal}'),
      if (sport.hasSteps && r.steps > 0) _M(t.detSteps, '${r.steps}'),
      if (sport.hasCadence && r.avgCadence > 0)
        _M(t.detAvgCadence, '${r.avgCadence} ${t.unitSpm}'),
      if (sport.hasStride && r.avgStride > 0)
        _M(t.detStride, '${fmtStride(r.avgStride)} ${strideUnit(t)}'),
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
          if (sport.hasDistance && r.isOutdoor) ...[
            const SizedBox(height: 20),
            Text(t.secRoute, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            RouteMapSection(r),
          ],
          if (sport.hasDistance && r.isOutdoor && r.distanceM >= 1000) ...[
            const SizedBox(height: 20),
            ListenableBuilder(
              listenable: unitsController,
              builder: (context, _) => _section(
                  context,
                  unitsController.imperial ? t.secSplitsMi : t.secSplits,
                  _SplitsSection(r)),
            ),
          ],
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
    return bestEfforts(parseRecordTrack(bytes));
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

/// Per-kilometer speed + average heart rate, rendered as a Mi Fitness-style
/// table: one row per whole km (plus the final partial), with a bar whose
/// length is proportional to that km's speed. Loaded on demand with a spinner.
class _SplitsSection extends StatefulWidget {
  final SportRecord record;
  const _SplitsSection(this.record);
  @override
  State<_SplitsSection> createState() => _SplitsSectionState();
}

class _SplitsSectionState extends State<_SplitsSection> {
  late final Future<RecordTrack> _future = _load();

  Future<RecordTrack> _load() async {
    final bytes = await repo.fdsRecordDetail(widget.record);
    return parseRecordTrack(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return FutureBuilder<RecordTrack>(
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
        // Segment by mile when the app is in imperial units, else by kilometer.
        // Computed here (not cached) so flipping the units setting re-segments.
        final splits = snap.hasError || snap.data == null
            ? const <KmSplit>[]
            : kmSplitStats(snap.data!,
                segmentM: unitsController.imperial ? 1609.344 : 1000);
        if (splits.isEmpty) {
          return Text(t.splitsNoData,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant));
        }

        final maxSpeed = splits
            .map((s) => s.speedKmh)
            .fold<double>(0, (a, b) => b > a ? b : a);
        final anyHr = splits.any((s) => s.avgHr > 0);

        final headerStyle = TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const SizedBox(width: 34),
                  Expanded(child: Text(t.colPace, style: headerStyle)),
                  SizedBox(
                      width: 70,
                      child: Text(paceUnit(t),
                          textAlign: TextAlign.right, style: headerStyle)),
                  if (anyHr)
                    SizedBox(
                        width: 58,
                        child: Text('${t.colHr} ${t.unitBpm}',
                            textAlign: TextAlign.right, style: headerStyle)),
                ],
              ),
            ),
            for (final s in splits)
              _SplitRow(
                  split: s, maxSpeed: maxSpeed, showHr: anyHr),
          ],
        );
      },
    );
  }
}

class _SplitRow extends StatelessWidget {
  final KmSplit split;
  final double maxSpeed;
  final bool showHr;
  const _SplitRow(
      {required this.split, required this.maxSpeed, required this.showHr});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final frac =
        maxSpeed > 0 ? (split.speedKmh / maxSpeed).clamp(0.05, 1.0) : 0.0;
    final label = split.isPartial
        ? fmtDistance(split.endDistanceM.round())
        : '${split.index}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 12,
                color: cs.surfaceContainerHighest,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                    decoration: BoxDecoration(
                      color: brandAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(fmtPace(split.paceSecPerKm),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          if (showHr)
            SizedBox(
              width: 58,
              child: Text(split.avgHr > 0 ? '${split.avgHr}' : '—',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}
