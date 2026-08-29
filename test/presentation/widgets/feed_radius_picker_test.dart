import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/config/app_config.dart';
import 'package:geoloc_app/presentation/widgets/feed_radius_picker.dart';

void main() {
  testWidgets('radius picker only offers values at or below 15 km', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFeedRadiusPicker(
                context: context,
                selectedKm: 5,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    for (final option in AppConfig.feedRadiusOptionsKm) {
      expect(find.text(AppConfig.formatFeedRadiusKm(option)), findsOneWidget);
      expect(option, lessThanOrEqualTo(15));
    }
    expect(find.text('25 km'), findsNothing);
    expect(find.text('50 km'), findsNothing);
    expect(find.textContaining('Maximum 15 km'), findsOneWidget);
  });

  testWidgets('selecting 15 km returns the clamped server maximum', (tester) async {
    double? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showFeedRadiusPicker(
                  context: context,
                  selectedKm: 50,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 km'));
    await tester.pumpAndSettle();

    expect(picked, 15);
  });
}
