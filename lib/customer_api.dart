import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'brand_api.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Shared brand-scoped transport. Mutating requests are never retried automatically.
class CustomerApi {
  final http.Client client;
  final String baseUrl;
  CustomerApi(this.client, {this.baseUrl = AppConfig.apiUrl});

  Future<dynamic> request(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? token,
    String? method,
  }) async {
    final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base$path').replace(queryParameters: query);
    final headers = <String, String>{
      'X-Brand-Code': AppConfig.brandCode,
      'X-Brand-Id': AppConfig.brandId,
      if (token != null) 'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    try {
      final verb = method ?? (body == null ? 'GET' : 'POST');
      final encoded = body == null ? null : jsonEncode(body);
      final response = await (switch (verb) {
        'GET' => client.get(uri, headers: headers),
        'POST' => client.post(uri, headers: headers, body: encoded),
        'PATCH' => client.patch(uri, headers: headers, body: encoded),
        'DELETE' => client.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported request method'),
      }).timeout(const Duration(seconds: 25));
      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        /* Check status first. */
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = response.statusCode == 429
            ? 'Too many attempts. Please wait before trying again.'
            : response.statusCode >= 500
            ? 'The server is unavailable. Please try again shortly.'
            : 'The request could not be completed. Please try again.';
        if (response.statusCode < 500 && data is Map) {
          final nested = data['error'];
          final rawDetail = nested is Map ? nested['message'] : data['message'];
          final detail = rawDetail is List
              ? rawDetail.whereType<String>().join(', ')
              : rawDetail;
          if (detail is String &&
              detail.trim().isNotEmpty &&
              detail.length <= 300) {
            message = detail;
          }
        }
        throw ApiException(message, response.statusCode);
      }
      if (response.statusCode == 204 || response.body.trim().isEmpty) {
        return null;
      }
      if (data == null) {
        throw const ApiException(
          'The server returned an unreadable response. Please try again.',
        );
      }
      return data;
    } on TimeoutException {
      throw const ApiException(
        'The request timed out. Please check your connection and try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Cannot connect. Please check your connection and try again.',
      );
    }
  }
}
