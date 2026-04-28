import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../../services/search_service.dart';

/// Search tab enum
enum SearchTab { users, posts }

/// Search state
class SearchState {
  final String query;
  final SearchTab activeTab;
  final List<User> userResults;
  final List<Post> postResults;
  final List<String> recentSearches;
  final List<User> suggestedUsers;
  final bool isLoading;
  final bool hasSearched;
  final String? error;

  const SearchState({
    this.query = '',
    this.activeTab = SearchTab.users,
    this.userResults = const [],
    this.postResults = const [],
    this.recentSearches = const [],
    this.suggestedUsers = const [],
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
    List<User>? suggestedUsers,
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
      suggestedUsers: suggestedUsers ?? this.suggestedUsers,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Search provider
final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.watch(searchServiceProvider));
});

/// Search state notifier
class SearchNotifier extends StateNotifier<SearchState> {
  final SearchService _searchService;
  Timer? _debounceTimer;
  static const String _recentSearchesBoxKey = 'recent_searches';
  static const int _maxRecentSearches = 10;

  SearchNotifier(this._searchService) : super(const SearchState()) {
    _loadRecentSearches();
    _loadSuggestedUsers();
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

  /// Load suggested users
  Future<void> _loadSuggestedUsers() async {
    try {
      final users = await _searchService.getSuggestedUsers();
      state = state.copyWith(suggestedUsers: users);
    } catch (_) {
      // Ignore errors for suggestions
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
      // Search both users and posts
      final results = await Future.wait([
        _searchService.searchUsers(query),
        _searchService.searchPosts(query),
      ]);

      state = state.copyWith(
        userResults: results[0] as List<User>,
        postResults: results[1] as List<Post>,
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

  /// Reload suggested users
  Future<void> refreshSuggestions() async {
    await _loadSuggestedUsers();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
