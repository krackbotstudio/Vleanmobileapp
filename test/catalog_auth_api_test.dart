import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vclean_laundry/auth.dart';
import 'package:vclean_laundry/brand_api.dart';
import 'package:vclean_laundry/catalog.dart';
import 'package:vclean_laundry/customer_api.dart';

void main() {
  test(
    'catalogue uses explicit branch and brand scope and preserves rupee decimals',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/items/price-list');
        expect(request.url.queryParameters, {'branchId': 'branch-one'});
        expect(request.headers['X-Brand-Code'], AppConfig.brandCode);
        expect(request.headers['X-Brand-Id'], AppConfig.brandId);
        return http.Response(
          jsonEncode([
            {
              'itemId': 'shirt',
              'name': 'Shirt',
              'icon': '/api/assets/shirt.png',
              'lines': [
                {
                  'segment': 'MEN',
                  'service': 'STEAM IRON',
                  'priceRupees': 25.50,
                },
                {'segment': 'KIDS', 'service': 'LAUNDRY', 'priceRupees': 0},
              ],
            },
          ]),
          200,
        );
      });
      final rows = await CatalogApi(
        CustomerApi(client),
      ).load('branch-one', const [Branch('branch-one', 'One')]);
      expect(rows.single.prices.first.paise, 2550);
      expect(rows.single.startingPrice, 0);
      expect(rupees(2550), '₹25.50');
      expect(rows.single.matches('men iron'), isTrue);
      expect(
        rows.single.imageUri.toString(),
        'https://apibubbler.krackbot.com/api/assets/shirt.png',
      );
    },
  );
  test('unknown branch never makes a catalogue request', () async {
    var calls = 0;
    final api = CatalogApi(
      CustomerApi(
        MockClient((request) async {
          calls++;
          return http.Response('[]', 200);
        }),
      ),
    );
    await expectLater(
      api.load('foreign', const [Branch('ours', 'Ours')]),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 0);
  });
  test(
    'malformed prices fail without turning into free or sample prices',
    () async {
      for (final price in [null, '25', -5]) {
        final api = CatalogApi(
          CustomerApi(
            MockClient(
              (_) async => http.Response(
                jsonEncode([
                  {
                    'itemId': 'shirt',
                    'name': 'Shirt',
                    'lines': [
                      {
                        'segment': 'MEN',
                        'service': 'IRON',
                        'priceRupees': price,
                      },
                    ],
                  },
                ]),
                200,
              ),
            ),
          ),
        );
        await expectLater(
          api.load('one', const [Branch('one', 'One')]),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );
  test(
    'OTP verification accepts six digits and preserves a leading zero',
    () async {
      final calls = <http.Request>[];
      final api = AuthApi(
        CustomerApi(
          MockClient((request) async {
            calls.add(request);
            expect(request.headers['X-Brand-Code'], AppConfig.brandCode);
            expect(request.headers['X-Brand-Id'], AppConfig.brandId);
            final body = jsonDecode(request.body);
            expect(body['brandCode'], AppConfig.brandCode);
            expect(body['phone'], '9876543210');
            if (request.url.path.endsWith('/request')) {
              return http.Response('{"requestId":"request-1"}', 200);
            }
            expect(body['otp'], '012345');
            expect(body['requestId'], 'request-1');
            return http.Response(
              jsonEncode({
                'token': 'verified-token',
                'user': {
                  'id': 'customer',
                  'phone': '+919876543210',
                  'role': 'CUSTOMER',
                },
              }),
              200,
            );
          }),
        ),
      );
      final id = await api.requestOtp('9876543210');
      for (final invalid in ['1234', '12345', '1234567', '12x456']) {
        await expectLater(
          api.verifyOtp('9876543210', invalid, id),
          throwsA(isA<ApiException>()),
        );
      }
      expect(calls.length, 1);
      final session = await api.verifyOtp('9876543210', '012345', id);
      expect(session.token, 'verified-token');
      expect(session.customer.id, 'customer');
      expect(calls.length, 2);
    },
  );
  test(
    'invalid OTP and throttled requests report failure without automatic retries',
    () async {
      var calls = 0;
      final api = AuthApi(
        CustomerApi(
          MockClient((_) async {
            calls++;
            return http.Response(
              '{"message":"Code expired. Request a new code."}',
              400,
            );
          }),
        ),
      );
      await expectLater(
        api.verifyOtp('9876543210', '012345', 'request'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Code expired'),
          ),
        ),
      );
      expect(calls, 1);
    },
  );
  test(
    'verification rejects staff, foreign-brand and mismatched-phone responses',
    () async {
      for (final user in [
        {'id': 'x', 'phone': '9876543210', 'role': 'ADMIN'},
        {
          'id': 'x',
          'phone': '9876543210',
          'role': 'CUSTOMER',
          'brandId': 'foreign',
        },
        {'id': 'x', 'phone': '9123456780', 'role': 'CUSTOMER'},
      ]) {
        final api = AuthApi(
          CustomerApi(
            MockClient(
              (_) async => http.Response(
                jsonEncode({'token': 'token', 'user': user}),
                200,
              ),
            ),
          ),
        );
        await expectLater(
          api.verifyOtp('9876543210', '012345', 'id'),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );
  test(
    'session restoration checks the profile using bearer and brand headers',
    () async {
      final api = AuthApi(
        CustomerApi(
          MockClient((request) async {
            expect(request.url.path, '/api/me');
            expect(request.headers['Authorization'], 'Bearer existing-token');
            expect(request.headers['X-Brand-Id'], AppConfig.brandId);
            return http.Response(
              '{"user":{"id":"customer","phone":"9876543210","role":"CUSTOMER","name":"Test"}}',
              200,
            );
          }),
        ),
      );
      expect((await api.restore('existing-token')).customer.name, 'Test');
    },
  );
}
