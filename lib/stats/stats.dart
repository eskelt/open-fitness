import '../xiaomi/models.dart';
import '../sports/sport.dart';

/// Aggregated totals over a set of sessions.
class Totals {
  final int count;
  final int distanceM;
  final int durationSec;
  final int calories;
  final int avgPace; // s/km weighted by distance (0 if not applicable)
  final int avgHr; // weighted by duration

  const Totals({
    required this.count,
    required this.distanceM,
    required this.durationSec,
    required this.calories,
    required this.avgPace,
    required this.avgHr,
  });

  double get distanceKm => distanceM / 1000.0;

  factory Totals.from(List<SportRecord> rs) {
    var dist = 0, dur = 0, cal = 0, hrWeighted = 0, hrDur = 0;
    for (final r in rs) {
      dist += r.distanceM;
      dur += r.durationSec;
      cal += r.calories;
      if (r.avgHr > 0 && r.durationSec > 0) {
        hrWeighted += r.avgHr * r.durationSec;
        hrDur += r.durationSec;
      }
    }
    final pace = dist > 0 ? (dur * 1000 / dist).round() : 0;
    return Totals(
      count: rs.length,
      distanceM: dist,
      durationSec: dur,
      calories: cal,
      avgPace: pace,
      avgHr: hrDur > 0 ? (hrWeighted / hrDur).round() : 0,
    );
  }
}

/// A weekly bucket (Monday as start) with distance/duration/session count.
class WeekBucket {
  final DateTime weekStart; // local Monday
  int distanceM = 0;
  int durationSec = 0;
  int count = 0;
  WeekBucket(this.weekStart);
  double get km => distanceM / 1000.0;
}

/// A personal record: value + the session that holds it.
class Record {
  final double value;
  final SportRecord record;
  const Record(this.value, this.record);
}

class PersonalRecords {
  final Record? longestDistance; // m
  final Record? longestDuration; // s
  final Record? fastestPace; // s/km (lowest)
  final Record? bestVo2max;
  final Record? mostCalories;
  final Record? bestTrainEffect;

  const PersonalRecords({
    this.longestDistance,
    this.longestDuration,
    this.fastestPace,
    this.bestVo2max,
    this.mostCalories,
    this.bestTrainEffect,
  });

  factory PersonalRecords.from(List<SportRecord> rs) {
    Record? maxBy(double Function(SportRecord) f, {bool valid = true}) {
      Record? best;
      for (final r in rs) {
        final v = f(r);
        if (v <= 0) continue;
        if (best == null || v > best.value) best = Record(v, r);
      }
      return best;
    }

    Record? minBy(double Function(SportRecord) f) {
      Record? best;
      for (final r in rs) {
        final v = f(r);
        if (v <= 0) continue;
        if (best == null || v < best.value) best = Record(v, r);
      }
      return best;
    }

    return PersonalRecords(
      longestDistance: maxBy((r) => r.distanceM.toDouble()),
      longestDuration: maxBy((r) => r.durationSec.toDouble()),
      fastestPace: minBy((r) => r.avgPace.toDouble()),
      bestVo2max: maxBy((r) => r.vo2max.toDouble()),
      mostCalories: maxBy((r) => r.calories.toDouble()),
      bestTrainEffect: maxBy((r) => r.trainEffect),
    );
  }
}

/// Aggregated HR zones (seconds in each zone) over a set of sessions.
class HrZoneTotals {
  final int warmUp, fatBurn, aerobic, anaerobic, extreme;
  const HrZoneTotals(
      this.warmUp, this.fatBurn, this.aerobic, this.anaerobic, this.extreme);

  int get total => warmUp + fatBurn + aerobic + anaerobic + extreme;
  List<int> get asList => [warmUp, fatBurn, aerobic, anaerobic, extreme];

  factory HrZoneTotals.from(List<SportRecord> rs) {
    var w = 0, f = 0, a = 0, an = 0, e = 0;
    for (final r in rs) {
      w += r.hrWarmUp;
      f += r.hrFatBurn;
      a += r.hrAerobic;
      an += r.hrAnaerobic;
      e += r.hrExtreme;
    }
    return HrZoneTotals(w, f, a, an, e);
  }
}

