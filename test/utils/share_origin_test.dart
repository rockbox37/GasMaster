import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gasmaster/utils/share_origin.dart';

void main() {
  testWidgets('uses render box when it fits on screen', (tester) async {
    late Rect origin;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 40,
              height: 20,
              child: Builder(
                builder: (context) {
                  return GestureDetector(
                    onTap: () => origin = sharePositionOriginFor(context),
                    child: const ColoredBox(color: Colors.red),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(GestureDetector));
    expect(origin.width, 40);
    expect(origin.height, 20);
    expect(origin.left, greaterThanOrEqualTo(0));
    expect(origin.top, greaterThanOrEqualTo(0));
  });

  testWidgets('falls back to center 1x1 when box is off-screen', (tester) async {
    late Rect origin;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Transform.translate(
            offset: const Offset(-500, -500),
            child: SizedBox(
              width: 40,
              height: 20,
              child: Builder(
                builder: (context) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => origin = sharePositionOriginFor(context),
                    child: const ColoredBox(color: Colors.red),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    // Off-screen widgets are not hittable; invoke via the element context.
    final builder = tester.element(find.byType(Builder).last);
    origin = sharePositionOriginFor(builder);

    expect(origin.width, 1);
    expect(origin.height, 1);
    final size = tester.getSize(find.byType(MaterialApp));
    expect(origin.center.dx, closeTo(size.width / 2, 0.5));
    expect(origin.center.dy, closeTo(size.height / 2, 0.5));
  });
}
