import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';

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

  // TODO: Initialize Firebase when GoogleService-Info.plist is added
  // await Firebase.initializeApp();
  // await PushNotificationService().initialize();

  runApp(const ProviderScope(child: GeolocApp()));
}
