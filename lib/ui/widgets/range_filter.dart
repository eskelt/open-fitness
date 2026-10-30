import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../stats/stats.dart';

/// Segmented time-range selector (Week / Month / Year / All) for the overview.
class RangeFilter extends StatelessWidget {
  final StatsRange value;
  final ValueChanged<StatsRange> onChanged;
  const RangeFilter({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    String label(StatsRange r) => switch (r) {
          StatsRange.week => t.rangeWeek,
          StatsRange.month => t.rangeMonth,
          StatsRange.year => t.rangeYear,
          StatsRange.all => t.rangeAll,
        };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: SegmentedButton<StatsRange>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          for (final r in StatsRange.values)
            ButtonSegment(value: r, label: Text(label(r))),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}
