import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'records_screen.dart';

/// Signed-in app shell: a bottom [NavigationBar] switching between Home,
/// History and Records. Uses an [IndexedStack] so each tab keeps its state;
/// History and Records are built lazily on first visit (Records fetches detail
/// data, so we don't want it running on launch).
class RootShell extends StatefulWidget {
  final VoidCallback onLogout;
  const RootShell({super.key, required this.onLogout});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  final _visited = <int>{0};

  void _go(int i) => setState(() {
        _index = i;
        _visited.add(i);
      });

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onLogout: widget.onLogout,
            onSeeAllActivities: () => _go(1),
          ),
          _visited.contains(1) ? const HistoryScreen() : const SizedBox(),
          _visited.contains(2) ? const RecordsScreen() : const SizedBox(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: t.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.format_list_bulleted),
            label: t.navHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: const Icon(Icons.emoji_events),
            label: t.navRecords,
          ),
        ],
      ),
    );
  }
}
