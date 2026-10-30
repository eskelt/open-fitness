import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'history_screen.dart';
import 'home_screen.dart';

/// Signed-in app shell: a bottom [NavigationBar] switching between Home and
/// History. Uses an [IndexedStack] so each tab keeps its scroll/filter state.
class RootShell extends StatefulWidget {
  final VoidCallback onLogout;
  const RootShell({super.key, required this.onLogout});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onLogout: widget.onLogout,
            onSeeAllActivities: () => setState(() => _index = 1),
          ),
          const HistoryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
        ],
      ),
    );
  }
}
