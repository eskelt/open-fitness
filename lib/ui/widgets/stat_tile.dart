import 'package:flutter/material.dart';

/// A single labelled metric: a small muted label over a bold value with an
/// optional unit. Used in the summary and reusable anywhere a stat is shown.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
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
}