/// Time-based aggregation helpers.
class StatsTime {
  /// Monday 00:00 (session local time) of the week containing [d].
  /// Uses calendar arithmetic (not Duration) so it stays at local midnight
  /// across DST transitions; otherwise bucket keys drift by an hour and
  /// records stop matching their week.
  static DateTime weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return DateTime(day.year, day.month, day.day - (day.weekday - 1));
  }

  /// Last [weeks] weeks (including the current one), in chronological order.
  static List<WeekBucket> weekly(List<SportRecord> rs, {int weeks = 12}) {
    final now = DateTime.now();
    final thisWeek = weekStart(now);
    final buckets = <DateTime, WeekBucket>{};
    for (var i = weeks - 1; i >= 0; i--) {
      // calendar arithmetic (DST-safe): same clean local midnight that
      // weekStart() produces for each record.
      final ws =
          DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * i);
      buckets[ws] = WeekBucket(ws);
    }
    for (final r in rs) {
      final ws = weekStart(r.localStart);
      final b = buckets[ws];
      if (b != null) {
        b.distanceM += r.distanceM;
        b.durationSec += r.durationSec;
        b.count++;
      }
    }
    return buckets.values.toList()
      ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
  }

  /// Distance (m) accumulated since the start of the current week.
  static int distanceThisWeek(List<SportRecord> rs) {
    final ws = weekStart(DateTime.now());
    var d = 0;
    for (final r in rs) {
      if (!r.localStart.isBefore(ws)) d += r.distanceM;
    }
    return d;
  }

  /// Distance (m) accumulated in the current month.
  static int distanceThisMonth(List<SportRecord> rs) {
    final now = DateTime.now();
    var d = 0;
    for (final r in rs) {
      final s = r.localStart;
      if (s.year == now.year && s.month == now.month) d += r.distanceM;
    }
    return d;
  }

  /// Days (local date, no time) with at least one session.
  static Set<DateTime> activeDays(List<SportRecord> rs) => rs
      .map((r) => DateTime(r.localStart.year, r.localStart.month, r.localStart.day))
      .toSet();

  /// Total distance (m) per local day, for the activity calendar: the key set
  /// are the active days, the value drives the cell's intensity.
  static Map<DateTime, int> distanceByDay(List<SportRecord> rs) {
    final map = <DateTime, int>{};
    for (final r in rs) {
      final s = r.localStart;
      final day = DateTime(s.year, s.month, s.day);
      map[day] = (map[day] ?? 0) + r.distanceM;
    }
    return map;
  }
}

/// A selectable time window for the overview stats.
enum StatsRange { week, month, year, all }

extension StatsRangeX on StatsRange {
  /// Inclusive start of this range relative to [now]. `all` -> null (no bound).
  DateTime? start(DateTime now) {
    switch (this) {
      case StatsRange.week:
        return StatsTime.weekStart(now);
      case StatsRange.month:
        return DateTime(now.year, now.month, 1);
      case StatsRange.year:
        return DateTime(now.year, 1, 1);
      case StatsRange.all:
        return null;
    }
  }

  /// The previous equivalent window [start, end) used for deltas. `all` -> null.
  (DateTime, DateTime)? previous(DateTime now) {
    switch (this) {
      case StatsRange.week:
        final s = StatsTime.weekStart(now);
        return (DateTime(s.year, s.month, s.day - 7), s);
      case StatsRange.month:
        return (DateTime(now.year, now.month - 1, 1),
            DateTime(now.year, now.month, 1));
      case StatsRange.year:
        return (DateTime(now.year - 1, 1, 1), DateTime(now.year, 1, 1));
      case StatsRange.all:
        return null;
    }
  }
}

/// Records within [range] relative to [now] (defaults to now).
List<SportRecord> recordsInRange(List<SportRecord> rs, StatsRange range,
    [DateTime? now]) {
  final start = range.start(now ?? DateTime.now());
  if (start == null) return rs;
  return rs.where((r) => !r.localStart.isBefore(start)).toList();
}

/// Records within the previous equivalent window (for deltas); empty for `all`.
List<SportRecord> recordsInPreviousRange(List<SportRecord> rs, StatsRange range,
    [DateTime? now]) {
  final p = range.previous(now ?? DateTime.now());
  if (p == null) return const [];
  final (ps, pe) = p;
  return rs
      .where((r) => !r.localStart.isBefore(ps) && r.localStart.isBefore(pe))
      .toList();
}

/// A calendar month with its sessions (sorted newest first) for the History
/// screen. [month] is the first day of the month in local time.
class MonthGroup {
  final DateTime month;
  final List<SportRecord> records;
  const MonthGroup(this.month, this.records);
  Totals get totals => Totals.from(records);
}

/// Groups sessions by calendar month, newest month first, each month's sessions
/// newest first.
List<MonthGroup> groupByMonth(List<SportRecord> rs) {
  final map = <DateTime, List<SportRecord>>{};
  for (final r in rs) {
    final s = r.localStart;
    (map[DateTime(s.year, s.month)] ??= []).add(r);
  }
  return map.entries
      .map((e) => MonthGroup(
          e.key, e.value..sort((a, b) => b.time.compareTo(a.time))))
      .toList()
    ..sort((a, b) => b.month.compareTo(a.month));
}

/// Groups sessions by sport category (for the sport selector).
Map<Sport, List<SportRecord>> groupBySport(List<SportRecord> rs) {
  final map = <String, List<SportRecord>>{};
  for (final r in rs) {
    (map[r.category] ??= []).add(r);
  }
  final out = <Sport, List<SportRecord>>{};
  for (final e in map.entries) {
    out[Sports.of(e.key)] = e.value
      ..sort((a, b) => b.time.compareTo(a.time));
  }
  return out;
}
