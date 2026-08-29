import 'dart:async';

import 'package:dio/dio.dart';
import 'package:geoloc_app/data/models/username.dart';
import 'package:geoloc_app/services/username_service.dart';

class FakeUsernameApi implements UsernameApi {
  UsernameHistory history = const UsernameHistory(username: 'me');
  UsernameAvailability Function(String username)? availabilityFor;
  Object? changeThrow;
  UsernameChangeResult? changeResult;

  int availabilityCalls = 0;
  final List<String> availabilityUsernames = [];
  final List<CancelToken> tokens = [];
  Completer<UsernameAvailability>? holdAvailability;

  @override
  Future<UsernameAvailability> checkAvailability(
    String username, {
    CancelToken? cancelToken,
  }) async {
    availabilityCalls++;
    availabilityUsernames.add(username);
    if (cancelToken != null) tokens.add(cancelToken);

    final held = holdAvailability;
    if (held != null) {
      return held.future;
    }

    if (availabilityFor != null) {
      return availabilityFor!(username);
    }
    return UsernameAvailability(username: username, available: true);
  }

  @override
  Future<UsernameChangeResult> changeUsername(String username) async {
    final error = changeThrow;
    if (error != null) {
      throw error;
    }
    return changeResult ??
        UsernameChangeResult(
          message: 'Username updated',
          username: username,
          previousUsername: 'me',
          nextChangeAt: DateTime.utc(2026, 10, 28),
        );
  }

  @override
  Future<UsernameHistory> getHistory({int limit = 50}) async => history;
}
