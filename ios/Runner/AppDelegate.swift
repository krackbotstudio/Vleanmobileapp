import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate {
  private var locationManager: CLLocationManager?
  private var locationResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let controller = controller {
      let channel = FlutterMethodChannel(
        name: "com.vcleanlaundry/location",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "getCurrentLocation" {
          self?.getCurrentLocation(result: result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func getCurrentLocation(result: @escaping FlutterResult) {
    locationResult = result
    locationManager = CLLocationManager()
    locationManager?.delegate = self
    locationManager?.desiredAccuracy = kCLLocationAccuracyBest

    let status = locationManager?.authorizationStatus ?? .notDetermined
    switch status {
    case .notDetermined:
      locationManager?.requestWhenInUseAuthorization()
    case .restricted, .denied:
      locationResult = nil
      result(FlutterError(
        code: "PERMISSION_DENIED",
        message: "Location permission denied. Please allow location access in app settings.",
        details: nil
      ))
    case .authorizedWhenInUse, .authorizedAlways:
      locationManager?.requestLocation()
      DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
        if self?.locationResult != nil {
          self?.locationManager?.stopUpdatingLocation()
          self?.locationResult?(FlutterError(
            code: "TIMEOUT",
            message: "Location request timed out. Please try again.",
            details: nil
          ))
          self?.locationResult = nil
        }
      }
    @unknown default:
      locationResult = nil
      result(FlutterError(
        code: "UNKNOWN",
        message: "Unknown location authorization status.",
        details: nil
      ))
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    guard locationResult != nil else { return }

    switch status {
    case .authorizedWhenInUse, .authorizedAlways:
      manager.requestLocation()
      DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
        if self?.locationResult != nil {
          self?.locationManager?.stopUpdatingLocation()
          self?.locationResult?(FlutterError(
            code: "TIMEOUT",
            message: "Location request timed out. Please try again.",
            details: nil
          ))
          self?.locationResult = nil
        }
      }
    case .denied, .restricted:
      locationResult?(FlutterError(
        code: "PERMISSION_DENIED",
        message: "Location permission denied. Please allow location access in app settings.",
        details: nil
      ))
      locationResult = nil
    default:
      break
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last, let result = locationResult else { return }
    locationResult = nil
    result([
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard let result = locationResult else { return }
    locationResult = nil
    result(FlutterError(
      code: "LOCATION_ERROR",
      message: "Failed to get location: \(error.localizedDescription)",
      details: nil
    ))
  }
}
