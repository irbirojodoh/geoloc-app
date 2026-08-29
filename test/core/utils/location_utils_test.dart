import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/utils/location_utils.dart';

void main() {
  group('LocationUtils.encodeGeohash', () {
    test('produces hashes of the requested precision', () {
      for (final p in [1, 3, 5, 7, 9]) {
        final hash = LocationUtils.encodeGeohash(40.0, -73.0, precision: p);
        expect(hash.length, p, reason: 'precision $p');
      }
    });

    test('uses only base32 geohash characters', () {
      const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
      final hash = LocationUtils.encodeGeohash(48.8584, 2.2945, precision: 8);
      for (final c in hash.split('')) {
        expect(base32.contains(c), isTrue, reason: 'unexpected char $c');
      }
    });

    test('is deterministic for the same coordinates', () {
      final a = LocationUtils.encodeGeohash(35.0, 135.0);
      final b = LocationUtils.encodeGeohash(35.0, 135.0);
      expect(a, b);
    });

    test('default precision matches the post geohash field (7 chars)', () {
      final hash = LocationUtils.encodeGeohash(35.0, 135.0);
      expect(hash.length, 7);
    });

    test('different points produce different hashes', () {
      final a = LocationUtils.encodeGeohash(35.0, 135.0, precision: 7);
      final b = LocationUtils.encodeGeohash(36.0, 135.0, precision: 7);
      expect(a, isNot(equals(b)));
    });
  });

  group('LocationUtils.decodeGeohash', () {
    test('round-trips encode/decode within the cell tolerance', () {
      const lat = 37.7749;
      const lon = -122.4194;
      final hash = LocationUtils.encodeGeohash(lat, lon, precision: 7);
      final decoded = LocationUtils.decodeGeohash(hash);
      // 7-char geohash cell is ~150 m wide; centers should be within 0.01°.
      expect((decoded['latitude']! - lat).abs(), lessThan(0.01));
      expect((decoded['longitude']! - lon).abs(), lessThan(0.01));
    });
  });

  group('LocationUtils.calculateDistance', () {
    test('zero distance for identical points', () {
      expect(LocationUtils.calculateDistance(0, 0, 0, 0), 0.0);
    });

    test('NYC to LA is ~3935 km (±50)', () {
      final d = LocationUtils.calculateDistance(40.7128, -74.0060, 34.0522, -118.2437);
      expect(d, closeTo(3935, 50));
    });

    test('London to Paris is ~344 km (±10)', () {
      final d = LocationUtils.calculateDistance(51.5074, -0.1278, 48.8566, 2.3522);
      expect(d, closeTo(344, 10));
    });
  });

  group('LocationUtils.formatDistance', () {
    test('renders < 1 km in metres', () {
      expect(LocationUtils.formatDistance(0.05), '50m');
      expect(LocationUtils.formatDistance(0.999), '999m');
    });

    test('renders 1–10 km with one decimal', () {
      expect(LocationUtils.formatDistance(2.5), '2.5km');
      expect(LocationUtils.formatDistance(9.94), '9.9km');
    });

    test('renders ≥ 10 km as integers', () {
      expect(LocationUtils.formatDistance(15.4), '15km');
      expect(LocationUtils.formatDistance(120.7), '121km');
    });
  });
}
