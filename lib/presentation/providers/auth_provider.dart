import 'dart:io';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/errors/failures.dart';
import '../../../data/models/user.dart';
import '../../../services/auth_service.dart';
import '../../../services/dm_service.dart';
import '../../../core/logging/app_logger.dart';

/// Auth state
class AuthState {
  final User? user;
  final bool isLoading;
  final bool isAuthenticated;
  final bool isNewUser;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.isNewUser = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isAuthenticated,
    bool? isNewUser,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isNewUser: isNewUser ?? this.isNewUser,
      error: error,
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
  /// 1. Launches the native Google Sign-In flow
  /// 2. Extracts the ID token from the authentication result
  /// 3. Sends it to the backend at POST /auth/google/token
  /// 4. Updates auth state with the result (including isNewUser flag)
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();

      if (account == null) {
        // User cancelled the sign-in
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

      final authResponse = await _authService.signInWithGoogleToken(idToken);
      state = AuthState.authenticated(
        authResponse.user,
        isNewUser: authResponse.isNewUser,
      );
      unawaited(_dmService.ensureKeysUploaded());
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Sign in with Apple using native SDK
  ///
  /// 1. Launches the native Apple Sign-In sheet
  /// 2. Extracts the identity token and (on first login) the user's name
  /// 3. Sends it to the backend at POST /auth/apple/token
  /// 4. Updates auth state with the result (including isNewUser flag)
  Future<bool> signInWithApple() async {
    // Apple Sign-In is only available on iOS/macOS
    if (!Platform.isIOS && !Platform.isMacOS) {
      state = state.copyWith(
        isLoading: false,
        error: 'Apple Sign-In is only available on Apple devices',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
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
        return false;
      }

      // Apple only provides the name on the FIRST sign-in ever.
      // Capture it here and pass to the backend; never overwrite with empty later.
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

      final authResponse = await _authService.signInWithAppleToken(
        idToken,
        fullName: fullName,
      );
      state = AuthState.authenticated(
        authResponse.user,
        isNewUser: authResponse.isNewUser,
      );
      unawaited(_dmService.ensureKeysUploaded());
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      // User dismissed the sheet — not an error state.
      if (e.code == AuthorizationErrorCode.canceled) {
        state = state.copyWith(isLoading: false, error: null);
        return false;
      }
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _dmService.clearLocalData();
    await _authService.logout();
    state = AuthState.unauthenticated();
  }

  /// Update current user
  void updateUser(User user) {
    state = state.copyWith(user: user);
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
