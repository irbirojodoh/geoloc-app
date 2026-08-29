import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/errors/failures.dart';
import 'package:geoloc_app/data/models/username.dart';
import 'package:geoloc_app/presentation/providers/change_username_provider.dart';

import '../../helpers/fake_username_api.dart';

void main() {
  group('availability debounce and cancel', () {
    test('debounces ~400ms and skips invalid or current handles', () {
      fakeAsync((async) {
        final fake = FakeUsernameApi();
        final notifier = ChangeUsernameNotifier(fake, currentUsername: 'me');

        notifier.onCandidateChanged('ab');
        async.elapse(const Duration(milliseconds: 500));
        expect(fake.availabilityCalls, 0);

        notifier.onCandidateChanged('me');
        async.elapse(const Duration(milliseconds: 500));
        expect(fake.availabilityCalls, 0);

        notifier.onCandidateChanged('hello');
        async.elapse(const Duration(milliseconds: 200));
        expect(fake.availabilityCalls, 0);

        async.elapse(const Duration(milliseconds: 200));
        expect(fake.availabilityCalls, 1);
        expect(fake.availabilityUsernames, ['hello']);
      });
    });

    test('cancels in-flight availability when input changes', () {
      fakeAsync((async) {
        final fake = FakeUsernameApi()
          ..holdAvailability = Completer<UsernameAvailability>();
        final notifier = ChangeUsernameNotifier(fake, currentUsername: 'me');

        notifier.onCandidateChanged('hello');
        async.elapse(const Duration(milliseconds: 400));
        expect(fake.availabilityCalls, 1);
        expect(fake.tokens.first.isCancelled, isFalse);

        notifier.onCandidateChanged('helloworld');
        expect(fake.tokens.first.isCancelled, isTrue);

        async.elapse(const Duration(milliseconds: 400));
        expect(fake.availabilityCalls, 2);
        expect(fake.availabilityUsernames, ['hello', 'helloworld']);
      });
    });
  });

  group('submit error paths', () {
    test('409 keeps the typed candidate and sets an inline field error',
        () async {
      final fake = FakeUsernameApi()
        ..changeThrow = const UsernameTakenFailure();
      final notifier = ChangeUsernameNotifier(fake, currentUsername: 'me');
      await notifier.loadHistory();
      notifier.debugSetReadyToSubmit('taken_name');

      final result = await notifier.submit();

      expect(result, isNull);
      expect(notifier.state.candidate, 'taken_name');
      expect(notifier.state.submitError, contains('taken'));
      expect(notifier.state.isOnCooldown, isFalse);
      expect(
        notifier.state.availabilityStatus,
        UsernameAvailabilityStatus.unavailable,
      );
    });

    test('429 re-renders cooldown from next_change_at', () async {
      final next = DateTime.utc(2099, 10, 28, 12);
      final fake = FakeUsernameApi()
        ..changeThrow = UsernameCooldownFailure(nextChangeAt: next);
      final notifier = ChangeUsernameNotifier(fake, currentUsername: 'me');
      await notifier.loadHistory();
      notifier.debugSetReadyToSubmit('new_handle');

      final result = await notifier.submit();

      expect(result, isNull);
      expect(notifier.state.isOnCooldown, isTrue);
      expect(notifier.state.nextChangeAt, next);
      expect(notifier.state.submitError, isNull);
      expect(notifier.state.candidate, 'me');
    });
  });
}
