import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vclean_laundry/service_sphere.dart';

void main() {
  testWidgets('ServiceSphere shows a banner carousel and service ribbon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 390, height: 280, child: ServiceSphere()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('home-carousel')), findsOneWidget);
    expect(find.text('Doorstep pickup & delivery'), findsOneWidget);
    expect(find.text('Wash & Fold'), findsOneWidget);

    final carousel = tester.getRect(find.byKey(const Key('home-carousel')));
    final second = find.text('Dry cleaning, done right');
    expect(tester.getTopLeft(second).dx, greaterThan(carousel.right - 60));
    await tester.pump(const Duration(seconds: 7));
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.getTopLeft(second).dx, lessThan(carousel.center.dx));

    await tester.drag(find.byType(GestureDetector).last, const Offset(-200, 0));
    await tester.pump();
  });
}
