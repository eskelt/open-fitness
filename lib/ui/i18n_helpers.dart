import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../sports/sport.dart';

/// Translated sport name (maps Sport.category to the i18n string).
String sportLabel(L t, Sport s) {
  switch (s.category) {
    case 'running':
      return t.sportRunning;
    case 'cycling':
      return t.sportCycling;
    case 'swimming':
      return t.sportSwimming;
    case 'walking':
      return t.sportWalking;
    case 'outdoor_hiking':
      return t.sportHiking;
    case 'tennis':
      return t.sportTennis;
    case 'strength_training':
      return t.sportStrength;
    case 'free_training':
      return t.sportFreeTraining;
    case 'rock_climbing':
      return t.sportRockClimbing;
    case 'canoeing':
      return t.sportCanoeing;
    default:
      return s.category;
  }
}

/// The 5 HR zone names in order (warm-up..extreme).
List<String> hrZoneNames(L t) =>
    [t.zoneWarmUp, t.zoneFatBurn, t.zoneAerobic, t.zoneAnaerobic, t.zoneExtreme];
