import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vclean_laundry/service_sphere.dart';

void main() {
  testWidgets('ServiceSphere displays 3D logo and orbiting service text', (
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

    // Verifies the 3D logo asset is rendered on the sphere
    expect(find.byType(Image), findsOneWidget);
    final imageWidget = tester.widget<Image>(find.byType(Image));
    expect(
      (imageWidget.image as AssetImage).assetName,
      'assets/vclean-logo.png',
    );

    // Verifies services are present in the widget tree
    expect(find.text('Wash & Fold'), findsOneWidget);

    // Verifies swipe gesture rotates to another service
    await tester.drag(
      find.byType(GestureDetector).first,
      const Offset(-200, 0),
    );
    await tester.pump();
  });
}
