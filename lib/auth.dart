import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'brand_api.dart';
import 'customer_api.dart';

class CustomerProfile {
  final String id, phone;
  final String? name, email;
  const CustomerProfile({
    required this.id,
    required this.phone,
    this.name,
    this.email,
  });
  factory CustomerProfile.parse(dynamic data) {
    if (data is! Map ||
        data['id'] is! String ||
        data['phone'] is! String ||
        (data['role'] as String? ?? '').toUpperCase() != 'CUSTOMER' ||
        (data['brandId'] != null && data['brandId'] != AppConfig.brandId)) {
      throw const ApiException('Please use a Vclean customer account.');
    }
    return CustomerProfile(
      id: data['id'] as String,
      phone: data['phone'] as String,
      name: data['name'] is String ? data['name'] as String : null,
      email: data['email'] is String ? data['email'] as String : null,
    );
  }
}

class CustomerSession {
  final String token;
  final CustomerProfile customer;
  const CustomerSession(this.token, this.customer);
}

abstract interface class CustomerAuth {
  Future<String> requestOtp(String phone);
  Future<CustomerSession> verifyOtp(
    String phone,
    String code,
    String requestId,
  );
  Future<CustomerSession> restore(String token);
}

class AuthApi implements CustomerAuth {
  final CustomerApi api;
  AuthApi(this.api);
  @override
  Future<String> requestOtp(String phone) async {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      throw const ApiException('Enter a valid mobile number.');
    }
    final data = await api.request(
      '/auth/customer/otp/request',
      body: {'phone': phone, 'brandCode': AppConfig.brandCode},
    );
    // The legacy API uses the phone as requestId when it omits an explicit ID.
    if (data is! Map) {
      throw const ApiException(
        'The sign-in response could not be read. Please try again.',
      );
    }
    final id = data['requestId'];
    return id is String && id.isNotEmpty ? id : phone;
  }

  @override
  Future<CustomerSession> verifyOtp(
    String phone,
    String code,
    String requestId,
  ) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const ApiException('Enter the 6-digit code.');
    }
    final data = await api.request(
      '/auth/customer/otp/verify',
      body: {
        'phone': phone,
        'otp': code,
        'requestId': requestId,
        'brandCode': AppConfig.brandCode,
      },
    );
    if (data is! Map ||
        data['token'] is! String ||
        (data['token'] as String).trim().isEmpty) {
      throw const ApiException(
        'Sign-in could not be verified. Please request a new code.',
      );
    }
    final customer = CustomerProfile.parse(data['user']);
    final returnedPhone = customer.phone.replaceAll(RegExp(r'\D'), '');
    if (returnedPhone != phone && returnedPhone != '91$phone') {
      throw const ApiException(
        'The sign-in response does not match your number.',
      );
    }
    // Only the server's successful, brand-scoped verification creates a session.
    return CustomerSession(data['token'] as String, customer);
  }

  @override
  Future<CustomerSession> restore(String token) async {
    final data = await api.request('/me', token: token);
    if (data is! Map) {
      throw const ApiException('Your profile could not be loaded.');
    }
    return CustomerSession(token, CustomerProfile.parse(data['user']));
  }
}

abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Browser preview sessions stay in memory. Mobile tokens use platform secure storage.
class MemorySessionStore implements SessionStore {
  String? _token;
  @override
  Future<String?> read() async => _token;
  @override
  Future<void> write(String token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

class SecureSessionStore implements SessionStore {
  static const _key = 'vclean.customer.session.v1';
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => storage.read(key: _key);
  @override
  Future<void> write(String token) => storage.write(key: _key, value: token);
  @override
  Future<void> clear() => storage.delete(key: _key);
}

SessionStore platformSessionStore() =>
    kIsWeb ? MemorySessionStore() : SecureSessionStore();
