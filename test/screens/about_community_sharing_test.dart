import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gasmaster/screens/about_screen.dart';
import 'package:gasmaster/services/preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'community_sharing_enabled': false,
    });
    await Preferences.init();
  });

  testWidgets('offers an explicit, default-off community sharing opt-in',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AboutScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Share anonymous fuel economy'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(toggle.value, isFalse);
    expect(
      find.textContaining('No raw fill-ups, IDs, dates, costs, or photos'),
      findsOneWidget,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(Preferences.communitySharingEnabled, isTrue);
  });
}
