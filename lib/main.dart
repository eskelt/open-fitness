import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data/repository.dart';
import 'locale_controller.dart';
import 'ui/root_shell.dart';
import 'ui/settings_screen.dart';
import 'ui/theme/theme.dart';
import 'ui/verify_webview.dart';
import 'xiaomi/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await localeController.load();
  runApp(const OpenFitnessApp());
}

class OpenFitnessApp extends StatelessWidget {
  const OpenFitnessApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeController,
      builder: (context, locale, _) {
        return MaterialApp(
          title: 'Open Fitness',
          debugShowCheckedModeBanner: false,
          theme: buildOpenFitnessTheme(),
          locale: locale,
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: const Gate(),
        );
      },
    );
  }
}

/// Decides whether to show login or home based on a stored session.
class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool _loading = true;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _logged = await repo.restoreSession();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _logged
        ? RootShell(onLogout: () => setState(() => _logged = false))
        : LoginScreen(onLogin: () => setState(() => _logged = true));
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String _region = 'de';
  bool _busy = false;
  String? _error;

  Future<void> _doLogin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    var extraCookies = <String, String>{};
    try {
      // Attempt 0: normal login. If it asks for verification, we do it in the
      // WebView (with the deviceId cookie) and retry (attempt 1) with the
      // passportsecurity_* cookies the verification leaves behind.
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await repo.login(_user.text.trim(), _pass.text,
              region: _region, extraCookies: extraCookies);
          widget.onLogin();
          return;
        } on XiaomiVerificationRequired catch (e) {
          if (attempt == 1) rethrow; // already retried with cookies: real failure
          final deviceId = await repo.deviceId();
          if (!mounted) return;
          final cookies = await Navigator.push<Map<String, String>>(
            context,
            MaterialPageRoute(
              builder: (_) => VerifyWebView(
                  notificationUrl: e.notificationUrl, deviceId: deviceId),
            ),
          );
          if (cookies == null || cookies.isEmpty) return; // cancelled
          extraCookies = cookies;
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: t.settings,
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.directions_run, size: 64),
                const SizedBox(height: 8),
                Text('Open Fitness',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(t.appTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 32),
                TextField(
                  controller: _user,
                  decoration: InputDecoration(
                      labelText: t.userHint,
                      border: const OutlineInputBorder()),
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: t.password,
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _region,
                  decoration: InputDecoration(
                      labelText: t.region,
                      border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'de', child: Text(t.regionEurope)),
                    DropdownMenuItem(value: 'sg', child: Text(t.regionAsia)),
                    DropdownMenuItem(value: 'in', child: Text(t.regionIndia)),
                    DropdownMenuItem(value: 'ru', child: Text(t.regionRussia)),
                    DropdownMenuItem(value: 'i2', child: Text(t.regionAmerica)),
                    DropdownMenuItem(value: 'cn', child: Text(t.regionChina)),
                  ],
                  onChanged: (v) => setState(() => _region = v ?? 'de'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _doLogin,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(t.signIn),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: SelectableText(_error!,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 16),
                Text(t.passwordDisclaimer,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
