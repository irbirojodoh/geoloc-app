import 'dart:math';

/// Utility functions for location and geohashing
class LocationUtils {
  LocationUtils._();

  /// Base32 characters for geohash encoding
  static const String _base32Chars = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encode latitude and longitude to geohash
  ///
  /// [latitude] - Latitude value (-90 to 90)
  /// [longitude] - Longitude value (-180 to 180)
  /// [precision] - Number of characters in geohash (default 5 for ~5km precision)
  ///
  /// Precision reference:
  /// - 1: ~5000km
  /// - 2: ~1250km
  /// - 3: ~156km
  /// - 4: ~39km
  /// - 5: ~5km
  /// - 6: ~1.2km
  /// - 7: ~153m
  /// - 8: ~38m
  static String encodeGeohash(
    double latitude,
    double longitude, {
    int precision = 5,
  }) {
    double minLat = -90.0, maxLat = 90.0;
    double minLon = -180.0, maxLon = 180.0;

    int idx = 0;
    int bit = 0;
    bool evenBit = true;
    String geohash = '';

    while (geohash.length < precision) {
      if (evenBit) {
        // Longitude
        final mid = (minLon + maxLon) / 2;
        if (longitude >= mid) {
          idx = idx | (16 >> bit);
          minLon = mid;
        } else {
          maxLon = mid;
        }
      } else {
        // Latitude
        final mid = (minLat + maxLat) / 2;
        if (latitude >= mid) {
          idx = idx | (16 >> bit);
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      evenBit = !evenBit;
      bit++;

      if (bit == 5) {
        geohash += _base32Chars[idx];
        bit = 0;
        idx = 0;
      }
    }

    return geohash;
  }

  /// Decode geohash to latitude and longitude
  /// Returns a map with 'latitude' and 'longitude' keys (center of the cell)
  static Map<String, double> decodeGeohash(String geohash) {
    double minLat = -90.0, maxLat = 90.0;
    double minLon = -180.0, maxLon = 180.0;
    bool evenBit = true;

    for (int i = 0; i < geohash.length; i++) {
      final idx = _base32Chars.indexOf(geohash[i].toLowerCase());

      for (int bit = 4; bit >= 0; bit--) {
        final bitN = (idx >> bit) & 1;

        if (evenBit) {
          // Longitude
          final mid = (minLon + maxLon) / 2;
          if (bitN == 1) {
            minLon = mid;
          } else {
            maxLon = mid;
          }
        } else {
          // Latitude
          final mid = (minLat + maxLat) / 2;
          if (bitN == 1) {
            minLat = mid;
          } else {
            maxLat = mid;
          }
        }

        evenBit = !evenBit;
      }
    }

    return {
      'latitude': (minLat + maxLat) / 2,
      'longitude': (minLon + maxLon) / 2,
    };
  }

  /// Calculate distance between two points using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Convert degrees to radians
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Format distance for display
  /// Shows "m" for distances < 1km, "km" otherwise
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km';
    } else {
      return '${distanceKm.round()}km';
    }
  }

  /// Get neighboring geohashes (8 directions + center)
  static List<String> getNeighborGeohashes(String geohash) {
    // Simplified version - just returns the geohash itself
    // Full implementation would calculate all 8 neighbors
    return [geohash];
  }
}
