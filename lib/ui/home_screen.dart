import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../data/repository.dart';
import '../sports/sport.dart';
import '../stats/stats.dart';
import '../xiaomi/models.dart';
import 'charts.dart';
import 'i18n_helpers.dart';
import 'session_detail.dart';
import 'settings_screen.dart';
import 'widgets/activity_calendar.dart';
import 'widgets/activity_list.dart';
import 'widgets/range_filter.dart';
import 'widgets/records_list.dart';
import 'widgets/section_card.dart';
import 'widgets/summary_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  /// Called from the "See all" action on the recent-activities section (the
  /// shell switches to the History tab).
  final VoidCallback? onSeeAllActivities;
  const HomeScreen({
    super.key,
    required this.onLogout,
    this.onSeeAllActivities,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  String? _error;
  StatsRange _range = StatsRange.month;

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

  void _openSession(SportRecord r) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => SessionDetailScreen(r)));

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
    // The filter scopes the overview hero; the trend/records/recent sections
    // stay global (all-time) by design.
    final rangeRecords = recordsInRange(records, _range);
    final totals = Totals.from(rangeRecords);
    final previous = _range == StatsRange.all
        ? null
        : Totals.from(recordsInPreviousRange(records, _range));
    final weeks = StatsTime.weekly(records, weeks: 12);
    final pr = PersonalRecords.from(records);
    final zones = HrZoneTotals.from(records);
    final locale = Localizations.localeOf(context).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RangeFilter(
            value: _range, onChanged: (r) => setState(() => _range = r)),
        SummaryCard(
            sport: sport, range: _range, totals: totals, previous: previous),
        SectionCard(
          title: t.secActivity,
          child: ActivityCalendar(
              byDay: StatsTime.distanceByDay(records), locale: locale),
        ),
        SectionCard(
          title: t.secWeeklyVolume,
          child: WeeklyVolumeChart(
              weeks: weeks, useDistance: sport.hasDistance, locale: locale),
        ),
        SectionCard(
          title: t.secRecords,
          child: RecordsList(sport: sport, records: pr, onSelect: _openSession),
        ),
        if (zones.total > 0)
          SectionCard(
            title: t.secHrZones,
            child: HrZonesBar(zones: zones, names: hrZoneNames(t)),
          ),
        SectionCard(
          title: t.secRecent,
          action: widget.onSeeAllActivities == null
              ? null
              : TextButton(
                  onPressed: widget.onSeeAllActivities,
                  child: Text(t.seeAll)),
          child: ActivityList(
              records: records.take(6).toList(), onSelect: _openSession),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
