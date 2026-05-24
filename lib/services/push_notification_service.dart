import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

/// Background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  debugPrint('Handling a background message: ${message.messageId}');
}

/// Provider for PushNotificationService
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(apiClientProvider));
});

/// Push notification service for Firebase Cloud Messaging
class PushNotificationService {
  final ApiClient _apiClient;

  PushNotificationService(this._apiClient);

  FirebaseMessaging? _messagingOrNull() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  /// Initialize push notifications
  Future<void> initialize() async {
    final messaging = _messagingOrNull();
    if (messaging == null) return;

    // Request permission on app start
    await requestPermission();

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle initial message (app launched from terminated state via notification)
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Handle message when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // Handle message when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');
      }
      if (message.notification != null && kDebugMode) {
        debugPrint('Message also contained a notification: ${message.notification}');
      }
    });
  }

  void _handleMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('Navigating to specific screen based on message: ${message.data}');
    }
    // TODO: implement navigation logic based on notification type
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    final messaging = _messagingOrNull();
    if (messaging == null) return false;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint('User granted permission: ${settings.authorizationStatus}');
    }
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
           settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Get FCM device token
  Future<String?> getToken() async {
    try {
      final messaging = _messagingOrNull();
      if (messaging == null) return null;
      return await messaging.getToken();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to get FCM token: $e');
      return null;
    }
  }

  /// Register device token with backend
  Future<void> registerToken(String token) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      await _apiClient.post(
        ApiEndpoints.registerDevice,
        data: {'token': token, 'platform': platform},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to register FCM token: $e');
    }
  }

  /// Unregister device token
  Future<void> unregisterToken() async {
    try {
      final token = await getToken();
      if (token != null) {
        await _apiClient.delete(
          ApiEndpoints.unregisterDevice,
          data: {'token': token},
        );
      }
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
