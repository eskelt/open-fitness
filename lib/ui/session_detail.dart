import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../data/repository.dart';
import '../stats/best_efforts.dart';
import '../stats/elevation.dart';
import '../stats/km_splits.dart';
import '../stats/series.dart';
import '../stats/stats.dart';
import '../units_controller.dart';
import 'widgets/metric_line_chart.dart';
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

    final hasHr = r.avgHr > 0 || r.maxHr > 0 || r.minHr > 0;

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
          // Map first (the hero, like Strava/Garmin/Mi Fitness), then the stats.
          if (sport.hasDistance && r.isOutdoor) ...[
            Text(t.secRoute, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            RouteMapSection(r),
            const SizedBox(height: 20),
          ],
          _section(context, t.detMetrics, _grid(metrics)),
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
          if (sport.hasDistance && r.isOutdoor && r.distanceM >= 1000) ...[
            ListenableBuilder(
              listenable: unitsController,
              builder: (context, _) => _StreamChartsSection(r, sport),
            ),
          ],
          // Heart rate as one block: chart (when a stream exists) + avg/max/min +
          // zones. Shows for any run with HR, including indoor/short ones.
          if (hasHr) ...[
            const SizedBox(height: 20),
            ListenableBuilder(
              listenable: unitsController,
              builder: (context, _) => _HeartRateSection(r),
            ),
          ],
          // Elevation profile: a distance chart of its own (terrain/DEM derived),
          // separate from the map, like Strava/Garmin. Self-spaces and renders
          // nothing when there's no GPS/elevation.
          if (sport.hasDistance && r.isOutdoor)
            ListenableBuilder(
              listenable: unitsController,
              builder: (context, _) => _ElevationSection(r),
            ),
          if (sport.hasDistance && r.distanceM >= 1000) ...[
            const SizedBox(height: 20),
            _section(context, t.secBestEfforts, _BestEffortsSection(r)),
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

  Future<RecordTrack> _load() => repo.recordStream(widget.record);

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
                  const SizedBox(width: 50),
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
            width: 50,
            child: Text(label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
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

/// Per-second line charts for a run (pace, heart rate, …). Reuses the single
/// [MetricLineChart] widget for every metric and the shared [repo.recordStream]
/// download, and renders one card per [Sport.chartChannels] entry that this
/// screen supports and that has real data. HR uses a fixed red, pace the brand
/// accent with an inverted axis (faster = higher), like Strava/Garmin.
class _StreamChartsSection extends StatefulWidget {
  final SportRecord record;
  final Sport sport;
  const _StreamChartsSection(this.record, this.sport);
  @override
  State<_StreamChartsSection> createState() => _StreamChartsSectionState();
}

class _StreamChartsSectionState extends State<_StreamChartsSection> {
  late final Future<RecordTrack> _future = repo.recordStream(widget.record);

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return FutureBuilder<RecordTrack>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        if (snap.hasError || snap.data == null) return const SizedBox.shrink();
        final track = snap.data!;
        final cards = <Widget>[];
        for (final ch in widget.sport.chartChannels) {
          final card = _chartFor(context, t, ch, track);
          if (card != null) {
            cards.add(const SizedBox(height: 20));
            cards.add(card);
          }
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: cards);
      },
    );
  }

  Widget? _chartFor(
      BuildContext context, L t, TrackChannel ch, RecordTrack track) {
    final imp = unitsController.imperial;
    String xTick(double v) => distanceKmToUnit(v).toStringAsFixed(imp ? 1 : 0);
    String xTip(double v) =>
        '${distanceKmToUnit(v).toStringAsFixed(2)} ${distanceUnit(t)}';

    final r = widget.record;
    final cs = Theme.of(context).colorScheme;

    switch (ch) {
      case TrackChannel.hr:
        return null; // rendered by the dedicated, unified _HeartRateSection
      case TrackChannel.pace:
        final s = paceSeries(track);
        if (s.isEmpty) return null;
        final refs = <ChartRefLine>[
          if (r.avgPace > 0)
            ChartRefLine(r.avgPace.toDouble(), color: cs.onSurfaceVariant),
          if (r.maxPace > 0)
            ChartRefLine(r.maxPace.toDouble(), color: brandAccent),
        ];
        return _chartCard(
          context,
          t.secPace,
          MetricLineChart(
            x: s.x,
            y: s.y,
            color: brandAccent,
            invertY: true,
            yLabel: (v) => fmtPace(v.round()),
            xLabel: xTick,
            tooltip: (x, y) => '${fmtPace(y.round())} ${paceUnit(t)}\n${xTip(x)}',
            refLines: refs,
          ),
          stats: [
            if (r.avgPace > 0)
              _Stat(t.statAvg, fmtPace(r.avgPace), paceUnit(t)),
            if (r.maxPace > 0)
              _Stat(t.statMax, fmtPace(r.maxPace), paceUnit(t)),
          ],
        );
      case TrackChannel.speed:
      case TrackChannel.cadence:
      case TrackChannel.elevation:
      case TrackChannel.power:
        return null; // not rendered on this screen yet
    }
  }

}

