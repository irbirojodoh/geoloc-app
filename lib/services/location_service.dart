import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/errors/failures.dart';

/// Provider for [LocationService].
///
/// Note: the `LocationState` data class lives in
/// `presentation/providers/location_provider.dart`. Do not redefine it here.
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Location service for handling geolocation
class LocationService {
  /// Location settings for high accuracy
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100, // Update every 100 meters
  );

  /// Check and request location permission
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current location
  Future<Position> getCurrentLocation() async {
    final hasPermission = await checkAndRequestPermission();

    if (!hasPermission) {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        throw const LocationPermissionFailure(
          message:
              'Location permission permanently denied. Please enable in Settings.',
        );
      }
      throw const LocationPermissionFailure();
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      throw LocationServiceFailure(
        message: 'Failed to get current location',
        details: e.toString(),
      );
    }
  }

  /// Get last known location (faster, but might be stale)
  Future<Position?> getLastKnownLocation() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }

  /// Stream location updates
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(locationSettings: _locationSettings);
  }

  /// Calculate distance between two points in kilometers
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
          startLatitude,
          startLongitude,
          endLatitude,
          endLongitude,
        ) /
        1000; // Convert meters to km
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (for permission denied forever)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Check if location service is enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current permission status
  Future<LocationPermission> getPermissionStatus() async {
    return await Geolocator.checkPermission();
  }
}
