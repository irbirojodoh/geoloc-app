import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/presentation/widgets/swipe_back_page.dart';

Widget _slide(Animation<double> animation, Widget child) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(animation),
    child: child,
  );
}

SwipeBackPage<void> _page(Widget child, {LocalKey? key}) {
  return SwipeBackPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondary, widget) =>
        _slide(animation, widget),
  );
}

void main() {
  testWidgets('edge swipe pops a pushed SwipeBackPage', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  _page(const Scaffold(body: Text('detail'))).createRoute(context),
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
    expect(find.text('detail'), findsOneWidget);

    final gesture = await tester.startGesture(const Offset(8, 400));
    await gesture.moveBy(const Offset(280, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('edge swipe does not pop the first route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onDidRemovePage: (_) {},
          pages: [
            _page(
              const Scaffold(body: Text('root')),
              key: const ValueKey('root'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(8, 400));
    await gesture.moveBy(const Offset(280, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('root'), findsOneWidget);
  });
}
