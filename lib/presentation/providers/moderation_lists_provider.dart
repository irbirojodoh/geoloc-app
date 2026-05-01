import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user.dart';
import '../../services/moderation_service.dart';

final blockedUsersListProvider =
    FutureProvider.autoDispose<List<User>>((ref) async {
  return ref.read(moderationServiceProvider).fetchBlockedUsers();
});

final mutedUsersListProvider =
    FutureProvider.autoDispose<List<User>>((ref) async {
  return ref.read(moderationServiceProvider).fetchMutedUsers();
});
