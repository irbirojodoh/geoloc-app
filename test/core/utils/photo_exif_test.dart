import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/utils/photo_exif.dart';
import 'package:image/image.dart' as img;

void main() {
  group('PhotoExif.dmsToDecimal', () {
    test('converts degrees, minutes, seconds', () {
      // 40° 47' 6.3276" N = 40.785091
      final decimal = PhotoExif.dmsToDecimal(
        [40, 47, 6.3276],
        negative: false,
      );
      expect(decimal, closeTo(40.785091, 0.00001));
    });

    test('applies south/west sign', () {
      final decimal = PhotoExif.dmsToDecimal(
        [73, 58, 5.826],
        negative: true,
      );
      expect(decimal, closeTo(-73.968285, 0.00001));
    });

    test('accepts degrees + decimal minutes', () {
      final decimal = PhotoExif.dmsToDecimal([40, 47.1], negative: false);
      expect(decimal, closeTo(40.785, 0.0001));
    });

    test('accepts a single decimal-degree rational', () {
      expect(PhotoExif.dmsToDecimal([40.785091], negative: false), 40.785091);
    });

    test('returns null for an empty list', () {
      expect(PhotoExif.dmsToDecimal([], negative: false), isNull);
    });
  });

  group('PhotoExif.isPhotoLocationVerified', () {
    const currentLat = 40.785091;
    const currentLng = -73.968285;

    test('is false when no photo has GPS', () {
      expect(
        PhotoExif.isPhotoLocationVerified(
          photoGps: const [],
          currentLat: currentLat,
          currentLng: currentLng,
        ),
        isFalse,
      );
      expect(
        PhotoExif.isPhotoLocationVerified(
          photoGps: const [null, null],
          currentLat: currentLat,
          currentLng: currentLng,
        ),
        isFalse,
      );
    });

    test('is true when a photo GPS is within 5 km', () {
      expect(
        PhotoExif.isPhotoLocationVerified(
          photoGps: const [(40.785091, -73.968285)],
          currentLat: currentLat,
          currentLng: currentLng,
        ),
        isTrue,
      );
      // ~1 km north
      expect(
        PhotoExif.isPhotoLocationVerified(
          photoGps: const [(40.7941, -73.968285)],
          currentLat: currentLat,
          currentLng: currentLng,
        ),
        isTrue,
      );
    });

    test('is false when a photo GPS is farther than 5 km', () {
      // Los Angeles vs Central Park
      expect(
        PhotoExif.isPhotoLocationVerified(
          photoGps: const [(34.0522, -118.2437)],
          currentLat: currentLat,
          currentLng: currentLng,
        ),
        isFalse,
      );
    });

    test('is false when any GPS-tagged photo is far away', () {
      expect(
        PhotoExif.isPhotoLocationVerified(
          photoGps: const [
            (40.785091, -73.968285),
            (34.0522, -118.2437),
          ],
          currentLat: currentLat,
          currentLng: currentLng,
        ),
        isFalse,
      );
    });

    test('ignores photos without GPS when others match', () {
      expect(
        PhotoExif.isPhotoLocationVerified(
          photoGps: const [null, (40.785091, -73.968285), null],
          currentLat: currentLat,
          currentLng: currentLng,
        ),
        isTrue,
      );
    });
  });

  group('PhotoExif.readGpsFromBytes', () {
    test('returns null for a JPEG without EXIF', () {
      final image = img.Image(width: 8, height: 8);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      final jpeg = Uint8List.fromList(img.encodeJpg(image));
      expect(PhotoExif.readGpsFromBytes(jpeg), isNull);
    });

    test('reads GPS injected into a JPEG', () {
      final image = img.Image(width: 8, height: 8);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      final jpeg = Uint8List.fromList(img.encodeJpg(image));

      final exif = img.ExifData();
      exif.gpsIfd[0x0001] = img.IfdValueAscii('N');
      exif.gpsIfd[0x0002] = img.IfdValueRational(40785091, 1000000);
      exif.gpsIfd[0x0003] = img.IfdValueAscii('W');
      exif.gpsIfd[0x0004] = img.IfdValueRational(73968285, 1000000);

      final withExif = img.injectJpgExif(jpeg, exif);
      expect(withExif, isNotNull);

      final gps = PhotoExif.readGpsFromBytes(withExif!);
      expect(gps, isNotNull);
      expect(gps!.latitude, closeTo(40.785091, 0.00001));
      expect(gps.longitude, closeTo(-73.968285, 0.00001));
    });

    test('gpsFromExif applies S/W refs', () {
      final exif = img.ExifData();
      exif.gpsIfd[0x0001] = img.IfdValueAscii('S');
      exif.gpsIfd[0x0002] = img.IfdValueRational(6, 1);
      exif.gpsIfd[0x0003] = img.IfdValueAscii('E');
      exif.gpsIfd[0x0004] = img.IfdValueRational(107, 1);

      final gps = PhotoExif.gpsFromExif(exif);
      expect(gps, isNotNull);
      expect(gps!.latitude, closeTo(-6.0, 0.0001));
      expect(gps.longitude, closeTo(107.0, 0.0001));
    });
  });
}
