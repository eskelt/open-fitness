import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../data/repository.dart';
import '../xiaomi/models.dart';
import 'format.dart';
import 'session_detail.dart';
import 'widgets/section_card.dart';

/// Records by distance across all runs: the fastest 1k / 1mi / 5k / 10k / half /
/// marathon, with the top 3 and an evolution chart per distance. Computing them
/// fetches each run's detail once (cached), so the first open shows progress.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

List<String> distanceLabels(L t) =>
    ['1 km', '1 mi', '5 km', '10 km', t.detPredHalf, t.detPredFull];

class _RecordsScreenState extends State<RecordsScreen> {
  bool _computing = false;
  int _done = 0, _total = 0;
  List<List<MapEntry<SportRecord, double>>>? _ranked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pending = await repo.pendingBestEfforts();
    if (pending > 0) {
      setState(() {
        _computing = true;
        _done = 0;
        _total = pending;
      });
      await repo.computeAllBestEfforts(onProgress: (d, t) {
        if (mounted) setState(() => _done = d);
      });
    }
    final ranked = await repo.rankedRecords();
    if (mounted) {
      setState(() {
        _ranked = ranked;
        _computing = false;
      });
    }
  }

  void _open(SportRecord r) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => SessionDetailScreen(r)));

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.navRecords)),
      body: _computing
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LinearProgressIndicator(
                      value: _total > 0 ? _done / _total : null),
                  const SizedBox(height: 12),
                  Text(t.recordsAnalyzing(_done, _total),
                      textAlign: TextAlign.center),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _buildList(context, t),
            ),
    );
  }

  Widget _buildList(BuildContext context, L t) {
    final ranked = _ranked;
    final labels = distanceLabels(t);
    final hasAny = ranked != null && ranked.any((l) => l.isNotEmpty);
    if (!hasAny) {
      return ListView(children: [
        const SizedBox(height: 120),
        Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.recordsEmpty, textAlign: TextAlign.center))),
      ]);
    }
    final locale = Localizations.localeOf(context).toString();
    final df = DateFormat('d MMM yyyy', locale);
    final cards = <Widget>[];
    for (var i = 0; i < ranked.length; i++) {
      final list = ranked[i];
      if (list.isEmpty) continue;
      cards.add(SectionCard(
        title: labels[i],
        action: list.length > 1
            ? TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _EvolutionScreen(labels[i], list))),
                child: Text(t.recordsEvolution))
            : null,
        child: Column(
          children: [
            for (var rank = 0; rank < list.length && rank < 3; rank++)
              _row(context, rank + 1, list[rank], df),
          ],
        ),
      ));
    }
    return ListView(padding: const EdgeInsets.only(top: 6, bottom: 24), children: cards);
  }

  Widget _row(BuildContext context, int rank, MapEntry<SportRecord, double> e,
      DateFormat df) {
    final best = rank == 1;
    return InkWell(
      onTap: () => _open(e.key),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
                width: 22,
                child: Text('$rank',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600))),
            Expanded(
              child: Text(df.format(e.key.localStart),
                  style: const TextStyle(fontSize: 14)),
            ),
            Text(fmtDuration(e.value.round()),
                style: TextStyle(
                    fontSize: best ? 20 : 16,
                    fontWeight: best ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// A line chart of a single distance's time across runs, oldest to newest.
class _EvolutionScreen extends StatelessWidget {
  final String label;
  final List<MapEntry<SportRecord, double>> entries;
  const _EvolutionScreen(this.label, this.entries);

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final locale = Localizations.localeOf(context).toString();
    final byDate = [...entries]
      ..sort((a, b) => a.key.time.compareTo(b.key.time));
    final spots = [
      for (var i = 0; i < byDate.length; i++)
        FlSpot(i.toDouble(), byDate[i].value / 60.0) // minutes
    ];
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.15).clamp(0.5, double.infinity);

    return Scaffold(
      appBar: AppBar(title: Text('$label · ${t.recordsEvolution}')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 16, 16),
        child: LineChart(LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(fmtDuration((v * 60).round()),
                    style: const TextStyle(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (byDate.length / 4).ceilToDouble().clamp(1, 1e9),
                getTitlesWidget: (v, _) {
                  final i = v.round();
                  if (i < 0 || i >= byDate.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        DateFormat('MMM yy', locale)
                            .format(byDate[i].key.localStart),
                        style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: brandAccent,
              barWidth: 2,
              dotData: FlDotData(show: spots.length <= 40),
            ),
          ],
        )),
      ),
    );
  }
}
