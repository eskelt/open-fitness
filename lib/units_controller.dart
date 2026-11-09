import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Measurement system for distance, pace and speed, applied app-wide.
/// false = metric (km, min/km, km/h); true = imperial (mi, min/mi, mph).
/// Persisted across launches.
class UnitsController extends ValueNotifier<bool> {
  static const _key = 'units_imperial';

  UnitsController() : super(false);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    value = p.getBool(_key) ?? false;
  }

  Future<void> set(bool imperial) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, imperial);
    value = imperial;
  }

  bool get imperial => value;
}

final unitsController = UnitsController();
