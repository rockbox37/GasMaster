import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasmaster/screens/fuel_saving_tips_screen.dart';

void main() {
  testWidgets('shows fuel-saving tips list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FuelSavingTipsScreen()),
    );
    await tester.pump();

    expect(find.text('Fuel-Saving Tips'), findsOneWidget);
    expect(find.text('Keep tires at the right pressure'), findsOneWidget);
    expect(fuelSavingTips.length, greaterThanOrEqualTo(8));

    await tester.scrollUntilVisible(
      find.text('Idle less'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Idle less'), findsOneWidget);
  });
}
