import 'package:flutter/foundation.dart';

import 'brand_api.dart';
import 'customer_api.dart';

class CatalogPrice {
  final String segment, service;
  final int paise;
  const CatalogPrice(this.segment, this.service, this.paise);
  factory CatalogPrice.parse(dynamic data) {
    if (data is! Map ||
        data['segment'] is! String ||
        data['service'] is! String ||
        data['priceRupees'] is! num) {
      throw const FormatException('Invalid catalogue price');
    }
    final amount = data['priceRupees'] as num;
    if (!amount.isFinite || amount < 0) {
      throw const FormatException('Invalid catalogue amount');
    }
    return CatalogPrice(
      data['segment'] as String,
      data['service'] as String,
      (amount * 100).round(),
    );
  }
}

class CatalogItem {
  final String id, name;
  final String? icon;
  final List<CatalogPrice> prices;
  const CatalogItem({
    required this.id,
    required this.name,
    this.icon,
    required this.prices,
  });
  factory CatalogItem.parse(dynamic data) {
    if (data is! Map ||
        data['itemId'] is! String ||
        data['name'] is! String ||
        data['lines'] is! List ||
        (data['itemId'] as String).trim().isEmpty ||
        (data['name'] as String).trim().isEmpty) {
      throw const FormatException('Invalid catalogue item');
    }
    return CatalogItem(
      id: data['itemId'] as String,
      name: data['name'] as String,
      icon: data['icon'] is String ? data['icon'] as String : null,
      prices: List.unmodifiable(
        (data['lines'] as List).map(CatalogPrice.parse),
      ),
    );
  }
  int? get startingPrice => prices.isEmpty
      ? null
      : prices.map((p) => p.paise).reduce((a, b) => a < b ? a : b);
  bool matches(String query) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty);
    final text =
        '$name ${prices.map((p) => '${p.segment} ${p.service}').join(' ')}'
            .toLowerCase();
    return terms.every(text.contains);
  }

  Uri? get imageUri {
    final raw = icon?.trim() ?? '';
    if (!raw.startsWith('/') && !raw.startsWith('https://')) return null;
    final uri = Uri.tryParse(AppConfig.assetOrigin)?.resolve(raw);
    if (uri?.scheme != 'https' || uri!.host.isEmpty) return null;
    final api = Uri.tryParse(AppConfig.apiUrl);
    if (kIsWeb &&
        api?.host == '127.0.0.1' &&
        uri.host == 'bubblerdb.krackbot.com' &&
        uri.path.startsWith(
          '/storage/v1/object/public/assets/catalog-icons/',
        )) {
      return api!.replace(path: uri.path, query: null, fragment: null);
    }
    return uri;
  }
}

String rupees(int paise) =>
    '₹${paise % 100 == 0 ? paise ~/ 100 : (paise / 100).toStringAsFixed(2)}';
typedef CatalogLoader = Future<List<CatalogItem>> Function(String branchId);

class CatalogApi {
  final CustomerApi api;
  CatalogApi(this.api);
  Future<List<CatalogItem>> load(
    String branchId,
    List<Branch> allowedBranches,
  ) async {
    if (branchId.isEmpty || !allowedBranches.any((b) => b.id == branchId)) {
      throw const ApiException('Select a Vclean branch to view its prices.');
    }
    final data = await api.request(
      '/items/price-list',
      query: {'branchId': branchId},
    );
    try {
      if (data is! List) throw const FormatException();
      return List.unmodifiable(data.map(CatalogItem.parse));
    } on FormatException {
      throw const ApiException(
        'The catalogue could not be read. Please try again.',
      );
    }
  }
}
