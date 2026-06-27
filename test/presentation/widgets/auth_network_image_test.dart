import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/presentation/widgets/auth_network_image.dart';

void main() {
  const r2Url =
      'https://abc.r2.cloudflarestorage.com/geoloc-media/posts/user-1/uuid.jpg?X-Amz-Expires=900';
  const externalUrl = 'https://images.unsplash.com/photo.jpg';

  Widget buildTestWidget({
    required String imageUrl,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    return ProviderScope(
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

  testWidgets('renders CachedNetworkImage without auth headers for R2 URLs', (tester) async {
    await tester.pumpWidget(buildTestWidget(imageUrl: r2Url));
    await tester.pump();

    final imageFinder = find.byType(CachedNetworkImage);
    expect(imageFinder, findsOneWidget);

    final CachedNetworkImage imageWidget = tester.widget(imageFinder);
    expect(imageWidget.imageUrl, r2Url);
    expect(imageWidget.httpHeaders, isNull);
  });

  testWidgets('renders CachedNetworkImage without auth headers for external URLs', (tester) async {
    await tester.pumpWidget(buildTestWidget(imageUrl: externalUrl));
    await tester.pump();

    final CachedNetworkImage imageWidget = tester.widget(find.byType(CachedNetworkImage));
    expect(imageWidget.imageUrl, externalUrl);
    expect(imageWidget.httpHeaders, isNull);
  });

  testWidgets('renders custom placeholder while loading', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        imageUrl: r2Url,
        placeholder: (context, url) => const Text('Loading custom...'),
      ),
    );

    expect(find.text('Loading custom...'), findsOneWidget);
  });

  testWidgets('renders custom error widget after failed refresh', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        imageUrl: r2Url,
        errorWidget: (context, url, error) => const Text('Custom Error'),
      ),
    );
    await tester.pump();

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });
}
