import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/app.dart';
import 'package:geoloc_app/core/bootstrap/app_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GeolocApp builds MaterialApp.router', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Avoid Firebase/native bootstrap during widget tests.
          appBootstrapProvider.overrideWith(
            (ref) async => const AppBootstrapResult(firebaseReady: false),
          ),
        ],
        child: const GeolocApp(),
      ),
    );

    // First frame only — avoid settle (auth/router keep scheduling work).
    await tester.pump();

    expect(find.byType(GeolocApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
