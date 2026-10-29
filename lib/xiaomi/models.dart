import 'dart:convert';

/// A workout session parsed from get_sport_records_by_time.
/// Most of the data lives in the `value` field (nested JSON encoded as a string).
class SportRecord {
  final String sid; // watch id
  final String key; // outdoor_running, indoor_running, open_swimming, ...
  final int time; // epoch s (start)
  final String category; // running, swimming, tennis, ...
  final int zoneOffsetSec; // e.g. 7200
  final String zoneName; // Europe/Madrid
  final int watermark;
  final Map<String, dynamic> v; // the parsed value

  SportRecord({
    required this.sid,
    required this.key,
    required this.time,
    required this.category,
    required this.zoneOffsetSec,
    required this.zoneName,
    required this.watermark,
    required this.v,
  });

  factory SportRecord.fromItem(Map<String, dynamic> item) {
    final valueStr = item['value'];
    final v = (valueStr is String && valueStr.isNotEmpty)
        ? json.decode(valueStr) as Map<String, dynamic>
        : <String, dynamic>{};
    return SportRecord(
      sid: (item['sid'] ?? '').toString(),
      key: (item['key'] ?? '').toString(),
      time: (item['time'] ?? 0) as int,
      category: (item['category'] ?? '').toString(),
      zoneOffsetSec: (item['zone_offset'] ?? 0) as int,
      zoneName: (item['zone_name'] ?? '').toString(),
      watermark: (item['watermark'] ?? 0) as int,
      v: v,
    );
  }

  /// Stable id for dedup/caching: sid|key|time.
  String get id => '$sid|$key|$time';

  // --- typed getters over v (with safe defaults) ---
  double _d(String k) => (v[k] is num) ? (v[k] as num).toDouble() : 0.0;
  int _i(String k) => (v[k] is num) ? (v[k] as num).toInt() : 0;

  bool get isRunning => category == 'running';
  bool get isOutdoor => key.startsWith('outdoor');

  int get distanceM => _i('distance');
  double get distanceKm => distanceM / 1000.0;
  int get durationSec => _i('duration');
  int get calories => _i('calories');
  int get totalCal => _i('total_cal');
  int get steps => _i('steps');

  int get avgPace => _i('avg_pace'); // s/km
  int get maxPace => _i('max_pace');
  double get avgSpeed => _d('avg_speed');
  double get maxSpeed => _d('max_speed');

  int get avgHr => _i('avg_hrm');
  int get maxHr => _i('max_hrm');
  int get minHr => _i('min_hrm');
  int get avgCadence => _i('avg_cadence');
  int get avgStride => _i('avg_stride');

  // time spent in each HR zone (seconds)
  int get hrWarmUp => _i('hrm_warm_up_duration');
  int get hrFatBurn => _i('hrm_fat_burning_duration');
  int get hrAerobic => _i('hrm_aerobic_duration');
  int get hrAnaerobic => _i('hrm_anaerobic_duration');
  int get hrExtreme => _i('hrm_extreme_duration');
  List<int> get hrZones =>
      [hrWarmUp, hrFatBurn, hrAerobic, hrAnaerobic, hrExtreme];

  double get trainEffect => _d('train_effect');
  double get anaerobicTrainEffect => _d('anaerobic_train_effect');
  int get vo2max => _i('vo2_max');
  double get runningAbilityIndex => _d('running_ability_index');
  int get recoverTimeH => _i('recover_time');
  int get trainLoad => _i('train_load');

  // race-time predictions (seconds)
  int get pred5k => _i('five_kilometre_grade_prediction_duration');
  int get pred10k => _i('ten_kilometre_grade_prediction_duration');
  int get predHalf => _i('half_marathon_grade_prediction_duration');
  int get predFull => _i('full_marathon_grade_prediction_duration');

  int get startTime => _i('start_time') != 0 ? _i('start_time') : time;
  int get endTime => _i('end_time');

  DateTime get localStart => DateTime.fromMillisecondsSinceEpoch(
      (startTime + zoneOffsetSec) * 1000,
      isUtc: true);

  static List<SportRecord> parseList(Map<String, dynamic> resp) {
    final result = resp['result'];
    if (result is! Map) return [];
    final list = result['sport_records'];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(SportRecord.fromItem)
        .toList();
  }
}
