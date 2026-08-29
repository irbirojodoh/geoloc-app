import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/data/models/user.dart';
import 'package:geoloc_app/data/models/username.dart';
import 'package:geoloc_app/presentation/providers/auth_provider.dart';
import 'package:geoloc_app/presentation/screens/settings/change_username_screen.dart';
import 'package:geoloc_app/services/username_service.dart';

import '../../../helpers/fake_username_api.dart';

void main() {
  testWidgets('cooldown blocks the form and shows the next-change date',
      (tester) async {
    final fake = FakeUsernameApi()
      ..history = UsernameHistory(
        username: 'old_handle',
        lastChangedAt: DateTime.utc(2026, 8, 28, 12),
        nextChangeAt: DateTime.utc(2099, 10, 28, 12),
        history: [
          UsernameHistoryEntry(
            oldUsername: 'ancient',
            newUsername: 'old_handle',
            changedAt: DateTime.utc(2026, 8, 28, 12),
          ),
        ],
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          usernameServiceProvider.overrideWithValue(fake),
          currentUserProvider.overrideWith(
            (ref) => const User(
              id: 'u1',
              username: 'old_handle',
              email: 'a@b.c',
            ),
          ),
        ],
        child: const MaterialApp(home: ChangeUsernameScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('You can change your username again on'),
      findsOneWidget,
    );

    final field = tester.widget<TextField>(
      find.byKey(const Key('change_username_field')),
    );
    expect(field.enabled, isFalse);

    expect(find.text('Change username'), findsNothing);
    expect(find.textContaining('was @ancient until'), findsOneWidget);
    expect(
      find.textContaining('Previous usernames stay reserved'),
      findsOneWidget,
    );
  });
}
