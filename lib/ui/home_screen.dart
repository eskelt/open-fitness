import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../data/repository.dart';
import '../sports/sport.dart';
import '../stats/stats.dart';
import '../xiaomi/models.dart';
import 'charts.dart';
import 'format.dart';
import 'i18n_helpers.dart';
import 'session_detail.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (repo.records.isEmpty) _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.refresh(onProgress: () {
        if (mounted) setState(() {});
      });
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    // Running-only for now: other sports are intentionally disabled. The Sports
    // registry and multi-sport stats stay in place for a future release.
    final runs = repo.runs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Fitness'),
        actions: [
          IconButton(
              tooltip: t.refresh,
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh)),
          IconButton(
              tooltip: t.settings,
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          IconButton(
              tooltip: t.logOut,
              onPressed: () async {
                await repo.logout();
                widget.onLogout();
              },
              icon: const Icon(Icons.logout)),
        ],
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: runs.isEmpty
            ? ListView(children: [
                const SizedBox(height: 120),
                Center(
                    child: _busy
                        ? const CircularProgressIndicator()
                        : Padding(
                            padding: const EdgeInsets.all(24),
                            child: SelectableText(
                                _error != null
                                    ? t.errorPrefix(_error!)
                                    : t.noDataYet,
                                textAlign: TextAlign.center))),
              ])
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                      child: _content(context, t, Sports.running, runs)),
                ],
              ),
      ),
    );
  }

  Widget _content(
      BuildContext context, L t, Sport sport, List<SportRecord> records) {
    final totals = Totals.from(records);
    final weeks = StatsTime.weekly(records, weeks: 12);
    final pr = PersonalRecords.from(records);
    final zones = HrZoneTotals.from(records);
    final locale = Localizations.localeOf(context).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summaryCard(context, t, sport, totals, records),
        _card(context, t.secWeeklyVolume,
            WeeklyVolumeChart(
                weeks: weeks,
                useDistance: sport.hasDistance,
                locale: locale)),
        if (sport.hasDistance || totals.durationSec > 0)
          _card(context, t.secRecords, _recordsGrid(context, t, sport, pr)),
        if (zones.total > 0)
          _card(context, t.secHrZones,
              HrZonesBar(zones: zones, names: hrZoneNames(t))),
        _recentList(context, t, records),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _card(BuildContext context, String title, Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      );

  Widget _summaryCard(BuildContext context, L t, Sport sport, Totals totals,
      List<SportRecord> records) {
    final tiles = <Widget>[
      if (sport.hasDistance)
        _stat(context, t.statDistance,
            fmtDistanceKm(totals.distanceM, decimals: 1), t.unitKm),
      _stat(context, t.statTime, fmtDurationLong(totals.durationSec), ''),
      if (sport.hasPace && totals.avgPace > 0)
        _stat(context, t.statAvgPace, fmtPace(totals.avgPace), t.paceUnit),
      if (totals.avgHr > 0)
        _stat(context, t.statAvgHr, '${totals.avgHr}', t.unitBpm),
      _stat(context, t.statCalories, '${totals.calories}', t.unitKcal),
      if (sport.hasDistance)
        _stat(context, t.statThisWeek,
            fmtDistanceKm(StatsTime.distanceThisWeek(records), decimals: 1),
            t.unitKm),
      if (sport.hasDistance)
        _stat(context, t.statThisMonth,
            fmtDistanceKm(StatsTime.distanceThisMonth(records), decimals: 1),
            t.unitKm),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 24,
            runSpacing: 16,
            children: tiles,
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, String unit) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: value,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: onSurface)),
                if (unit.isNotEmpty)
                  TextSpan(
                      text: ' $unit',
                      style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordsGrid(
      BuildContext context, L t, Sport sport, PersonalRecords pr) {
    final items = <Widget>[];
    void add(String label, Record? rec, String Function(Record) fmt) {
      if (rec == null) return;
      items.add(_recordTile(context, label, fmt(rec), rec.record));
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
    add(t.recMostCal, pr.mostCalories, (r) => '${r.value.round()} ${t.unitKcal}');
    add(t.recBestEffect, pr.bestTrainEffect,
        (r) => r.value.toStringAsFixed(1));

    return Column(children: items);
  }

  Widget _recordTile(
      BuildContext context, String label, String value, SportRecord r) {
    final locale = Localizations.localeOf(context).toString();
    final d = DateFormat('d MMM yyyy', locale).format(r.localStart);
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => SessionDetailScreen(r))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            SizedBox(
                width: 78,
                child: Text(d,
                    textAlign: TextAlign.right,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _recentList(BuildContext context, L t, List<SportRecord> records) {
    final recent = records.take(20).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.secRecent,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              for (final r in recent) _RunTile(r),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  final SportRecord r;
  const _RunTile(this.r);

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
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
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => SessionDetailScreen(r))),
    );
  }
}
