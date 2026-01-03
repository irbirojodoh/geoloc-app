import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../services/location_service.dart';

/// Location state
class LocationState {
  final Position? position;
  final bool isLoading;
  final bool hasPermission;
  final bool isServiceEnabled;
  final String? error;

  const LocationState({
    this.position,
    this.isLoading = false,
    this.hasPermission = false,
    this.isServiceEnabled = true,
    this.error,
  });

  LocationState copyWith({
    Position? position,
    bool? isLoading,
    bool? hasPermission,
    bool? isServiceEnabled,
    String? error,
  }) {
    return LocationState(
      position: position ?? this.position,
      isLoading: isLoading ?? this.isLoading,
      hasPermission: hasPermission ?? this.hasPermission,
      isServiceEnabled: isServiceEnabled ?? this.isServiceEnabled,
      error: error,
    );
  }

  /// Get latitude or null
  double? get latitude => position?.latitude;

  /// Get longitude or null
  double? get longitude => position?.longitude;

  /// Check if location is available
  bool get hasLocation => position != null;
}

/// Location state notifier provider
final locationStateProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
      return LocationNotifier(ref.watch(locationServiceProvider));
    });

/// Current position provider (convenience)
final currentPositionProvider = Provider<Position?>((ref) {
  return ref.watch(locationStateProvider).position;
});

/// Location notifier for managing location state
class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService _locationService;

  LocationNotifier(this._locationService) : super(const LocationState()) {
    _initializeLocation();
  }

  /// Initialize location on startup
  Future<void> _initializeLocation() async {
    state = state.copyWith(isLoading: true);

    try {
      // Check if service is enabled
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLoading: false,
          isServiceEnabled: false,
          error: 'Location services are disabled',
        );
        return;
      }

      // Check permission
      final hasPermission = await _locationService.checkAndRequestPermission();
      state = state.copyWith(hasPermission: hasPermission);

      if (hasPermission) {
        // Try to get last known location first (faster)
        final lastKnown = await _locationService.getLastKnownLocation();
        if (lastKnown != null) {
          state = state.copyWith(position: lastKnown);
        }

        // Then get current location
        await refreshLocation();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Location permission denied',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh current location
  Future<void> refreshLocation() async {
    if (!state.hasPermission) {
      final hasPermission = await _locationService.checkAndRequestPermission();
      if (!hasPermission) {
        state = state.copyWith(error: 'Location permission denied');
        return;
      }
      state = state.copyWith(hasPermission: true);
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final position = await _locationService.getCurrentLocation();
      state = state.copyWith(position: position, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Request permission
  Future<bool> requestPermission() async {
    final hasPermission = await _locationService.checkAndRequestPermission();
    state = state.copyWith(hasPermission: hasPermission);

    if (hasPermission) {
      await refreshLocation();
    }

    return hasPermission;
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
