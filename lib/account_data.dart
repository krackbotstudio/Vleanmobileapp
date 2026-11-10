import 'auth.dart';
import 'brand_api.dart';
import 'customer_api.dart';

Map<String, dynamic> record(dynamic value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid record');
  }
  if (value['brandId'] != null && value['brandId'] != AppConfig.brandId) {
    throw const ApiException('This record does not belong to Vclean.');
  }
  return value;
}

String field(Map<String, dynamic> data, String name) =>
    data[name] is String ? data[name] as String : '';
String recordId(Map<String, dynamic> data) {
  final id = field(data, 'id');
  if (id.isEmpty) throw const FormatException('Missing record ID');
  return id;
}

int? amount(dynamic value) {
  if (value == null) return null;
  if (value is! num || !value.isFinite || value < 0 || value != value.round()) {
    throw const FormatException('Invalid amount');
  }
  return value.toInt();
}

String statusCode(String value) =>
    value.toUpperCase().replaceAll('-', '_').trim();
String statusLabel(String value) =>
    const {
      'BOOKING_CONFIRMED': 'Booking confirmed',
      'PICKUP_SCHEDULED': 'Pickup scheduled',
      'PICKED_UP': 'Picked up',
      'IN_PROCESSING': 'In progress',
      'IN_PROCESS': 'In progress',
      'READY': 'Ready',
      'OUT_FOR_DELIVERY': 'Out for delivery',
      'DELIVERED': 'Delivered',
      'COMPLETED': 'Delivered',
      'CANCELLED': 'Cancelled',
      'CANCELED': 'Cancelled',
    }[statusCode(value)] ??
    value.replaceAll('_', ' ');
String serviceLabel(String value) => value
    .split(',')
    .map(
      (part) =>
          const {
            'WASH_FOLD': 'Wash & Fold',
            'WASH_IRON': 'Wash & Iron',
            'DRY_CLEAN': 'Dry cleaning',
            'STEAM_IRON': 'Steam Iron',
            'SHOES': 'Shoe cleaning',
            'HOME_LINEN': 'Home linen',
            'ADD_ONS': 'Add-ons',
          }[statusCode(part)] ??
          part.trim().replaceAll('_', ' '),
    )
    .join(', ');

class CustomerOrder {
  final Map<String, dynamic> data;
  final String id, status;
  CustomerOrder(dynamic value)
    : data = record(value),
      id = recordId(record(value)),
      status = field(record(value), 'status') {
    if (status.isEmpty) throw const FormatException('Missing order status');
    amount(data['amountToPayPaise']);
  }
  String text(String key) => field(data, key);
  String get code => statusCode(status);
  bool get cancelled => const ['CANCELLED', 'CANCELED'].contains(code);
  bool get delivered => const ['DELIVERED', 'COMPLETED'].contains(code);
  bool get completed => cancelled || delivered;
  bool get paid =>
      const ['CAPTURED', 'PAID'].contains(statusCode(text('paymentStatus')));
  bool get walkIn =>
      statusCode(text('orderSource')) == 'WALK_IN' ||
      statusCode(text('orderType')) == 'WALK_IN';
  String get services {
    final list = data['serviceTypes'];
    return list is List && list.isNotEmpty
        ? list.whereType<String>().map(serviceLabel).join(', ')
        : serviceLabel(text('serviceType'));
  }

  int? get due => amount(data['amountToPayPaise']);
  int? get trackingStage => switch (code) {
    'BOOKING_CONFIRMED' || 'PICKUP_SCHEDULED' || 'RECEIVED' => 0,
    'PICKED_UP' || 'IN_PROCESSING' || 'IN_PROCESS' || 'READY' => 1,
    'OUT_FOR_DELIVERY' => 2,
    'DELIVERED' || 'COMPLETED' => 3,
    _ => null,
  };
  List<CustomerInvoice>? get embeddedInvoices => data['invoices'] is List
      ? (data['invoices'] as List).map(CustomerInvoice.new).toList()
      : null;
}