/// A chart card: section title, big avg/max figures on their own line, then the
/// chart inside a Card. Shared by the stream charts and the heart-rate section.
Widget _chartCard(BuildContext context, String title, Widget chart,
    {List<_Stat> stats = const []}) {
  final theme = Theme.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: theme.textTheme.titleMedium),
      if (stats.isNotEmpty) ...[
        const SizedBox(height: 8),
        _bigStats(context, stats),
      ],
      const SizedBox(height: 10),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 12, 12), child: chart),
      ),
    ],
  );
}

/// A row of big avg/max/min figures on their own line under the section title,
/// like Strava/Mi Fitness. Reused by every chart (HR, pace, …).
Widget _bigStats(BuildContext context, List<_Stat> stats) {
  final cs = Theme.of(context).colorScheme;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < stats.length; i++) ...[
        if (i > 0) const SizedBox(width: 32),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stats[i].label.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: cs.onSurfaceVariant)),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(stats[i].value,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700)),
                if (stats[i].unit.isNotEmpty)
                  Text(' ${stats[i].unit}',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ],
    ],
  );
}

/// Heart rate as one unified block: the per-second HR chart (when a stream is
/// available) plus big avg/max/min figures and the HR-zones bar. The figures and
/// zones come from the summary, so the block renders for every run with HR,
/// including indoor/short ones that have no downloadable stream.
class _HeartRateSection extends StatefulWidget {
  final SportRecord record;
  const _HeartRateSection(this.record);
  @override
  State<_HeartRateSection> createState() => _HeartRateSectionState();
}

class _HeartRateSectionState extends State<_HeartRateSection> {
  // Only outdoor runs of a meaningful length have a per-second stream worth
  // downloading; for the rest we just show the summary figures + zones.
  late final bool _withChart =
      widget.record.isOutdoor && widget.record.distanceM >= 1000;
  late final Future<RecordTrack>? _future =
      _withChart ? repo.recordStream(widget.record) : null;

  static const _hrColor = Color(0xFFEB5757);

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final r = widget.record;
    final cs = Theme.of(context).colorScheme;

    final stats = <_Stat>[
      if (r.avgHr > 0) _Stat(t.statAvg, '${r.avgHr}', t.unitBpm),
      if (r.maxHr > 0) _Stat(t.statMax, '${r.maxHr}', t.unitBpm),
      if (r.minHr > 0) _Stat(t.statMin, '${r.minHr}', t.unitBpm),
    ];
    final zoneTotals = HrZoneTotals.from([r]);
    final Widget? zones = zoneTotals.total > 0
        ? HrZonesBar(zones: zoneTotals, names: hrZoneNames(t))
        : null;

    if (!_withChart) return _card(context, t, stats, null, zones);

