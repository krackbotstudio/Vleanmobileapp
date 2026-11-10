import 'dart:convert';

import 'package:http/http.dart' as http;

abstract final class AppConfig {
  static const apiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://apibubbler.krackbot.com/api',
  );
  static const brandSlug = String.fromEnvironment(
    'BRAND_SLUG',
    defaultValue: 'Vclean',
  );
  static const brandCode = String.fromEnvironment(
    'BRAND_CODE',
    defaultValue: 'Vclean',
  );
  static const brandId = String.fromEnvironment(
    'BRAND_ID',
    defaultValue: '87211d7b-1b57-417f-9762-4a5c4d42945a',
  );
  static const assetOrigin = String.fromEnvironment(
    'ASSET_BASE_URL',
    defaultValue: 'https://apibubbler.krackbot.com',
  );
}

class Branch {
  final String id, name;
  const Branch(this.id, this.name);
}

class BrandInfo {
  final String name, privacy, terms;
  final List<Branch> branches;
  const BrandInfo({
    required this.name,
    required this.privacy,
    required this.terms,
    required this.branches,
  });
  factory BrandInfo.parse(Map<String, dynamic> json) {
    if (json['brandId'] != AppConfig.brandId) {
      throw const FormatException('Unexpected brand');
    }
    final branches = <Branch>[];
    for (final item in (json['branches'] as List? ?? [])) {
      if (item is Map &&
          item['brandId'] == AppConfig.brandId &&
          item['id'] is String &&
          item['name'] is String) {
        branches.add(Branch(item['id'] as String, item['name'] as String));
      }
    }
    return BrandInfo(
      name: json['businessName'] as String? ?? 'Vclean laundry',
      privacy: json['privacyPolicy'] as String? ?? '',
      terms: json['termsAndConditions'] as String? ?? '',
      branches: branches,
    );
  }
}

class BrandApi {
  final http.Client client;
  BrandApi(this.client);
  Future<List<String>> loadBanners() async {
    final base = AppConfig.apiUrl.replaceFirst(RegExp(r'/+$'), '');
    final response = await client
        .get(
          Uri.parse('$base/carousel/public'),
          headers: {
            'X-Brand-Code': AppConfig.brandCode,
            'X-Brand-Id': AppConfig.brandId,
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw const FormatException('Banners unavailable');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['imageUrls'] as List? ?? [])
        .whereType<String>()
        .map(
          (value) => Uri.parse(AppConfig.assetOrigin).resolve(value).toString(),
        )
        .where((value) => Uri.parse(value).scheme == 'https')
        .toList();
  }

  Future<BrandInfo> load() async {
    final base = AppConfig.apiUrl.replaceFirst(RegExp(r'/+$'), '');
    final response = await client
        .get(
          Uri.parse(
            '$base/branding/public/${Uri.encodeComponent(AppConfig.brandSlug)}',
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw const FormatException('Brand information unavailable');
    }
    return BrandInfo.parse(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
