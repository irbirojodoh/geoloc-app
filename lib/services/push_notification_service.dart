import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/push_navigation.dart';
import '../core/logging/app_logger.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../firebase_options.dart';

/// Background message handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  AppLogger.debug('Handling a background message: ${message.messageId}');
}

/// Pending cold-start / background open route derived from a push payload.
final pendingPushRouteProvider = StateProvider<String?>((ref) => null);

/// Provider for PushNotificationService
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(
    ref.watch(apiClientProvider),
    onOpened: (data) {
      final route = routeFromPushData(data);
      if (route != null) {
        ref.read(pendingPushRouteProvider.notifier).state = route;
      }
    },
  );
});

/// Push notification service for Firebase Cloud Messaging
class PushNotificationService {
  PushNotificationService(this._apiClient, {this.onOpened});

  final ApiClient _apiClient;
  final void Function(Map<String, dynamic> data)? onOpened;

  FirebaseMessaging? _messagingOrNull() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  /// Register listeners only — does **not** request permission.
  Future<void> setupListeners() async {
    final messaging = _messagingOrNull();
    if (messaging == null) return;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      AppLogger.debug('Foreground FCM message: ${message.messageId}');
    });
  }

  /// @Deprecated Prefer [setupListeners] + [requestPermissionAndRegister].
  Future<void> initialize() => setupListeners();

  void _handleMessage(RemoteMessage message) {
    AppLogger.debug('Push opened with data keys: ${message.data.keys}');
    onOpened?.call(message.data);
  }

  /// Request notification permission and register the device token.
  Future<bool> requestPermissionAndRegister() async {
    final granted = await requestPermission();
    if (!granted) return false;
    final token = await getToken();
    if (token != null) {
      await registerToken(token);
    }
    return true;
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    final messaging = _messagingOrNull();
    if (messaging == null) return false;

    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    AppLogger.debug(
      'User granted permission: ${settings.authorizationStatus}',
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Get FCM device token
  Future<String?> getToken() async {
    try {
      final messaging = _messagingOrNull();
      if (messaging == null) return null;
      return await messaging.getToken();
    } catch (e, st) {
      AppLogger.warning('Failed to get FCM token', e, st);
      return null;
    }
  }

  /// Register device token with backend
  Future<void> registerToken(String token) async {
    try {
      // Ensure permission was granted before registering (no-op if denied).
      await requestPermission();
      final platform = Platform.isIOS ? 'ios' : 'android';
      await _apiClient.post(
        ApiEndpoints.registerDevice,
        data: {'token': token, 'platform': platform},
      );
    } catch (e, st) {
      AppLogger.warning('Failed to register FCM token', e, st);
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
    } catch (e, st) {
      AppLogger.warning('Failed to unregister FCM token', e, st);
    }
  }

  /// Subscribe to a topic (e.g., for location-based notifications)
  Future<void> subscribeToTopic(String topic) async {
    final messaging = _messagingOrNull();
    if (messaging == null) return;
    try {
      await messaging.subscribeToTopic(topic);
    } catch (e, st) {
      AppLogger.warning('Failed to subscribe to topic $topic', e, st);
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    final messaging = _messagingOrNull();
    if (messaging == null) return;
    try {
      await messaging.unsubscribeFromTopic(topic);
    } catch (e, st) {
      AppLogger.warning('Failed to unsubscribe from topic $topic', e, st);
    }
  }
}
