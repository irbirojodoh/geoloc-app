import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../services/search_service.dart';
import 'location_provider.dart';

/// Search tab enum
enum SearchTab { users, posts }

/// Search state
class SearchState {
  final String query;
  final SearchTab activeTab;
  final List<User> userResults;
  final List<Post> postResults;
  final List<String> recentSearches;
  final List<String> autocompleteUsers;
  final List<String> autocompleteHashtags;
  final bool isLoading;
  final bool hasSearched;
  final String? error;

  const SearchState({
    this.query = '',
    this.activeTab = SearchTab.users,
    this.userResults = const [],
    this.postResults = const [],
    this.recentSearches = const [],
    this.autocompleteUsers = const [],
    this.autocompleteHashtags = const [],
    this.isLoading = false,
    this.hasSearched = false,
    this.error,
  });

  bool get hasResults =>
      activeTab == SearchTab.users
          ? userResults.isNotEmpty
          : postResults.isNotEmpty;

  bool get showEmptyState => hasSearched && !isLoading && !hasResults;

  SearchState copyWith({
    String? query,
    SearchTab? activeTab,
    List<User>? userResults,
    List<Post>? postResults,
    List<String>? recentSearches,
    List<String>? autocompleteUsers,
    List<String>? autocompleteHashtags,
    bool? isLoading,
    bool? hasSearched,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      query: query ?? this.query,
      activeTab: activeTab ?? this.activeTab,
      userResults: userResults ?? this.userResults,
      postResults: postResults ?? this.postResults,
      recentSearches: recentSearches ?? this.recentSearches,
      autocompleteUsers: autocompleteUsers ?? this.autocompleteUsers,
      autocompleteHashtags: autocompleteHashtags ?? this.autocompleteHashtags,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Search provider
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.watch(searchServiceProvider), ref);
});

/// Search state notifier
class SearchNotifier extends StateNotifier<SearchState> {
  final SearchService _searchService;
  final Ref _ref;
  Timer? _debounceTimer;
  static const String _recentSearchesBoxKey = 'recent_searches';
  static const int _maxRecentSearches = 10;

  SearchNotifier(this._searchService, this._ref) : super(const SearchState()) {
    _loadRecentSearches();
  }

  /// Load recent searches from Hive
  Future<void> _loadRecentSearches() async {
    try {
      final box = await Hive.openBox<String>(_recentSearchesBoxKey);
      final searches = box.values.toList();
      state = state.copyWith(recentSearches: searches.reversed.toList());
    } catch (_) {
      // Hive not initialized or box not available
    }
  }

  /// Search with debounce
  void search(String query) {
    state = state.copyWith(query: query, clearError: true);

    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      state = state.copyWith(
        userResults: [],
        postResults: [],
        autocompleteUsers: [],
        autocompleteHashtags: [],
        hasSearched: false,
        isLoading: false,
      );
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  /// Execute the actual search
  Future<void> _executeSearch(String query) async {
    state = state.copyWith(isLoading: true);

    try {
      final locationState = _ref.read(locationStateProvider);
      final hasLocation =
          locationState.hasLocation &&
          locationState.latitude != null &&
          locationState.longitude != null;

      final searchFuture = hasLocation
          ? _searchService.searchNearby(
              query,
              lat: locationState.latitude!,
              lon: locationState.longitude!,
            )
          : _searchService.searchGlobal(query);

      final results = await Future.wait<dynamic>([
        searchFuture,
        _searchService.autocomplete(query),
      ]);
      final searchResponse = results[0] as SearchResponse;
      final autocompleteResponse = results[1] as AutocompleteResponse;

      state = state.copyWith(
        userResults: searchResponse.users,
        postResults: searchResponse.posts,
        autocompleteUsers: autocompleteResponse.users,
        autocompleteHashtags: autocompleteResponse.hashtags,
        isLoading: false,
        hasSearched: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasSearched: true,
        error: 'Search failed: $e',
      );
    }
  }

  /// Set active tab
  void setActiveTab(SearchTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  /// Clear search
  void clearSearch() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      query: '',
      userResults: [],
      postResults: [],
      autocompleteUsers: [],
      autocompleteHashtags: [],
      hasSearched: false,
      isLoading: false,
      clearError: true,
    );
  }

  /// Add a search query to recent searches
  Future<void> addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    try {
      final box = await Hive.openBox<String>(_recentSearchesBoxKey);

      // Remove if already exists
      final existingIndex = state.recentSearches.indexOf(query);
      if (existingIndex != -1) {
        await box.deleteAt(
          state.recentSearches.length - 1 - existingIndex,
        );
      }

      // Add to end (most recent)
      await box.add(query);

      // Keep only max items
      while (box.length > _maxRecentSearches) {
        await box.deleteAt(0);
      }

      await _loadRecentSearches();
    } catch (_) {
      // Ignore storage errors
    }
  }

  /// Remove a recent search
  Future<void> removeRecentSearch(String query) async {
    try {
      final box = await Hive.openBox<String>(_recentSearchesBoxKey);
      final index = state.recentSearches.indexOf(query);
      if (index != -1) {
        await box.deleteAt(state.recentSearches.length - 1 - index);
        await _loadRecentSearches();
      }
    } catch (_) {
      // Ignore storage errors
    }
  }

  /// Clear all recent searches
  Future<void> clearRecentSearches() async {
    try {
      final box = await Hive.openBox<String>(_recentSearchesBoxKey);
      await box.clear();
      state = state.copyWith(recentSearches: []);
    } catch (_) {
      // Ignore storage errors
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
