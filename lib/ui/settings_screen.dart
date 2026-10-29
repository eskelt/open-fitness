import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../locale_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ValueListenableBuilder<Locale?>(
        valueListenable: localeController,
        builder: (context, _, __) {
          final current = localeController.current;
          Widget tile(String code, String label) => RadioListTile<String>(
                value: code,
                groupValue: current,
                title: Text(label),
                onChanged: (v) => localeController.set(v!),
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
