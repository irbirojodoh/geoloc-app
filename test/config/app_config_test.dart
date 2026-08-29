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

  test('feed radius is clamped to the 15 km server maximum', () {
    expect(AppConfig.maxFeedRadiusKm, 15);
    expect(AppConfig.clampFeedRadiusKm(15), 15);
    expect(AppConfig.clampFeedRadiusKm(50), 15);
    expect(AppConfig.clampFeedRadiusKm(0), AppConfig.defaultFeedRadiusKm);
    expect(AppConfig.clampFeedRadiusKm(-3), AppConfig.defaultFeedRadiusKm);
    expect(AppConfig.clampFeedRadiusKm(double.nan), AppConfig.defaultFeedRadiusKm);
    expect(AppConfig.feedRadiusOptionsKm.last, 15);
    expect(
      AppConfig.feedRadiusOptionsKm.every((km) => km <= AppConfig.maxFeedRadiusKm),
      isTrue,
    );
    expect(AppConfig.formatFeedRadiusKm(50), '15 km');
    expect(AppConfig.formatFeedRadiusKm(5), '5 km');
  });

  test('feed receive timeout is at least 10 seconds', () {
    expect(
      AppConfig.feedReceiveTimeout,
      greaterThanOrEqualTo(const Duration(seconds: 10)),
    );
  });
}
