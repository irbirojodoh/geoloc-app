import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/presentation/widgets/icon_square_button.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('renders the supplied icon', (tester) async {
    await tester.pumpWidget(host(
      IconSquareButton(icon: Icons.bookmark, onTap: () {}),
    ));
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });

  testWidgets('fires onTap when tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      IconSquareButton(icon: Icons.add, onTap: () => taps++),
    ));
    await tester.tap(find.byType(IconSquareButton));
    expect(taps, 1);
  });

  testWidgets('exposes a 44pt minimum tap target by default', (tester) async {
    await tester.pumpWidget(host(
      IconSquareButton(icon: Icons.add, onTap: () {}),
    ));
    final size = tester.getSize(find.byType(IconSquareButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('publishes a Semantics label when provided', (tester) async {
    await tester.pumpWidget(host(
      IconSquareButton(
        icon: Icons.notifications,
        semanticLabel: 'Notifications',
        onTap: () {},
      ),
    ));
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
  });

  testWidgets('disables ripple when onTap is null', (tester) async {
    await tester.pumpWidget(host(
      const IconSquareButton(icon: Icons.add, onTap: null),
    ));
    // No exception when tapping a disabled button.
    await tester.tap(find.byType(IconSquareButton), warnIfMissed: false);
  });
}
