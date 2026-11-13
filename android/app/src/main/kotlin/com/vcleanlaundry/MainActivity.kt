package com.vcleanlaundry

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.vcleanlaundry/location"
    private val LOCATION_PERMISSION_REQUEST = 1001

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentLocation" -> getCurrentLocation(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            pendingResult = result
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ),
                LOCATION_PERMISSION_REQUEST
            )
            return
        }
        fetchLocation(result)
    }

    private fun fetchLocation(result: MethodChannel.Result) {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("PERMISSION_DENIED", "Location permission denied", null)
            return
        }

        val locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

        val isGpsEnabled = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
        val isNetworkEnabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)

        if (!isGpsEnabled && !isNetworkEnabled) {
            result.error(
                "LOCATION_DISABLED",
                "Location services are disabled. Please turn on GPS in your device settings.",
                null
            )
            return
        }

        // Fast path: use cached location if recent (< 60s)
        val provider = if (isGpsEnabled) LocationManager.GPS_PROVIDER else LocationManager.NETWORK_PROVIDER
        val lastLocation = locationManager.getLastKnownLocation(provider)
            ?: locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)

        if (lastLocation != null && System.currentTimeMillis() - lastLocation.time < 60000) {
            result.success(
                mapOf(
                    "latitude" to lastLocation.latitude,
                    "longitude" to lastLocation.longitude
                )
            )
            return
        }

        // Fresh GPS update request
        var responded = false
        val handler = Handler(Looper.getMainLooper())

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                if (!responded) {
                    responded = true
                    locationManager.removeUpdates(this)
                    result.success(
                        mapOf(
                            "latitude" to location.latitude,
                            "longitude" to location.longitude
                        )
                    )
                }
            }

            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }

        try {
            if (isGpsEnabled) {
                locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER, 0L, 0f, listener, Looper.getMainLooper()
                )
            }
            if (isNetworkEnabled) {
                locationManager.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER, 0L, 0f, listener, Looper.getMainLooper()
                )
            }
        } catch (e: Exception) {
            if (!responded) {
                responded = true
                result.error("LOCATION_ERROR", "Failed to request location: ${e.message}", null)
            }
            return
        }

        // 15-second timeout
        handler.postDelayed({
            if (!responded) {
                responded = true
                locationManager.removeUpdates(listener)
                val fallback = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                    ?: locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                if (fallback != null) {
                    result.success(
                        mapOf(
                            "latitude" to fallback.latitude,
                            "longitude" to fallback.longitude
                        )
                    )
                } else {
                    result.error("TIMEOUT", "Location request timed out. Please try again.", null)
                }
            }
        }, 15000)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == LOCATION_PERMISSION_REQUEST) {
            val result = pendingResult
            pendingResult = null
            if (result == null) return

            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                fetchLocation(result)
            } else {
                result.error(
                    "PERMISSION_DENIED",
                    "Location permission denied. Please allow location access in app settings.",
                    null
                )
            }
        }
    }
}
