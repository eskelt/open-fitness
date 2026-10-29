import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls the app language. null = follow the device language (falling back
/// to English if there is no translation). Persists the choice.
class LocaleController extends ValueNotifier<Locale?> {
  static const _key = 'app_locale'; // 'system' | 'en' | 'es'

  LocaleController() : super(null);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString(_key);
    value = (code == null || code == 'system') ? null : Locale(code);
  }

  Future<void> set(String code) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, code);
    value = code == 'system' ? null : Locale(code);
  }

  String get current {
    final v = value;
    return v == null ? 'system' : v.languageCode;
  }
}

final localeController = LocaleController();
