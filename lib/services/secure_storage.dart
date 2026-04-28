import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Singleton [FlutterSecureStorage] with platform-hardened options.
///
/// - **iOS**: keychain accessibility set to `first_unlock_this_device` so
///   secrets are bound to this device and unavailable before first unlock.
/// - **Android**: encrypted shared preferences enabled (`EncryptedSharedPreferences`).
///
/// Always import and use this single instance instead of constructing a
/// `FlutterSecureStorage()` directly so iOS/Android settings stay consistent.
const FlutterSecureStorage secureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
);
