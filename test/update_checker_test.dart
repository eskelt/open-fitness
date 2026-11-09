// Version comparison used by the in-app update banner. Pure, no network.
import 'package:flutter_test/flutter_test.dart';
import 'package:open_fitness/update/update_checker.dart';

void main() {
  group('UpdateChecker.isNewer', () {
    test('a higher patch/minor/major is newer', () {
      expect(UpdateChecker.isNewer('0.4.1', '0.4.0'), isTrue);
      expect(UpdateChecker.isNewer('0.5.0', '0.4.9'), isTrue);
      expect(UpdateChecker.isNewer('1.0.0', '0.9.9'), isTrue);
    });

    test('equal or older is not newer', () {
      expect(UpdateChecker.isNewer('0.4.0', '0.4.0'), isFalse);
      expect(UpdateChecker.isNewer('0.4.0', '0.5.0'), isFalse);
      expect(UpdateChecker.isNewer('0.3.9', '0.4.0'), isFalse);
    });

    test('build metadata after "+" is ignored', () {
      // Same version, different build number -> not an update.
      expect(UpdateChecker.isNewer('0.4.0+5', '0.4.0+4'), isFalse);
      expect(UpdateChecker.isNewer('0.4.0', '0.4.0+99'), isFalse);
    });

    test('test-APK scenario: 0.4.0 release beats a 0.3.0+99 build', () {
      // The banner test APK ships as 0.3.0+99 so the real 0.4.0 release shows.
      expect(UpdateChecker.isNewer('0.4.0', '0.3.0+99'), isTrue);
    });

    test('a leading "v" and missing components are tolerated', () {
      expect(UpdateChecker.isNewer('v0.5.0', '0.4.0'), isTrue);
      expect(UpdateChecker.isNewer('1', '0.9'), isTrue); // 1.0.0 > 0.9.0
    });
  });
}
