import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Set preferred orientations (portrait only for now)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style — warm-neutral old-money aesthetic
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // For Android: dark icons on warm cream bg
      statusBarBrightness: Brightness.light, // For iOS: light status bar content
    ),
  );

  // Initialize Firebase and Push Notifications
  await Firebase.initializeApp();
  
  // Note: We need a provider container to use the service if not inside a widget,
  // or we can initialize it in GeoloApp's initState. Since we don't have direct access
  // to PushNotificationService without a ref here, let's initialize it in the ProviderScope
  // using a ProviderContainer or inside GeoloApp.
  // Actually, we can just instantiate it directly for the background handler registration
  // or we can handle initialization inside the first screen. Let's create an ad-hoc container:
  final container = ProviderContainer();
  final pushService = container.read(pushNotificationServiceProvider);
  await pushService.initialize();

  runApp(UncontrolledProviderScope(container: container, child: const GeolocApp()));
}