    return FutureBuilder<RecordTrack>(
      future: _future,
      builder: (context, snap) {
        Widget? chart;
        if (snap.connectionState == ConnectionState.done &&
            !snap.hasError &&
            snap.data != null) {
          final s = hrSeries(snap.data!);
          if (!s.isEmpty) {
            final imp = unitsController.imperial;
            String xTick(double v) =>
                distanceKmToUnit(v).toStringAsFixed(imp ? 1 : 0);
            String xTip(double v) =>
                '${distanceKmToUnit(v).toStringAsFixed(2)} ${distanceUnit(t)}';
            final refs = <ChartRefLine>[
              if (r.avgHr > 0)
                ChartRefLine(r.avgHr.toDouble(), color: cs.onSurfaceVariant),
              if (r.maxHr > 0)
                ChartRefLine(r.maxHr.toDouble(), color: _hrColor),
            ];
            chart = MetricLineChart(
              x: s.x,
              y: s.y,
              color: _hrColor,
              yLabel: (v) => '${v.round()}',
              xLabel: xTick,
              tooltip: (x, y) => '${y.round()} ${t.unitBpm}\n${xTip(x)}',
              refLines: refs,
            );
          }
        }
        // Stats + zones show immediately; the chart pops in when the stream
        // resolves (no separate spinner — the block is already useful).
        return _card(context, t, stats, chart, zones);
      },
    );
  }

  /// Title + big figures, then a Card holding the chart and/or zones. The Card is
  /// omitted when there's neither (summary-only HR with no zones).
  Widget _card(BuildContext context, L t, List<_Stat> stats, Widget? chart,
      Widget? zones) {
    final theme = Theme.of(context);
    final body = <Widget>[
      if (chart != null) chart,
      if (chart != null && zones != null) const SizedBox(height: 16),
      if (zones != null) zones,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.detHeartRate, style: theme.textTheme.titleMedium),
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 8),
          _bigStats(context, stats),
        ],
        if (body.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 12, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
            ),
          ),
        ],
      ],
    );
  }
}

/// Terrain-elevation profile as a standalone distance chart (ascent/descent as
/// the big figures, like Strava/Garmin), decoupled from the map. Elevation is
/// derived from the route via a DEM (the watch reports no altitude), so the
/// source is noted under the chart. Fetches the GPS track itself (cached by the
/// repo, so it shares the map's download) and renders nothing when unavailable.
class _ElevationSection extends StatefulWidget {
  final SportRecord record;
  const _ElevationSection(this.record);
  @override
  State<_ElevationSection> createState() => _ElevationSectionState();
}

class _ElevationSectionState extends State<_ElevationSection> {
  late final Future<ElevationProfile?> _future = _load();

  Future<ElevationProfile?> _load() async {
    try {
      final track = await repo.fdsGpsTrack(widget.record);
      if (track.points.length < 2) return null;
      return await repo.runElevation(widget.record, track);
    } catch (_) {
      return null; // expired / unavailable — the map already explains it
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final theme = Theme.of(context);
    return FutureBuilder<ElevationProfile?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink(); // no spinner; pops in when ready
        }
        final p = snap.data;
        if (p == null || p.isEmpty) return const SizedBox.shrink();
        final imp = unitsController.imperial;
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MetricLineChart(
              x: p.distKm,
              y: p.eleM,
              color: theme.colorScheme.primary,
              fill: true,
              height: 150,
              yLabel: (v) => '${elevToUnit(v).round()}',
              xLabel: (v) =>
                  distanceKmToUnit(v).toStringAsFixed(imp ? 1 : 0),
              tooltip: (x, y) => '${elevToUnit(y).round()} ${elevUnit(t)}\n'
                  '${distanceKmToUnit(x).toStringAsFixed(2)} ${distanceUnit(t)}',
            ),
            const SizedBox(height: 6),
            Text(t.elevSource,
                style: TextStyle(
                    fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          ],
        );
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _chartCard(
            context,
            t.secElevation,
            body,
            stats: [
              _Stat(t.detAscent, fmtElevation(p.gain), elevUnit(t)),
              _Stat(t.detDescent, fmtElevation(p.loss), elevUnit(t)),
            ],
          ),
        );
      },
    );
  }
}

/// A labelled figure (avg/max) shown above a chart.
class _Stat {
  final String label;
  final String value;
  final String unit;
  const _Stat(this.label, this.value, this.unit);
}