class CustomerInvoice {
  final Map<String, dynamic> data;
  final String id;
  final int total;
  CustomerInvoice(dynamic value)
    : data = record(value),
      id = recordId(record(value)),
      total =
          amount(record(value)['total']) ??
          (throw const FormatException('Missing invoice total')) {
    for (final key in [
      'subtotal',
      'tax',
      'discountPaise',
      'advancePaymentAmount',
    ]) {
      amount(data[key]);
    }
    for (final item in items) {
      amount(item['unitPrice']);
      amount(item['amount']);
      final quantity = item['quantity'];
      if (quantity != null &&
          (quantity is! num || !quantity.isFinite || quantity < 0)) {
        throw const FormatException('Invalid quantity');
      }
    }
  }
  String text(String key) => field(data, key);
  int? money(String key) => amount(data[key]);
  bool get finalInvoice => statusCode(text('type')) == 'FINAL';
  bool get acknowledgement => statusCode(text('type')) == 'ACKNOWLEDGEMENT';
  bool get voided => const [
    'VOID',
    'VOIDED',
    'CANCELLED',
  ].contains(statusCode(text('status')));
  List<Map<String, dynamic>> get items =>
      data['items'] is List ? (data['items'] as List).map(record).toList() : [];
}

int invoiceAdvance(CustomerInvoice invoice, List<CustomerInvoice> invoices) {
  final own = invoice.money('advancePaymentAmount');
  if (own != null) return own;
  if (invoice.finalInvoice) {
    for (final candidate in invoices) {
      if (candidate.acknowledgement && !candidate.voided) {
        return candidate.money('advancePaymentAmount') ?? 0;
      }
    }
  }
  return 0;
}

class SavedAddress {
  final Map<String, dynamic> data;
  final String id;
  SavedAddress(dynamic value)
    : data = record(value),
      id = recordId(record(value));
  String text(String key) => field(data, key);
  bool get isDefault => data['isDefault'] == true;
  bool get walkIn => statusCode(text('source')) == 'WALK_IN';
}

class AccountApi {
  final CustomerApi api;
  AccountApi(this.api);
  String pathId(String id) {
    if (id.trim().isEmpty) {
      throw const ApiException('The selected record is unavailable.');
    }
    return Uri.encodeComponent(id);
  }

  Future<T> parse<T>(
    Future<dynamic> response,
    T Function(dynamic) decode,
  ) async {
    final value = await response;
    try {
      return decode(value);
    } on FormatException {
      throw const ApiException(
        'The server returned incomplete details. Please refresh.',
      );
    } on TypeError {
      throw const ApiException(
        'The server returned incomplete details. Please refresh.',
      );
    }
  }

  Future<CustomerProfile> profile(String token) => parse(
    api.request('/me', token: token),
    (value) => CustomerProfile.parse(record(value)['user']),
  );
  Future<void> updateProfile(String token, String name, String email) async {
    await api.request(
      '/me',
      token: token,
      method: 'PATCH',
      body: {
        'name': name.trim(),
        if (email.trim().isNotEmpty) 'email': email.trim(),
      },
    );
  }

  static String _normalizeTimeWindow(String window) {
    final clean = window
        .replaceAll(' ', '')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .toLowerCase();
    if (clean.contains('9am') ||
        clean.startsWith('9-') ||
        clean.startsWith('09:')) {
      return '09:00-12:00';
    }
    if (clean.contains('12pm') ||
        clean.startsWith('12-') ||
        clean.startsWith('12:')) {
      return '12:00-15:00';
    }
    if (clean.contains('3pm') ||
        clean.startsWith('3-') ||
        clean.startsWith('15:')) {
      return '15:00-18:00';
    }
    return window;
  }

  Future<String> createOrder(
    String token, {
    required String addressId,
    required String pickupDate,
    required String timeWindow,
    List<String> selectedServices = const [],
    String? branchId,
    double? estimatedWeightKg,
  }) async {
    final normalizedWindow = _normalizeTimeWindow(timeWindow);
    final payload = <String, dynamic>{
      'orderType': 'INDIVIDUAL',
      'addressId': addressId,
      'pickupDate': pickupDate,
      'timeWindow': normalizedWindow,
      'selectedServices': selectedServices,
      if (branchId != null && branchId.trim().isNotEmpty)
        'branchId': branchId.trim(),
      if (estimatedWeightKg != null) 'estimatedWeightKg': estimatedWeightKg,
    };
    final res = await api.request(
      '/orders',
      method: 'POST',
      token: token,
      body: payload,
    );
    if (res is Map && res['orderId'] != null) {
      return res['orderId'].toString();
    }
    if (res is Map && res['id'] != null) {
      return res['id'].toString();
    }
    return '';
  }

