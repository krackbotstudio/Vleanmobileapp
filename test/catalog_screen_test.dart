import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vclean_laundry/brand_api.dart';
import 'package:vclean_laundry/catalog.dart';
import 'package:vclean_laundry/customer_api.dart';
import 'package:vclean_laundry/prices_screen.dart';

const branches = [Branch('one', 'One'), Branch('two', 'Two')];
List<CatalogItem> rows(String name, int amount) => [
  CatalogItem(
    id: 'item',
    name: name,
    prices: [CatalogPrice('MEN', 'DRY CLEAN', amount)],
  ),
];
void main() {
  testWidgets(
    'late branch responses never replace the selected branch catalogue',
    (tester) async {
      final first = Completer<List<CatalogItem>>(),
          second = Completer<List<CatalogItem>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PricesScreen(
              branches: branches,
              loadCatalogue: (id) => id == 'one' ? first.future : second.future,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('branch-two')));
      await tester.pump();
      second.complete(rows('Two shirt', 4550));
      await tester.pumpAndSettle();
      expect(find.text('Two shirt'), findsOneWidget);
      expect(find.text('From ₹45.50'), findsOneWidget);
      first.complete(rows('Old one shirt', 99900));
      await tester.pumpAndSettle();
      expect(find.text('Old one shirt'), findsNothing);
      expect(find.text('Two shirt'), findsOneWidget);
    },
  );
  testWidgets(
    'branch failure hides old prices and retry loads actual catalogue',
    (tester) async {
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PricesScreen(
              branches: branches,
              loadCatalogue: (id) async {
                if (id == 'two' && fail) {
                  throw const ApiException('Branch prices unavailable.');
                }
                return rows(id == 'one' ? 'First shirt' : 'Second shirt', 2500);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('branch-two')));
      await tester.pumpAndSettle();
      expect(find.text('First shirt'), findsNothing);
      expect(find.text('Branch prices unavailable.'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry prices'));
      await tester.pumpAndSettle();
      expect(find.text('Second shirt'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('price-search')),
        'dry clean',
      );
      await tester.pumpAndSettle();
      expect(find.text('Second shirt'), findsOneWidget);
    },
  );
  testWidgets('empty branch shows an empty state, never example cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PricesScreen(
            branches: branches,
            loadCatalogue: (_) async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No catalogue prices are available for this branch yet.'),
      findsOneWidget,
    );
    expect(find.byType(PriceFlipCard), findsNothing);
  });
}
