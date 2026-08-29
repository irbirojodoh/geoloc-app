import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/presentation/widgets/post_location_label.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 180, child: child),
        ),
      );

  testWidgets('ellipsizes long street-level names on two lines', (tester) async {
    const longName =
        'Jalan Teuku Cik Ditiro, Gondangdia, Menteng, Jakarta Pusat, Daerah Khusus Ibukota Jakarta';
    await tester.pumpWidget(
      host(
        const PostLocationLabel(
          label: longName,
          verified: true,
        ),
      ),
    );

    final text = tester.widget<Text>(find.text(longName));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified check sits immediately to the right of the location',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: PostLocationLabel(
              label: 'Menteng',
              verified: true,
            ),
          ),
        ),
      ),
    );

    final textRight = tester.getRect(find.text('Menteng')).right;
    final checkLeft = tester.getRect(find.byIcon(Icons.check_circle)).left;
    expect(checkLeft, greaterThan(textRight));
    expect(checkLeft - textRight, lessThan(12));

    final textColor = tester.widget<Text>(find.text('Menteng')).style?.color;
    final checkColor = tester.widget<Icon>(find.byIcon(Icons.check_circle)).color;
    expect(checkColor, textColor);
  });

  testWidgets('callout variant is single-line for map pins', (tester) async {
    const longName =
        'Jalan Teuku Cik Ditiro, Gondangdia, Menteng, Jakarta Pusat';
    await tester.pumpWidget(
      host(const PostLocationLabel.callout(label: longName)),
    );

    final text = tester.widget<Text>(find.text(longName));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
