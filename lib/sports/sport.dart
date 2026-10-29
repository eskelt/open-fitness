import 'package:flutter/material.dart';

/// Primary metric a sport is measured by (for the summary/records).
enum PrimaryMetric { distance, duration }

/// Definition of a sport: how it is shown and which metrics make sense to
/// display. Designed to grow (cycling, swimming, strength...) without touching
/// the UI.
class Sport {
  final String category; // value of the cloud `category` field
  final IconData icon;
  final String labelKey; // i18n key (see L); if missing, [category] is used
  final PrimaryMetric primary;
  final bool hasDistance;
  final bool hasPace; // pace min/km
  final bool hasCadence;
  final bool hasStride;
  final bool hasSwolf; // swimming
  final bool hasSteps;

  const Sport({
    required this.category,
    required this.icon,
    required this.labelKey,
    this.primary = PrimaryMetric.distance,
    this.hasDistance = true,
    this.hasPace = true,
    this.hasCadence = true,
    this.hasStride = true,
    this.hasSwolf = false,
    this.hasSteps = true,
  });
}

/// Central registry of supported sports. Adding a new one is a single line.
class Sports {
  static const running = Sport(
    category: 'running',
    icon: Icons.directions_run,
    labelKey: 'sportRunning',
  );
  static const walking = Sport(
    category: 'walking',
    icon: Icons.directions_walk,
    labelKey: 'sportWalking',
  );
  static const hiking = Sport(
    category: 'outdoor_hiking',
    icon: Icons.terrain,
    labelKey: 'sportHiking',
  );
  static const cycling = Sport(
    category: 'cycling',
    icon: Icons.directions_bike,
    labelKey: 'sportCycling',
    hasCadence: true,
    hasStride: false,
    hasSteps: false,
  );
  static const swimming = Sport(
    category: 'swimming',
    icon: Icons.pool,
    labelKey: 'sportSwimming',
    hasPace: true,
    hasCadence: false,
    hasStride: false,
    hasSwolf: true,
    hasSteps: false,
  );
  static const tennis = Sport(
    category: 'tennis',
    icon: Icons.sports_tennis,
    labelKey: 'sportTennis',
    primary: PrimaryMetric.duration,
    hasDistance: false,
    hasPace: false,
    hasCadence: false,
    hasStride: false,
    hasSteps: false,
  );
  static const strength = Sport(
    category: 'strength_training',
    icon: Icons.fitness_center,
    labelKey: 'sportStrength',
    primary: PrimaryMetric.duration,
    hasDistance: false,
    hasPace: false,
    hasCadence: false,
    hasStride: false,
    hasSteps: false,
  );
  static const freeTraining = Sport(
    category: 'free_training',
    icon: Icons.self_improvement,
    labelKey: 'sportFreeTraining',
    primary: PrimaryMetric.duration,
    hasDistance: false,
    hasPace: false,
    hasCadence: false,
    hasStride: false,
    hasSteps: false,
  );
  static const rockClimbing = Sport(
    category: 'rock_climbing',
    icon: Icons.landscape,
    labelKey: 'sportRockClimbing',
    primary: PrimaryMetric.duration,
    hasDistance: false,
    hasPace: false,
    hasCadence: false,
    hasStride: false,
    hasSteps: false,
  );
  static const canoeing = Sport(
    category: 'canoeing',
    icon: Icons.kayaking,
    labelKey: 'sportCanoeing',
    hasCadence: false,
    hasStride: false,
    hasSteps: false,
  );

  static const all = <Sport>[
    running,
    cycling,
    swimming,
    walking,
    hiking,
    tennis,
    strength,
    freeTraining,
    rockClimbing,
    canoeing,
  ];

  static final _byCategory = {for (final s in all) s.category: s};

  /// Sport by category; if not registered, a reasonable generic one.
  static Sport of(String category) =>
      _byCategory[category] ??
      Sport(
        category: category,
        icon: Icons.fitness_center,
        labelKey: category,
        primary: PrimaryMetric.duration,
        hasDistance: false,
        hasPace: false,
        hasCadence: false,
        hasStride: false,
        hasSteps: false,
      );
}