  Future<List<Map<String, dynamic>>> notifications(String token) async {
    try {
      final res = await api.request('/notifications', token: token);
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (res is Map && res['notifications'] is List) {
        return (res['notifications'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<CustomerOrder>> orders(String token) =>
      parse(api.request('/orders', token: token), (value) {
        if (value is! List) throw const FormatException();
        final rows = value.map(CustomerOrder.new).toList();
        return [
          ...rows.where((row) => !row.completed),
          ...rows.where((row) => row.completed),
        ];
      });
  Future<CustomerOrder> order(String token, String id) =>
      parse(api.request('/orders/${pathId(id)}', token: token), (value) {
        final result = CustomerOrder(value);
        if (result.id != id) throw const FormatException();
        return result;
      });
  Future<List<CustomerInvoice>> invoices(String token, String id) => parse(
    api.request('/orders/${pathId(id)}/invoices', token: token),
    (value) {
      if (value is! List) throw const FormatException();
      return value.map(CustomerInvoice.new).toList();
    },
  );
  Future<bool> feedbackEligible(String token, String id) => parse(
    api.request('/orders/${pathId(id)}/feedback/eligibility', token: token),
    (value) {
      final data = record(value);
      return data['eligible'] == true && data['alreadySubmitted'] != true;
    },
  );
  Future<void> feedback(
    String token,
    String id,
    int rating,
    String message,
  ) async {
    if (rating < 1 || rating > 5) {
      throw const ApiException('Select a star rating.');
    }
    await api.request(
      '/orders/${pathId(id)}/feedback',
      token: token,
      body: {
        'rating': rating,
        if (message.trim().isNotEmpty) 'message': message.trim(),
      },
    );
  }

  Future<List<SavedAddress>> addresses(String token, String customerId) =>
      parse(api.request('/addresses', token: token), (value) {
        if (value is! List) throw const FormatException();
        final rows = value.map(SavedAddress.new).toList();
        if (rows.any(
          (a) => a.text('userId').isNotEmpty && a.text('userId') != customerId,
        )) {
          throw const ApiException(
            'The address list does not match your account.',
          );
        }
        return rows.where((a) => !a.walkIn).toList();
      });
  Future<void> ensureEditable(String token, String id) async {
    if ((await orders(
      token,
    )).any((order) => !order.completed && order.text('addressId') == id)) {
      throw const ApiException(
        'This address has an active order. You can edit it after the order is completed or cancelled.',
      );
    }
  }

  Future<void> saveAddress(
    String token,
    Map<String, dynamic> body, {
    String? id,
  }) async {
    if (id != null) await ensureEditable(token, id);
    await api.request(
      id == null ? '/addresses' : '/addresses/${pathId(id)}',
      token: token,
      method: id == null ? 'POST' : 'PATCH',
      body: body,
    );
  }

  Future<void> deleteAddress(String token, String id) async {
    await ensureEditable(token, id);
    await api.request(
      '/addresses/${pathId(id)}',
      token: token,
      method: 'DELETE',
    );
  }

  Future<List<Branch>> servingBranches(String pincode) async {
    if (!RegExp(r'^[1-9]\d{5}$').hasMatch(pincode)) {
      throw const ApiException('Enter a valid six-digit pincode.');
    }
    final directory = await parse(
      api.request('/branding/public/${AppConfig.brandSlug}'),
      (data) => BrandInfo.parse(record(data)),
    );
    return parse(
      api.request('/serviceability/branches', query: {'pincode': pincode}),
      (value) {
        final rows = record(value)['branches'];
        if (rows is! List) throw const FormatException();
        final permitted = directory.branches.map((b) => b.id).toSet();
        return rows
            .whereType<Map<String, dynamic>>()
            .where(
              (b) =>
                  permitted.contains(b['id']) &&
                  (b['brandId'] == null || b['brandId'] == AppConfig.brandId),
            )
            .map((b) => Branch(recordId(b), field(b, 'name')))
            .toList();
      },
    );
  }

  Future<void> requestArea(
    CustomerProfile customer,
    String pincode,
    String address,
  ) async {
    await api.request(
      '/feedback/area-request',
      body: {
        'pincode': pincode,
        'addressLine': address,
        'customerPhone': customer.phone,
        if (customer.name?.isNotEmpty == true) 'customerName': customer.name,
        if (customer.email?.isNotEmpty == true) 'customerEmail': customer.email,
      },
    );
  }
}
