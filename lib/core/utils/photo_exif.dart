import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../config/app_config.dart';
import 'location_utils.dart';

/// GPS coordinates extracted from photo EXIF.
class PhotoGps {
  final double latitude;
  final double longitude;

  const PhotoGps({required this.latitude, required this.longitude});
}

/// Reads GPS from image EXIF and compares it to the device location.
class PhotoExif {
  PhotoExif._();

  /// Converts EXIF GPS rationals (degrees / minutes / seconds) to decimal
  /// degrees. [negative] is true for south latitude or west longitude.
  static double? dmsToDecimal(
    List<double> dms, {
    required bool negative,
  }) {
    if (dms.isEmpty) return null;

    double decimal;
    if (dms.length >= 3) {
      decimal = dms[0] + (dms[1] / 60.0) + (dms[2] / 3600.0);
    } else if (dms.length == 2) {
      decimal = dms[0] + (dms[1] / 60.0);
    } else {
      decimal = dms[0];
    }

    if (decimal.isNaN || decimal.isInfinite) return null;
    return negative ? -decimal : decimal;
  }

  /// True when at least one photo has GPS and every photo that has GPS is
  /// within [radiusKm] of the current location.
  static bool isPhotoLocationVerified({
    required List<(double lat, double lng)?> photoGps,
    required double currentLat,
    required double currentLng,
    double radiusKm = AppConfig.defaultFeedRadiusKm,
  }) {
    final withGps = photoGps.whereType<(double, double)>().toList();
    if (withGps.isEmpty) return false;

    for (final gps in withGps) {
      final distanceKm = LocationUtils.calculateDistance(
        currentLat,
        currentLng,
        gps.$1,
        gps.$2,
      );
      if (distanceKm > radiusKm) return false;
    }
    return true;
  }

  static Future<PhotoGps?> readGpsFromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return readGpsFromBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  static PhotoGps? readGpsFromBytes(Uint8List bytes) {
    try {
      final isJpeg = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
      if (isJpeg) {
        final jpegExif = img.decodeJpgExif(bytes);
        if (jpegExif == null) return null;
        return gpsFromExif(jpegExif);
      }

      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      return gpsFromExif(decoded.exif);
    } catch (_) {
      return null;
    }
  }

  static PhotoGps? gpsFromExif(img.ExifData exif) {
    final gps = exif.gpsIfd;
    final latValue = gps[0x0002];
    final lngValue = gps[0x0004];
    if (latValue == null || lngValue == null) return null;
    if (latValue.length < 1 || lngValue.length < 1) return null;

    final latDms = List<double>.generate(latValue.length, latValue.toDouble);
    final lngDms = List<double>.generate(lngValue.length, lngValue.toDouble);

    final lat = dmsToDecimal(
      latDms,
      negative: _isSouthernOrWestern(gps[0x0001], 'S'),
    );
    final lng = dmsToDecimal(
      lngDms,
      negative: _isSouthernOrWestern(gps[0x0003], 'W'),
    );
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;
    return PhotoGps(latitude: lat, longitude: lng);
  }

  static Future<bool> filesMatchCurrentLocation({
    required List<File> files,
    required double currentLat,
    required double currentLng,
    double radiusKm = AppConfig.defaultFeedRadiusKm,
  }) async {
    final coords = <(double, double)?>[];
    for (final file in files) {
      final gps = await readGpsFromFile(file);
      coords.add(gps == null ? null : (gps.latitude, gps.longitude));
    }
    return isPhotoLocationVerified(
      photoGps: coords,
      currentLat: currentLat,
      currentLng: currentLng,
      radiusKm: radiusKm,
    );
  }

  static bool _isSouthernOrWestern(img.IfdValue? ref, String letter) {
    if (ref == null) return false;
    final asString = ref.toString().trim().toUpperCase();
    if (asString.startsWith(letter)) return true;
    if (ref.length == 1) {
      final code = ref.toInt();
      if (code >= 32 && code <= 126) {
        return String.fromCharCode(code).toUpperCase() == letter;
      }
    }
    return false;
  }
}
