import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../data/repository.dart';
import '../stats/stats.dart';
import '../xiaomi/models.dart';
import 'format.dart';
import 'session_detail.dart';
import 'widgets/activity_list.dart';

/// Full activity history, grouped by month in collapsible sections (newest
/// first), each with that month's totals. Reuses [ActivityList].
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  void _open(BuildContext context, SportRecord r) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => SessionDetailScreen(r)));

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.navHistory)),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final groups = groupByMonth(repo.runs);
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(t.noDataYet, textAlign: TextAlign.center),
              ),
            );
          }
          final locale = Localizations.localeOf(context).toString();
          return ListView.builder(
            padding: const EdgeInsets.only(top: 6, bottom: 24),
            itemCount: groups.length,
            itemBuilder: (context, i) =>
                _MonthCard(group: groups[i], locale: locale, expanded: i == 0,
                    onSelect: (r) => _open(context, r)),
          );
        },
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final MonthGroup group;
  final String locale;
  final bool expanded;
  final void Function(SportRecord) onSelect;
  const _MonthCard({
    required this.group,
    required this.locale,
    required this.expanded,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final totals = group.totals;
    final raw = DateFormat('MMMM yyyy', locale).format(group.month);
    final month = raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
    final subtitle =
        '${t.statRuns(totals.count)}  ·  ${fmtDistanceKm(totals.distanceM, decimals: 1)} ${t.unitKm}';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Theme(
        // Hide ExpansionTile's default top/bottom divider lines.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          title: Text(month, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(subtitle,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          children: [ActivityList(records: group.records, onSelect: onSelect)],
        ),
      ),
    );
  }
}
