import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'location_provider_stub.dart'
    if (dart.library.html) 'location_provider_web.dart';

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

Future<GpsLocationResult> fetchCurrentLocation({http.Client? client}) async {
  final coords = await getCurrentGpsCoordinates();
  if (coords == null) {
    throw Exception(
      'Unable to retrieve current GPS location. Please ensure location permissions are enabled.',
    );
  }

  final lat = coords.$1;
  final lng = coords.$2;
  final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  String? city;
  String? pincode;
  String? streetArea;

  final httpClient = client ?? http.Client();
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
    );
    final response = await httpClient
        .get(uri, headers: {'User-Agent': 'DarkToWhiteCustomerApp/1.0'})
        .timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['address'] is Map) {
        final address = data['address'] as Map;
        pincode = address['postcode']?.toString().replaceAll(
          RegExp(r'\s+'),
          '',
        );
        final rawCity =
            address['city'] ??
            address['town'] ??
            address['village'] ??
            address['suburb'] ??
            address['city_district'] ??
            address['county'];
        if (rawCity != null) city = rawCity.toString();

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
    // If reverse geocode is slow or fails, we still return the coordinates and Maps URL
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
