# Authentication Implementation Guide

This guide covers how to set up and configure native Sign In with Apple and Google Sign-In for a Flutter application.

## 1. Google Sign-In Setup

Google Sign-In uses the `google_sign_in` package to obtain an ID token natively, which can then be passed to our backend.

### 1.1 Server/Backend Setup
1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create or select a project
3. Go to **APIs & Services > Credentials**
4. Click **Create Credentials > OAuth client ID**
5. Create a **Web application** client ID (this is needed for your backend to verify the tokens)

### 1.2 iOS Setup
1. In Google Cloud Console, create another OAuth client ID of type **iOS**
2. Enter your app's Bundle ID
3. Download the `GoogleService-Info.plist` file (or copy the generated Client ID and Reverse Client ID)
4. Add `GoogleService-Info.plist` to your Xcode project under `ios/Runner`
5. Open `ios/Runner/Info.plist` and add the custom URL scheme:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Replace with your REVERSED_CLIENT_ID from GoogleService-Info.plist -->
      <string>com.googleusercontent.apps.YOUR-CLIENT-ID-HERE</string>
    </array>
  </dict>
</array>
```

### 1.3 Android Setup
1. In Google Cloud Console, create another OAuth client ID of type **Android**
2. Enter your package name and SHA-1 signing certificate fingerprint
3. No further configuration is required in code if you setup Firebase, otherwise add the Web Client ID to `strings.xml`.

### 1.4 Flutter Implementation
```dart
import 'package:google_sign_in/google_sign_in.dart';

Future<void> signInWithGoogle() async {
  // Pass the WEB client ID here (not iOS/Android client IDs)
  // This tells Google which backend will verify the token
  final googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  
  final account = await googleSignIn.signIn();
  if (account == null) return; // User cancelled
  
  final auth = await account.authentication;
  final idToken = auth.idToken;
  
  // Send idToken to POST /auth/google/token
}
```

---

## 2. Sign In With Apple Setup

Apple Sign-In uses the `sign_in_with_apple` package.

### 2.1 Apple Developer Setup
1. Go to the [Apple Developer Account](https://developer.apple.com/)
2. Go to **Certificates, Identifiers & Profiles > Identifiers**
3. Select your app's App ID
4. Enable the **Sign In with Apple** capability
5. Save and regenerate your provisioning profiles

### 2.2 Xcode Setup
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** target
3. Go to the **Signing & Capabilities** tab
4. Click **+ Capability** and add **Sign In with Apple**

### 2.3 Android Setup (Optional for Apple)
To support Apple Sign-In on Android:
1. Go to Apple Developer Account > Identifiers
2. Create a new **Services ID**
3. Configure it for Sign In with Apple and link it to your primary App ID
4. Define your return URLs (which your backend will handle)
5. Set up a Web API endpoint on your server to handle the Apple redirect
*(We recommend sticking to Google on Android and Apple on iOS for simplicity)*

### 2.4 Flutter Implementation
```dart
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

Future<void> signInWithApple() async {
  final credential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
  );
  
  final idToken = credential.identityToken;
  
  // Apple ONLY provides the user's name on the FIRST ever login!
  // You must capture and send it during this first request.
  String? fullName;
  if (credential.givenName != null || credential.familyName != null) {
      fullName = [credential.givenName, credential.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');
  }
  
  // Send idToken + fullName (if present) to POST /auth/apple/token
}
```
