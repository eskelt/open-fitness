import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../locale_controller.dart';
import '../units_controller.dart';
import '../update/update_checker.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListenableBuilder(
        listenable: Listenable.merge([localeController, unitsController]),
        builder: (context, _) {
          final current = localeController.current;
          Widget tile(String code, String label) => RadioListTile<String>(
                value: code,
                groupValue: current,
                title: Text(label),
                onChanged: (v) => localeController.set(v!),
              );
          Widget unitTile(bool imperial, String label) =>
              RadioListTile<bool>(
                value: imperial,
                groupValue: unitsController.imperial,
                title: Text(label),
                onChanged: (v) => unitsController.set(v!),
              );
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(t.language,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              tile('system', t.languageSystem),
              tile('es', t.languageSpanish),
              tile('en', t.languageEnglish),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(t.units,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              unitTile(false, t.unitsMetric),
              unitTile(true, t.unitsImperial),
              const Divider(),
              const _UpdatesSection(),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(t.about,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(t.aboutText,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Settings "Updates" block: shows the installed version and a manual
/// "Check for updates" action (the automatic check lives in the Home banner).
class _UpdatesSection extends StatefulWidget {
  const _UpdatesSection();
  @override
  State<_UpdatesSection> createState() => _UpdatesSectionState();
}

class _UpdatesSectionState extends State<_UpdatesSection> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final info = await UpdateChecker.check(force: true);
    if (!mounted) return;
    setState(() => _checking = false);
    final t = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (info == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.upToDate)));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(t.updateAvailable(info.version)),
        action: SnackBarAction(
          label: t.updateView,
          onPressed: () => launchUrl(Uri.parse(info.url),
              mode: LaunchMode.externalApplication),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child:
              Text(t.updates, style: Theme.of(context).textTheme.titleMedium),
        ),
        FutureBuilder<String>(
          future: UpdateChecker.currentVersion(),
          builder: (context, snap) => ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(snap.hasData ? t.appVersion(snap.data!) : '…'),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.system_update),
          title: Text(_checking ? t.checking : t.checkUpdates),
          trailing: _checking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: _checking ? null : _check,
        ),
      ],
    );
  }
}
