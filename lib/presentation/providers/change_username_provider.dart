import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/username.dart';
import '../../data/models/username.dart';
import '../../services/username_service.dart';
import 'auth_provider.dart';

enum UsernameAvailabilityStatus { idle, checking, available, unavailable }

class ChangeUsernameState {
  final bool isLoadingHistory;
  final String? loadError;
  final String currentUsername;
  final DateTime? lastChangedAt;
  final DateTime? nextChangeAt;
  final List<UsernameHistoryEntry> history;

  final String candidate;
  final String? formatError;
  final UsernameAvailabilityStatus availabilityStatus;
  final String? availabilityReason;

  final bool isSubmitting;
  final String? submitError;
  final bool submitSuccess;

  const ChangeUsernameState({
    this.isLoadingHistory = false,
    this.loadError,
    this.currentUsername = '',
    this.lastChangedAt,
    this.nextChangeAt,
    this.history = const [],
    this.candidate = '',
    this.formatError,
    this.availabilityStatus = UsernameAvailabilityStatus.idle,
    this.availabilityReason,
    this.isSubmitting = false,
    this.submitError,
    this.submitSuccess = false,
  });

  /// True when the server says the next rename is still in the future.
  /// Missing [nextChangeAt] means the user has never renamed — change is allowed.
  bool get isOnCooldown {
    final at = nextChangeAt;
    if (at == null) return false;
    return at.isAfter(DateTime.now());
  }

  bool get canSubmit =>
      !isOnCooldown &&
      !isLoadingHistory &&
      !isSubmitting &&
      formatError == null &&
      candidate.isNotEmpty &&
      !_isSameAsCurrent &&
      availabilityStatus == UsernameAvailabilityStatus.available;

  bool get _isSameAsCurrent =>
      candidate.toLowerCase() == currentUsername.toLowerCase();

  ChangeUsernameState copyWith({
    bool? isLoadingHistory,
    String? loadError,
    bool clearLoadError = false,
    String? currentUsername,
    DateTime? lastChangedAt,
    DateTime? nextChangeAt,
    bool clearNextChangeAt = false,
    List<UsernameHistoryEntry>? history,
    String? candidate,
    String? formatError,
    bool clearFormatError = false,
    UsernameAvailabilityStatus? availabilityStatus,
    String? availabilityReason,
    bool clearAvailabilityReason = false,
    bool? isSubmitting,
    String? submitError,
    bool clearSubmitError = false,
    bool? submitSuccess,
  }) {
    return ChangeUsernameState(
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      currentUsername: currentUsername ?? this.currentUsername,
      lastChangedAt: lastChangedAt ?? this.lastChangedAt,
      nextChangeAt:
          clearNextChangeAt ? null : (nextChangeAt ?? this.nextChangeAt),
      history: history ?? this.history,
      candidate: candidate ?? this.candidate,
      formatError: clearFormatError ? null : (formatError ?? this.formatError),
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      availabilityReason: clearAvailabilityReason
          ? null
          : (availabilityReason ?? this.availabilityReason),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      submitSuccess: submitSuccess ?? this.submitSuccess,
    );
  }
}

final changeUsernameProvider = StateNotifierProvider.autoDispose<
    ChangeUsernameNotifier, ChangeUsernameState>((ref) {
  final current = ref.read(currentUserProvider)?.username ?? '';
  final notifier = ChangeUsernameNotifier(
    ref.watch(usernameServiceProvider),
    currentUsername: current,
  );
  notifier.loadHistory();
  return notifier;
});

class ChangeUsernameNotifier extends StateNotifier<ChangeUsernameState> {
  ChangeUsernameNotifier(
    this._api, {
    required String currentUsername,
  }) : super(ChangeUsernameState(currentUsername: currentUsername));

  final UsernameApi _api;

  Timer? _debounce;
  CancelToken? _availabilityToken;

