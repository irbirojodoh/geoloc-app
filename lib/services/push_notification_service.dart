import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

/// Provider for PushNotificationService
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(apiClientProvider));
});

/// Push notification service for Firebase Cloud Messaging
/// 
/// NOTE: Firebase is not configured yet. Add GoogleService-Info.plist to ios/Runner/
/// and uncomment firebase_core and firebase_messaging in pubspec.yaml to enable.
class PushNotificationService {
  final ApiClient _apiClient;

  PushNotificationService(this._apiClient);

  /// Initialize push notifications
  /// TODO(geoloc): Implement after Firebase is configured (see docs).
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint(
        'Push notifications not configured. Add GoogleService-Info.plist to enable.',
      );
    }
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    // Firebase not configured yet
    return false;
  }

  /// Get FCM device token
  Future<String?> getToken() async {
    // Firebase not configured yet
    return null;
  }

  /// Register device token with backend
  Future<void> registerToken(String token) async {
    try {
      await _apiClient.post(
        ApiEndpoints.registerDevice,
        data: {'token': token, 'platform': 'ios'},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to register FCM token: $e');
    }
  }

  /// Unregister device token
  Future<void> unregisterToken() async {
    try {
      await _apiClient.delete(ApiEndpoints.unregisterDevice);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to unregister FCM token: $e');
    }
  }

  /// Subscribe to a topic (e.g., for location-based notifications)
  Future<void> subscribeToTopic(String topic) async {
    // Firebase not configured yet
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    // Firebase not configured yet
  }
}
