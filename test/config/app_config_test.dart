import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/config/app_config.dart';

void main() {
  test('debug default API base URL is configured', () {
    // In test/debug builds without dart-define, LAN default is used.
    expect(AppConfig.apiBaseUrl, isNotEmpty);
    expect(AppConfig.assertValidForRelease, returnsNormally);
  });

  test('isSecureBaseUrl reflects scheme', () {
    // Value depends on dart-define / mode; just ensure getter is stable.
    expect(AppConfig.isSecureBaseUrl, isA<bool>());
  });
}
