import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../data/models/user.dart';
import '../../../services/auth_service.dart';

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
  return AuthNotifier(ref.watch(authServiceProvider));
});

/// Current user provider (convenience)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).user;
});

/// Auth notifier for managing authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState.initial()) {
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
      final user = await _authService.login(email: email, password: password);
      state = AuthState.authenticated(user);
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
      if (idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to get Apple identity token',
        );
        return false;
      }

      // Apple only provides the name on the FIRST sign-in ever.
      // Capture it here and pass to the backend.
      String? fullName;
      final givenName = credential.givenName;
      final familyName = credential.familyName;
      if (givenName != null || familyName != null) {
        fullName =
            [givenName, familyName].where((s) => s != null && s.isNotEmpty).join(
              ' ',
            );
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
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
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
    String? profilePictureUrl,
    String? coverImageUrl,
  }) async {
    if (state.user == null) return false;

    try {
      // Build update data
      final updateData = <String, dynamic>{};
      if (fullName != null) updateData['full_name'] = fullName;
      if (username != null) updateData['username'] = username;
      if (bio != null) updateData['bio'] = bio;
      if (profilePictureUrl != null) {
        updateData['profile_picture_url'] = profilePictureUrl;
      }
      if (coverImageUrl != null) {
        updateData['cover_image_url'] = coverImageUrl;
      }

      if (updateData.isEmpty) return true;

      // Call API to update profile
      await _authService.updateProfile(updateData);

      // Update local user state
      final updatedUser = state.user!.copyWith(
        fullName: fullName ?? state.user!.fullName,
        username: username ?? state.user!.username,
        bio: bio ?? state.user!.bio,
        profilePictureUrl: profilePictureUrl ?? state.user!.profilePictureUrl,
        coverImageUrl: coverImageUrl ?? state.user!.coverImageUrl,
      );
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
}
