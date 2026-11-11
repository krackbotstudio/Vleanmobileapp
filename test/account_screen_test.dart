import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vclean_laundry/account_data.dart';
import 'package:vclean_laundry/addresses_screen.dart';
import 'package:vclean_laundry/appearance.dart';
import 'package:vclean_laundry/auth.dart';
import 'package:vclean_laundry/customer_api.dart';
import 'package:vclean_laundry/domain.dart';
import 'package:vclean_laundry/orders_screen.dart';
import 'package:vclean_laundry/profile_screen.dart';

const session = CustomerSession(
  'test-token',
  CustomerProfile(id: 'customer', phone: '9876543210', name: 'Original Name'),
);
Future<void> mount(WidgetTester tester, Widget screen) async {
  await tester.binding.setSurfaceSize(const Size(320, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: customerTheme(true),
      home: Scaffold(body: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'profile validates edits, saves to the server, refreshes the name and exposes account actions',
    (tester) async {
      var storedName = 'Original Name';
      var patches = 0;
      CustomerProfile? changed;
      final api = AccountApi(
        CustomerApi(
          MockClient((request) async {
            if (request.method == 'PATCH') {
              patches++;
              storedName = jsonDecode(request.body)['name'];
              return http.Response('', 204);
            }
            return http.Response(
              jsonEncode({
                'user': {
                  'id': 'customer',
                  'phone': '9876543210',
                  'role': 'CUSTOMER',
                  'name': storedName,
                  'email': 'name@example.test',
                },
              }),
              200,
            );
          }),
        ),
      );
      await mount(
        tester,
        ProfileScreen(
          session: session,
          brand: null,
          api: api,
          signIn: () {},
          signOut: () async {},
          openOrders: () {},
          onProfileChanged: (profile) => changed = profile,
        ),
      );
      await tester.enterText(
        find.byKey(const Key('profile-email')),
        'not-an-email',
      );
      await tap(tester, find.byKey(const Key('profile-save')));
      expect(patches, 0);
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'Updated Name',
      );
      await tester.enterText(
        find.byKey(const Key('profile-email')),
        'name@example.test',
      );
      await tap(tester, find.byKey(const Key('profile-save')));
      expect(patches, 1);
      expect(changed?.name, 'Updated Name');
      expect(find.text('My Addresses'), findsOneWidget);
      expect(find.text('My Orders'), findsOneWidget);
      await tap(tester, find.text('Delete account'));
      expect(
        find.textContaining('please contact Vclean support'),
        findsOneWidget,
      );
      await tap(tester, find.text('OK'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'order details show tracking, final invoice, advance and correct remaining amount at phone width',
    (tester) async {
      final previews = PreviewBookings();
      addTearDown(previews.dispose);
      final api = AccountApi(
        CustomerApi(
          MockClient((request) async {
            if (request.url.path.endsWith('/orders')) {
              return http.Response.bytes(
                utf8.encode(
                  jsonEncode([
                    {
                      'id': 'old',
                      'status': 'DELIVERED',
                      'pickupDate': '2026-11-01',
                      'timeWindow': '9 AM – 12 PM',
                      'serviceType': 'WASH_FOLD',
                    },
                    {
                      'id': 'out',
                      'status': 'OUT_FOR_DELIVERY',
                      'pickupDate': '2026-11-06',
                      'timeWindow': '12 PM – 3 PM',
                      'serviceType': 'DRY_CLEAN',
                    },
                  ]),
                ),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'id': 'out',
                  'status': 'OUT_FOR_DELIVERY',
                  'pickupDate': '2026-11-06',
                  'timeWindow': '12 PM – 3 PM',
                  'serviceType': 'DRY_CLEAN',
                  'addressLine': 'Example pickup address',
                  'pincode': '500001',
                  'invoices': [
                    {
                      'id': 'ack',
                      'type': 'ACKNOWLEDGEMENT',
                      'total': 120050,
                      'advancePaymentAmount': 20000,
                    },
                    {
                      'id': 'final',
                      'type': 'FINAL',
                      'total': 120050,
                      'subtotal': 120050,
                      'items': [
                        {
                          'id': 'shirt',
                          'name': 'Shirt',
                          'quantity': 2,
                          'unitPrice': 60025,
                          'amount': 120050,
                        },
                      ],
                    },
                  ],
                }),
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      await mount(
        tester,
        OrdersScreen(
          session: session,
          api: api,
          signIn: () {},
          previews: previews,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('order-out'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('order-old'))).dy),
      );
      await tap(tester, find.byKey(const Key('order-out')));
      expect(find.text('Order Details'), findsOneWidget);
      expect(find.text('Out for delivery'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Final Invoice'),
        280,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Acknowledgement Invoice'), findsNothing);
      expect(find.text('₹1000.50'), findsWidgets);
      expect(find.text('Advance paid'), findsOneWidget);
      expect(find.text('₹200'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'saved addresses hide walk-ins and protect addresses with ongoing orders',
    (tester) async {
      final api = AccountApi(
        CustomerApi(
          MockClient(
            (request) async => http.Response(
              jsonEncode(
                request.url.path.endsWith('/addresses')
                    ? [
                        {
                          'id': 'locked',
                          'userId': 'customer',
                          'label': 'Home',
                          'addressLine': 'A sample home address',
                          'pincode': '500001',
                        },
                        {
                          'id': 'free',
                          'userId': 'customer',
                          'label': 'Office',
                          'addressLine': 'A sample office address',
                          'pincode': '500002',
                        },
                        {
                          'id': 'walkin',
                          'userId': 'customer',
                          'label': 'Walk-in counter',
                          'source': 'WALK_IN',
                        },
                      ]
                    : [
                        {
                          'id': 'order',
                          'status': 'OUT_FOR_DELIVERY',
                          'addressId': 'locked',
                        },
                      ],
              ),
              200,
            ),
          ),
        ),
      );
      await mount(tester, AddressesScreen(api: api, session: session));
      expect(find.text('Active order'), findsOneWidget);
      expect(find.byKey(const Key('edit-address-locked')), findsNothing);
      expect(find.byKey(const Key('delete-address-locked')), findsNothing);
      expect(find.byKey(const Key('edit-address-free')), findsOneWidget);
      expect(find.text('Walk-in counter'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
