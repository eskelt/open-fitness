import 'package:flutter/material.dart';

/// A titled card used for each section on a screen: a bold title with content
/// below, with consistent padding and margins. Presentational and reusable:
/// pass the title and the body widget, it owns no data or state.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  /// Optional trailing widget in the title row (e.g. a "See all" button).
  final Widget? action;
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    if (action != null) action!,
                  ],
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      );
}
