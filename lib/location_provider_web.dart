import 'dart:async';
import 'dart:html' as html;

Future<(double, double)?> getCurrentGpsCoordinates() async {
  try {
    final pos = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 10),
    );
    final lat = pos.coords?.latitude?.toDouble();
    final lng = pos.coords?.longitude?.toDouble();
    if (lat != null && lng != null) {
      return (lat, lng);
    }
  } catch (e) {
    rethrow;
  }
  return null;
}
