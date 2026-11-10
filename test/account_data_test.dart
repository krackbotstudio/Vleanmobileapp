import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vclean_laundry/account_data.dart';
import 'package:vclean_laundry/brand_api.dart';
import 'package:vclean_laundry/customer_api.dart';

void main() {
  test(
    'orders stay brand scoped, ongoing first, and out-for-delivery is not delivered',
    () async {
      final api = AccountApi(
        CustomerApi(
          MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer customer-token');
            expect(request.headers['X-Brand-Id'], AppConfig.brandId);
            return http.Response(
              jsonEncode([
                {'id': 'done', 'status': 'DELIVERED'},
                {'id': 'out', 'status': 'OUT_FOR_DELIVERY'},
                {'id': 'cancel', 'status': 'CANCELLED'},
              ]),
              200,
            );
          }),
        ),
      );
      final rows = await api.orders('customer-token');
      expect(rows.map((o) => o.id), ['out', 'done', 'cancel']);
      expect(rows.first.delivered, false);
      expect(rows.first.trackingStage, 2);
      expect(rows.last.trackingStage, isNull);
    },
  );
  test(
    'profile PATCH accepts 204, sends editable fields only, and never retries a failure',
    () async {
      var calls = 0;
      final api = AccountApi(
        CustomerApi(
          MockClient((request) async {
            calls++;
            expect(request.method, 'PATCH');
            expect(jsonDecode(request.body), {'name': 'New Name'});
            expect(request.headers['Authorization'], 'Bearer token');
            return calls == 1
                ? http.Response('', 204)
                : http.Response(
                    '{"error":{"message":"Email is invalid"}}',
                    400,
                  );
          }),
        ),
      );
      await api.updateProfile('token', ' New Name ', '');
      await expectLater(
        api.updateProfile('token', 'New Name', ''),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Email is invalid',
          ),
        ),
      );
      expect(calls, 2);
    },
  );
  test(
    'foreign tenant orders and another customer address list are rejected',
    () async {
      final api = AccountApi(
        CustomerApi(
          MockClient(
            (r) async => http.Response(
              jsonEncode([
                r.url.path.endsWith('/orders')
                    ? {'id': 'bad', 'status': 'DELIVERED', 'brandId': 'foreign'}
                    : {'id': 'address', 'userId': 'another-customer'},
              ]),
              200,
            ),
          ),
        ),
      );
      await expectLater(api.orders('token'), throwsA(isA<ApiException>()));
      await expectLater(
        api.addresses('token', 'our-customer'),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test(
    'an active order blocks address mutation, including unknown future statuses',
    () async {
      final methods = <String>[];
      final api = AccountApi(
        CustomerApi(
          MockClient((request) async {
            methods.add(request.method);
            return http.Response(
              '[{"id":"order","status":"NEW_FUTURE_STAGE","addressId":"address"}]',
              200,
            );
          }),
        ),
      );
      await expectLater(
        api.deleteAddress('token', 'address'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        api.saveAddress('token', {}, id: 'address'),
        throwsA(isA<ApiException>()),
      );
      expect(methods, ['GET', 'GET']);
    },
  );
  test(
    'serviceability cross-checks branch membership and cannot use a foreign branch',
    () async {
      final api = AccountApi(
        CustomerApi(
          MockClient(
            (r) async => http.Response(
              jsonEncode(
                r.url.path.contains('/branding/')
                    ? {
                        'brandId': AppConfig.brandId,
                        'branches': [
                          {
                            'id': 'ours',
                            'name': 'Our branch',
                            'brandId': AppConfig.brandId,
                          },
                        ],
                      }
                    : {
                        'branches': [
                          {'id': 'ours', 'name': 'Our branch'},
                          {'id': 'foreign', 'name': 'Wrong branch'},
                        ],
                      },
              ),
              200,
            ),
          ),
        ),
      );
      expect((await api.servingBranches('500001')).map((b) => b.id), ['ours']);
    },
  );
  test(
    'invoice balances use paise and do not apply the same advance twice',
    () {
      final ack = CustomerInvoice({
        'id': 'ack',
        'type': 'ACKNOWLEDGEMENT',
        'total': 150000,
        'advancePaymentAmount': 20000,
      });
      final finalInvoice = CustomerInvoice({
        'id': 'final',
        'type': 'FINAL',
        'total': 120050,
      });
      expect(invoiceAdvance(finalInvoice, [ack, finalInvoice]), 20000);
      final ownAdvance = CustomerInvoice({
        'id': 'final-own',
        'type': 'FINAL',
        'total': 120050,
        'advancePaymentAmount': 15000,
      });
      expect(invoiceAdvance(ownAdvance, [ack, ownAdvance]), 15000);
      expect(
        CustomerOrder({
          'id': 'paid',
          'status': 'OUT_FOR_DELIVERY',
          'paymentStatus': 'PAID',
        }).paid,
        true,
      );
      expect(
        () => CustomerInvoice({'id': 'bad', 'total': '1200'}),
        throwsFormatException,
      );
      expect(
        () => CustomerInvoice({
          'id': 'bad',
          'total': 100,
          'items': [
            {'unitPrice': -1},
          ],
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'feedback keeps order ID and customer auth and rejects invalid ratings locally',
    () async {
      var calls = 0;
      final api = AccountApi(
        CustomerApi(
          MockClient((r) async {
            calls++;
            expect(r.url.path, '/api/orders/order-1/feedback');
            expect(r.headers['Authorization'], 'Bearer token');
            expect(jsonDecode(r.body), {
              'rating': 5,
              'message': 'Great service',
            });
            return http.Response('{"id":"feedback"}', 201);
          }),
        ),
      );
      await expectLater(
        api.feedback('token', 'order-1', 0, ''),
        throwsA(isA<ApiException>()),
      );
      await api.feedback('token', 'order-1', 5, ' Great service ');
      expect(calls, 1);
    },
  );
}
