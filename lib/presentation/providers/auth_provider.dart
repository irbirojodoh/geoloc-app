import 'dart:io';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../config/app_config.dart';
import '../../../core/errors/failures.dart';
import '../../../data/models/auth_response.dart';
import '../../../data/models/user.dart';
import '../../../services/auth_service.dart';
import '../../../services/dm_service.dart';
import '../../../core/logging/app_logger.dart';

/// Pending social link when email is already used by another method.
class PendingSocialLink {
  final String provider; // google | apple
  final String idToken;
  final String? fullName;
  final String email;
  final List<String> existingMethods;
  final String attemptingMethod;

  const PendingSocialLink({
    required this.provider,
    required this.idToken,
    required this.email,
    required this.existingMethods,
    required this.attemptingMethod,
    this.fullName,
  });
}

/// Auth state
class AuthState {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  final bool isNewUser;
  final String? error;
  final PendingSocialLink? pendingSocialLink;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.isNewUser = false,
    this.error,
    this.pendingSocialLink,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isAuthenticated,
    bool? isNewUser,
    String? error,
    PendingSocialLink? pendingSocialLink,
    bool clearPendingSocialLink = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isNewUser: isNewUser ?? this.isNewUser,
      error: error,
      pendingSocialLink: clearPendingSocialLink
          ? null
          : (pendingSocialLink ?? this.pendingSocialLink),
    );
  }

  /// Initial loading state
  factory AuthState.initial() => const AuthState(isLoading: true);

  /// Authenticated state
  factory AuthState.authenticated(User user, {bool isNewUser = false}) =>
      AuthState(user: user, isAuthenticated: true, isNewUser: isNewUser);

  /// Unauthenticated state
  factory AuthState.unauthenticated() => const AuthState();

  /// Error state
  factory AuthState.error(String message) => AuthState(error: message);
}

/// Auth state notifier provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authServiceProvider),
    ref.watch(dmServiceProvider),
  );
});

/// Current user provider (convenience)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).user;
});

/// Access token provider (convenience)
final accessTokenProvider = FutureProvider<String?>((ref) async {
  // Watch authStateProvider so that if auth state changes (e.g. login/logout),
  // the token provider will refresh.
  final authState = ref.watch(authStateProvider);
  if (!authState.isAuthenticated) {
    return null;
  }
  return ref.read(authServiceProvider).getAccessToken();
});

