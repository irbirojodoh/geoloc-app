import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failures.dart';
import '../../data/models/location_follow.dart';
import '../../services/location_follow_service.dart';

/// In-memory followed locations. Prefixes are never written to disk.
class FollowedLocationsState {
  final List<LocationFollow> locations;
  final bool isLoading;
  final bool hasFetched;
  final String? error;

  const FollowedLocationsState({
    this.locations = const [],
    this.isLoading = false,
    this.hasFetched = false,
    this.error,
  });

  FollowedLocationsState copyWith({
    List<LocationFollow>? locations,
    bool? isLoading,
    bool? hasFetched,
    String? error,
    bool clearError = false,
  }) {
    return FollowedLocationsState(
      locations: locations ?? this.locations,
      isLoading: isLoading ?? this.isLoading,
      hasFetched: hasFetched ?? this.hasFetched,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// True when [prefix] is in the latest server list (exact match only).
  bool isFollowedPrefix(String prefix) {
    return locations.any((item) => item.geohashPrefix == prefix);
  }
}

final followedLocationsProvider =
    StateNotifierProvider<FollowedLocationsNotifier, FollowedLocationsState>((
      ref,
    ) {
      return FollowedLocationsNotifier(ref.watch(locationFollowServiceProvider));
    });

/// Loads followed locations from the server and unfollows using that list.
///
/// Does not persist `geohash_prefix`. Client-computed hashes are not used
/// for "is this followed?" or for the unfollow path param.
class FollowedLocationsNotifier extends StateNotifier<FollowedLocationsState> {
  FollowedLocationsNotifier(this._api) : super(const FollowedLocationsState());

  final LocationFollowApi _api;

  /// Refetch `GET /locations/following`. Call after the geohash-v6 migration
  /// and before any unfollow so path params are server-owned 6-char prefixes.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final locations = await _api.getFollowing();
      state = state.copyWith(
        locations: locations,
        isLoading: false,
        hasFetched: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _message(e),
      );
    }
  }

  /// Unfollow using the prefix from the most recent GET. Returns false and
  /// does **not** call DELETE when [geohashPrefix] is absent from that list
  /// (avoids the silent 200-on-stale-5-char-prefix failure).
  Future<bool> unfollow(String geohashPrefix) async {
    if (!state.hasFetched) {
      await refresh();
    }

    var match = _matchOnServerList(geohashPrefix);
    if (match == null) {
      await refresh();
      match = _matchOnServerList(geohashPrefix);
    }
    if (match == null) return false;

    try {
      await _api.unfollow(match.geohashPrefix);
      state = state.copyWith(
        locations: state.locations
            .where((item) => item.geohashPrefix != match!.geohashPrefix)
            .toList(),
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: _message(e));
      return false;
    }
  }

  Future<LocationFollow?> follow({
    required double latitude,
    required double longitude,
    String? name,
  }) async {
    try {
      final created = await _api.follow(
        latitude: latitude,
        longitude: longitude,
        name: name,
      );
      final withoutDup = state.locations
          .where((item) => item.geohashPrefix != created.geohashPrefix)
          .toList();
      state = state.copyWith(
        locations: [created, ...withoutDup],
        hasFetched: true,
        clearError: true,
      );
      return created;
    } catch (e) {
      state = state.copyWith(error: _message(e));
      return null;
    }
  }

  LocationFollow? _matchOnServerList(String geohashPrefix) {
    for (final item in state.locations) {
      if (item.geohashPrefix == geohashPrefix) return item;
    }
    return null;
  }

  void clear() {
    state = const FollowedLocationsState();
  }

  String _message(Object e) {
    if (e is Failure) return e.message;
    return e.toString();
  }
}
