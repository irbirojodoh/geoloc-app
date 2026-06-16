import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/presentation/providers/auth_provider.dart';
import 'package:geoloc_app/presentation/widgets/auth_network_image.dart';

void main() {
  const testUrl = 'https://example.com/image.jpg';

  Widget buildTestWidget({
    required String imageUrl,
    required List<Override> overrides,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(
          body: AuthNetworkImage(
            imageUrl: imageUrl,
            placeholder: placeholder,
            errorWidget: errorWidget,
          ),
        ),
      ),
    );
  }

  testWidgets('renders custom placeholder when token is loading', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        imageUrl: testUrl,
        overrides: [
          accessTokenProvider.overrideWith((ref) => Completer<String?>().future),
        ],
        placeholder: (context, url) => const Text('Loading custom...'),
      ),
    );

    expect(find.text('Loading custom...'), findsOneWidget);
  });

  testWidgets('renders CachedNetworkImage with authentication headers when token is loaded', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        imageUrl: testUrl,
        overrides: [
          accessTokenProvider.overrideWith((ref) async => 'my-secure-token'),
        ],
      ),
    );

    // Let the Future resolve and pump the widget
    await tester.pump();

    final imageFinder = find.byType(CachedNetworkImage);
    expect(imageFinder, findsOneWidget);

    final CachedNetworkImage imageWidget = tester.widget(imageFinder);
    expect(imageWidget.imageUrl, testUrl);
    expect(imageWidget.httpHeaders, containsPair('Authorization', 'Bearer my-secure-token'));
  });

  testWidgets('renders CachedNetworkImage with empty headers when token is null (logged out)', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        imageUrl: testUrl,
        overrides: [
          accessTokenProvider.overrideWith((ref) async => null),
        ],
      ),
    );

    // Let the Future resolve and pump
    await tester.pump();

    final imageFinder = find.byType(CachedNetworkImage);
    expect(imageFinder, findsOneWidget);

    final CachedNetworkImage imageWidget = tester.widget(imageFinder);
    expect(imageWidget.imageUrl, testUrl);
    expect(imageWidget.httpHeaders, isNot(contains('Authorization')));
  });

  testWidgets('renders custom error widget when token loading fails', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        imageUrl: testUrl,
        overrides: [
          accessTokenProvider.overrideWith((ref) async => throw Exception('Failed to load token')),
        ],
        errorWidget: (context, url, error) => const Text('Custom Error'),
      ),
    );

    // Let the Future resolve with error
    await tester.pump();

    expect(find.text('Custom Error'), findsOneWidget);
  });
}