/// Auth notifier for managing authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final DmService _dmService;

  AuthNotifier(this._authService, this._dmService) : super(AuthState.initial()) {
    _initializeAuth();
  }

  /// Initialize authentication state on app start
  Future<void> _initializeAuth() async {
    try {
      final isAuthenticated = await _authService.isAuthenticated();

      if (isAuthenticated) {
        final user = await _authService.getCurrentUser();
        if (user != null) {
          state = AuthState.authenticated(user);
          unawaited(_dmService.ensureKeysUploaded());
          return;
        }
      }

      state = AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.unauthenticated();
    }
  }

  /// Register a new user
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _authService.register(
        username: username,
        email: email,
        password: password,
        fullName: fullName,
      );
      state = AuthState.authenticated(user);
      unawaited(_dmService.ensureKeysUploaded(password: password));
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Login with email and password
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authResponse = await _authService.login(email: email, password: password);
      state = AuthState.authenticated(authResponse.user);

      // Automatic E2E Restoration if backup exists and local key is missing
      if (authResponse.keyBackup != null && !(await _dmService.hasLocalIdentity())) {
        try {
          await _dmService.restoreIdentityFromBackup(
            passphrase: password,
            currentUserId: authResponse.user.id,
            backup: authResponse.keyBackup,
          );
        } catch (e) {
          AppLogger.debug('Failed to restore E2E private key on login: $e');
        }
      } else {
        unawaited(_dmService.ensureKeysUploaded(password: password));
      }

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Sign in with Google using native SDK
  ///
  /// Returns true when authenticated. Returns false on cancel/error.
  /// When the email is already used by another method, sets
  /// [AuthState.pendingSocialLink] and returns false so the UI can prompt.
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      clearPendingSocialLink: true,
    );

    try {
      final serverClientId = AppConfig.googleServerClientId;
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
      );
      final account = await googleSignIn.signIn();

      if (account == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to get Google ID token',
        );
        return false;
      }

      return await _completeSocialTokenSignIn(
        provider: 'google',
        idToken: idToken,
        confirmLink: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Sign in with Apple using native SDK.
  ///
  /// Always requests a fresh [SignInWithApple.getAppleIDCredential] — never
  /// reuses a stored/cached Apple identityToken after logout or across attempts.
  Future<bool> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      state = state.copyWith(
        isLoading: false,
        error: 'Apple Sign-In is only available on Apple devices',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      clearPendingSocialLink: true,
    );

    try {
      final apple = await _requestFreshAppleCredential();
      if (apple == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }

      return await _completeSocialTokenSignIn(
        provider: 'apple',
        idToken: apple.idToken,
        fullName: apple.fullName,
        confirmLink: false,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        state = state.copyWith(isLoading: false, error: null);
        return false;
      }
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } on AppleIdentityTokenExpiredFailure catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        clearPendingSocialLink: true,
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Opens the native Apple sheet and returns a fresh identity token.
  /// Returns null if Apple returned no token (caller should abort).
  Future<({String idToken, String? fullName})?> _requestFreshAppleCredential() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        error: 'Apple did not return an identity token',
      );
      return null;
    }

    String? fullName;
    final givenName = credential.givenName;
    final familyName = credential.familyName;
    if ((givenName != null && givenName.isNotEmpty) ||
        (familyName != null && familyName.isNotEmpty)) {
      fullName = [givenName, familyName]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(' ');
      if (fullName.isEmpty) fullName = null;
    }

    return (idToken: idToken, fullName: fullName);
  }

  Future<bool> _completeSocialTokenSignIn({
    required String provider,
    required String idToken,
    String? fullName,
    required bool confirmLink,
  }) async {
    try {
      final AuthResponse authResponse;
      if (provider == 'apple') {
        authResponse = await _authService.signInWithAppleToken(
          idToken,
          fullName: fullName,
          confirmLink: confirmLink,
        );
      } else {
        authResponse = await _authService.signInWithGoogleToken(
          idToken,
          confirmLink: confirmLink,
        );
      }

      state = AuthState.authenticated(
        authResponse.user,
        isNewUser: authResponse.isNewUser,
      );
      unawaited(_dmService.ensureKeysUploaded());
      return true;
    } on EmailInUseFailure catch (e) {
      // For Apple, do not keep the identityToken in memory across the dialog —
      // confirmPendingSocialLink always fetches a fresh credential.
      state = state.copyWith(
        isLoading: false,
        error: null,
        pendingSocialLink: PendingSocialLink(
          provider: provider,
          idToken: provider == 'apple' ? '' : idToken,
          fullName: fullName,
          email: e.email,
          existingMethods: e.existingMethods,
          attemptingMethod: e.attemptingMethod.isNotEmpty
              ? e.attemptingMethod
              : provider,
        ),
      );
      return false;
    } on AppleIdentityTokenExpiredFailure catch (e) {
      // Never retry with the same Apple token — force a new native sheet.
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        clearPendingSocialLink: true,
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// User confirmed linking the pending social provider to the existing account.
  ///
  /// For Apple, always requests a **new** identityToken before calling the API —
  /// never reuses the token stored in [PendingSocialLink] (it may already be expired).
  Future<bool> confirmPendingSocialLink() async {
    final pending = state.pendingSocialLink;
    if (pending == null) return false;

    state = state.copyWith(isLoading: true, error: null);

    if (pending.provider == 'apple') {
      try {
        final apple = await _requestFreshAppleCredential();
        if (apple == null) {
          state = state.copyWith(clearPendingSocialLink: true);
          return false;
        }
        return _completeSocialTokenSignIn(
          provider: 'apple',
          idToken: apple.idToken,
          // Name is only returned on the very first Apple auth; keep prior if any.
          fullName: apple.fullName ?? pending.fullName,
          confirmLink: true,
        );
      } on SignInWithAppleAuthorizationException catch (e) {
        if (e.code == AuthorizationErrorCode.canceled) {
          state = state.copyWith(
            isLoading: false,
            error: null,
            clearPendingSocialLink: true,
          );
          return false;
        }
        state = state.copyWith(
          isLoading: false,
          error: e.message,
          clearPendingSocialLink: true,
        );
        return false;
      }
    }

    return _completeSocialTokenSignIn(
      provider: pending.provider,
      idToken: pending.idToken,
      fullName: pending.fullName,
      confirmLink: true,
    );
  }

  /// User cancelled linking; clears pending state and signs out of Google if needed.
  Future<void> cancelPendingSocialLink() async {
    final pending = state.pendingSocialLink;
    if (pending?.provider == 'google') {
      await _signOutGoogleSilently();
    }
    state = state.copyWith(
      isLoading: false,
      error: null,
      clearPendingSocialLink: true,
    );
  }

  /// Logout — clears JWTs, FCM device registration, DM cache, and any social
  /// leftovers (including in-memory Apple/Google tokens). No backend JWT revoke.
  Future<void> logout() async {
    // Drop pending Apple/Google tokens immediately so nothing can reuse them.
    state = state.copyWith(
      isLoading: false,
      error: null,
      clearPendingSocialLink: true,
    );
    await _clearSocialAuthLeftovers();
    await _dmService.clearLocalData();
    await _authService.logout();
    state = AuthState.unauthenticated();
  }

  /// Drop in-memory pending social tokens and native Google session.
  /// Apple has no client sign-out API; we simply never reuse a cached identityToken.
  Future<void> _clearSocialAuthLeftovers() async {
    await _signOutGoogleSilently();
  }

  Future<void> _signOutGoogleSilently() async {
    try {
      final serverClientId = AppConfig.googleServerClientId;
      await GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
      ).signOut();
    } catch (_) {}
  }

  /// Update current user
  void updateUser(User user) {
    state = state.copyWith(user: user);
  }

  /// Write a new handle onto the cached current user (memory + secure storage).
  Future<void> applyUsername(String username) async {
    final user = state.user;
    if (user == null) return;
    final updated = user.copyWith(username: username);
    await _authService.persistCurrentUser(updated);
    state = state.copyWith(user: updated);
  }

  /// Update profile (for edit profile screen)
  Future<bool> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? avatarKey,
    String? coverKey,
    String? profilePictureUrl,
    String? coverImageUrl,
  }) async {
    if (state.user == null) return false;

    try {
      final updateData = <String, dynamic>{};
      if (fullName != null) updateData['full_name'] = fullName;
      if (username != null) updateData['username'] = username;
      if (bio != null) updateData['bio'] = bio;
      if (avatarKey != null) updateData['avatar_key'] = avatarKey;
      if (coverKey != null) updateData['cover_key'] = coverKey;
      if (profilePictureUrl != null) {
        updateData['profile_picture_url'] = profilePictureUrl;
      }
      if (coverImageUrl != null) {
        updateData['cover_image_url'] = coverImageUrl;
      }

      if (updateData.isEmpty) return true;

      final updatedUser = await _authService.updateProfile(updateData);
      state = state.copyWith(user: updatedUser);

      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear the isNewUser flag (call after onboarding is complete)
  void clearNewUserFlag() {
    state = state.copyWith(isNewUser: false);
  }

  /// Permanently deletes the authenticated account ([password]) then logs out.
  /// Returns **null** on success, or user-facing **error message** otherwise.
  Future<String?> deleteAccountWithPassword(String password) async {
    try {
      await _authService.deleteCurrentUser(password: password);
      await _clearSocialAuthLeftovers();
      await _dmService.clearLocalData();
      await _authService.logout();
      state = AuthState.unauthenticated();
      return null;
    } on Failure catch (f) {
      return f.message;
    } catch (e) {
      return e.toString();
    }
  }
}