  @override
  void dispose() {
    _debounce?.cancel();
    _availabilityToken?.cancel();
    super.dispose();
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoadingHistory: true, clearLoadError: true);
    try {
      final history = await _api.getHistory();
      final username = history.username.isNotEmpty
          ? history.username
          : state.currentUsername;
      state = state.copyWith(
        isLoadingHistory: false,
        currentUsername: username,
        lastChangedAt: history.lastChangedAt,
        nextChangeAt: history.nextChangeAt,
        clearNextChangeAt: history.nextChangeAt == null,
        history: history.historyNewestFirst,
        candidate: state.candidate.isEmpty ? username : state.candidate,
      );
    } on Failure catch (e) {
      state = state.copyWith(
        isLoadingHistory: false,
        loadError: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingHistory: false,
        loadError: 'Could not load username details',
      );
    }
  }

  /// Update the candidate as the user types. Lowercasing is applied by the
  /// caller (and again here as a safeguard). Debounces availability by
  /// [AppConfig.searchDebounce] and cancels any in-flight check.
  void onCandidateChanged(String raw) {
    final candidate = normalizeUsernameInput(raw);
    final formatError = candidate.isEmpty
        ? null
        : validateUsernameFormat(normalizeUsername(candidate));
    final sameAsCurrent =
        candidate.toLowerCase() == state.currentUsername.toLowerCase();

    state = state.copyWith(
      candidate: candidate,
      formatError: formatError,
      clearFormatError: formatError == null,
      availabilityStatus: UsernameAvailabilityStatus.idle,
      clearAvailabilityReason: true,
      clearSubmitError: true,
    );

    _debounce?.cancel();
    _availabilityToken?.cancel();
    _availabilityToken = null;

    if (state.isOnCooldown) return;
    if (formatError != null || candidate.isEmpty || sameAsCurrent) return;

    _debounce = Timer(AppConfig.searchDebounce, () {
      unawaited(_checkAvailability(candidate));
    });
  }

  Future<void> _checkAvailability(String username) async {
    // Input changed again before we ran.
    if (state.candidate != username) return;

    final token = CancelToken();
    _availabilityToken = token;
    state = state.copyWith(
      availabilityStatus: UsernameAvailabilityStatus.checking,
      clearAvailabilityReason: true,
    );

    try {
      final result = await _api.checkAvailability(
        username,
        cancelToken: token,
      );
      if (token.isCancelled || state.candidate != username) return;

      if (result.available) {
        state = state.copyWith(
          availabilityStatus: UsernameAvailabilityStatus.available,
          clearAvailabilityReason: true,
        );
      } else {
        state = state.copyWith(
          availabilityStatus: UsernameAvailabilityStatus.unavailable,
          availabilityReason: result.unavailableMessage,
        );
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      if (state.candidate != username) return;
      state = state.copyWith(
        availabilityStatus: UsernameAvailabilityStatus.idle,
        clearAvailabilityReason: true,
      );
    } catch (_) {
      if (token.isCancelled || state.candidate != username) return;
      state = state.copyWith(
        availabilityStatus: UsernameAvailabilityStatus.idle,
        clearAvailabilityReason: true,
      );
    }
  }

  Future<UsernameChangeResult?> submit() async {
    if (!state.canSubmit) return null;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);
    try {
      final result = await _api.changeUsername(state.candidate);
      state = state.copyWith(
        isSubmitting: false,
        submitSuccess: true,
        currentUsername: result.username,
        nextChangeAt: result.nextChangeAt,
        lastChangedAt: DateTime.now().toUtc(),
      );
      return result;
    } on UsernameCooldownFailure catch (e) {
      // Cached cooldown was stale — lock the form using the server timestamps.
      _debounce?.cancel();
      _availabilityToken?.cancel();
      state = state.copyWith(
        isSubmitting: false,
        nextChangeAt: e.nextChangeAt,
        lastChangedAt: e.lastChangedAt,
        candidate: state.currentUsername,
        clearSubmitError: true,
        availabilityStatus: UsernameAvailabilityStatus.idle,
        clearAvailabilityReason: true,
      );
      return null;
    } on UsernameTakenFailure catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: e.message,
        availabilityStatus: UsernameAvailabilityStatus.unavailable,
        availabilityReason: e.message,
      );
      return null;
    } on Failure catch (e) {
      state = state.copyWith(isSubmitting: false, submitError: e.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: 'Could not change username',
      );
      return null;
    }
  }

  /// Skip debounce so error-path tests can reach [submit] without a timer.
  @visibleForTesting
  void debugSetReadyToSubmit(String candidate) {
    state = state.copyWith(
      candidate: candidate,
      formatError: validateUsernameFormat(candidate),
      clearFormatError: validateUsernameFormat(candidate) == null,
      availabilityStatus: UsernameAvailabilityStatus.available,
      clearAvailabilityReason: true,
      clearSubmitError: true,
    );
  }
}
