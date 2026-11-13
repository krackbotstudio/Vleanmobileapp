import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class GpsLocationResult {
  final double latitude;
  final double longitude;
  final String googleMapsUrl;
  final String? city;
  final String? pincode;
  final String? streetArea;

  const GpsLocationResult({
    required this.latitude,
    required this.longitude,
    required this.googleMapsUrl,
    this.city,
    this.pincode,
    this.streetArea,
  });
}

const _channel = MethodChannel('com.vcleanlaundry/location');

Future<(double, double)> getCurrentGpsCoordinates() async {
  if (kIsWeb) {
    throw PlatformException(
      code: 'UNSUPPORTED',
      message: 'GPS auto-detection is available on Android and iOS devices.',
    );
  }
  final result = await _channel.invokeMethod<Map>('getCurrentLocation');
  if (result == null) {
    throw Exception('Unable to retrieve current GPS location.');
  }
  final lat = (result['latitude'] as num).toDouble();
  final lng = (result['longitude'] as num).toDouble();
  return (lat, lng);
}

Future<GpsLocationResult> fetchCurrentLocation({http.Client? client}) async {
  final coords = await getCurrentGpsCoordinates();
  final lat = coords.$1;
  final lng = coords.$2;
  final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  String? city;
  String? pincode;
  String? streetArea;

  final httpClient = client ?? http.Client();
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&addressdetails=1',
    );
    final response = await httpClient
        .get(uri, headers: {'User-Agent': 'VcleanCustomerApp/1.0 (com.vcleanlaundry)'})
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['address'] is Map) {
        final address = data['address'] as Map;

        // Pincode (6 digits)
        final rawPin =
            address['postcode']?.toString().replaceAll(RegExp(r'\D'), '');
        if (rawPin != null && rawPin.length == 6) {
          pincode = rawPin;
        }

        // City
        final rawCity =
            address['city'] ??
            address['town'] ??
            address['village'] ??
            address['suburb'] ??
            address['city_district'] ??
            address['county'];
        if (rawCity != null && rawCity.toString().trim().isNotEmpty) {
          city = rawCity.toString().trim();
        }

        // Street & area
        final road = address['road']?.toString() ?? '';
        final area =
            address['suburb']?.toString() ??
            address['neighbourhood']?.toString() ??
            address['residential']?.toString() ??
            '';
        final parts = [road, area].where((s) => s.trim().isNotEmpty).toList();
        if (parts.isNotEmpty) {
          streetArea = parts.join(', ');
        }
      }
    }
  } catch (_) {
    // Non-fatal: maps link and coordinates are still returned even if reverse-lookup fails
  } finally {
    if (client == null) httpClient.close();
  }

  return GpsLocationResult(
    latitude: lat,
    longitude: lng,
    googleMapsUrl: mapsUrl,
    city: city,
    pincode: pincode,
    streetArea: streetArea,
  );
}
