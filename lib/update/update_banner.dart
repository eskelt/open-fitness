import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_checker.dart';

/// A dismissible banner shown on Home when a newer release is available on
/// GitHub. Renders nothing (zero height) while checking, when up to date, or
/// once dismissed for that version. "View" opens the release page in the
/// browser (where the APK can be downloaded).
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});
  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  UpdateInfo? _info;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await UpdateChecker.check();
    if (info == null || !mounted) return;
    if (await UpdateChecker.isDismissed(info.version)) return;
    if (mounted) setState(() => _info = info);
  }

  Future<void> _open() async {
    final info = _info;
    if (info == null) return;
    await launchUrl(Uri.parse(info.url), mode: LaunchMode.externalApplication);
  }

  Future<void> _dismiss() async {
    final info = _info;
    if (info != null) await UpdateChecker.dismiss(info.version);
    if (mounted) setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null || _hidden) return const SizedBox.shrink();
    final t = L.of(context);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            Icon(Icons.system_update, size: 20, color: cs.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.updateAvailable(info.version),
                style: TextStyle(
                    color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: _open, child: Text(t.updateView)),
            IconButton(
              tooltip: t.updateDismiss,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, size: 20, color: cs.onPrimaryContainer),
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
