import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vclean_laundry/brand_api.dart';

void main() {
  test('requests the authorized brand and filters foreign branches', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/branding/public/${AppConfig.brandSlug}');
      // Brand is explicit in the URL and validated in the response.
      // Custom headers are unnecessary here and would trigger a failed CORS preflight.
      expect(request.headers.containsKey('X-Brand-Code'), isFalse);
      return http.Response(
        '''{"brandId":"${AppConfig.brandId}","businessName":"Vclean laundry",
        "branches":[{"id":"ours","name":"Example","brandId":"${AppConfig.brandId}"},
        {"id":"other","name":"Other","brandId":"other-brand"}]}''',
        200,
      );
    });
    final info = await BrandApi(client).load();
    expect(info.branches.map((branch) => branch.id), ['ours']);
    client.close();
  });
  test('rejects a different brand response', () {
    expect(() => BrandInfo.parse({'brandId': 'other'}), throwsFormatException);
  });
  test('handles server errors without returning fake live data', () async {
    final client = MockClient((_) async => http.Response('Unavailable', 503));
    await expectLater(BrandApi(client).load(), throwsFormatException);
    client.close();
  });
}
