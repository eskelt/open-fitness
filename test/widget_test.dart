// Basic smoke test: the app builds and shows the sign-in screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:open_fitness/main.dart';

void main() {
  testWidgets('App builds and shows the sign-in screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OpenFitnessApp());
    await tester.pumpAndSettle();

    // The login screen shows the app name.
    expect(find.text('Open Fitness'), findsWidgets);
  });
}
