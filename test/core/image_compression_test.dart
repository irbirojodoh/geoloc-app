import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:geoloc_app/core/utils/photo_exif.dart';
import 'package:geoloc_app/services/upload_service.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('image_compression_test');
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  File createTestImage(int width, int height, String ext) {
    final image = img.Image(width: width, height: height);
    // Fill with solid red color
    img.fill(image, color: img.ColorRgb8(255, 0, 0));

    final bytes = ext == 'png' ? img.encodePng(image) : img.encodeJpg(image);
    final file = File('${tempDir.path}/test_image_${DateTime.now().microsecondsSinceEpoch}.$ext');
    file.writeAsBytesSync(bytes);
    return file;
  }

  test('normal aspect ratio image (e.g., 3000x2000) is scaled down to cap long side at 2280', () async {
    final file = createTestImage(3000, 2000, 'jpg');

    final compressedPath = await compressAndResizeImageIsolate(file.path);
    expect(compressedPath, isNot(equals(file.path)));

    final compressedBytes = File(compressedPath).readAsBytesSync();
    final compressedImage = img.decodeImage(compressedBytes);

    expect(compressedImage, isNotNull);
    expect(compressedImage!.width, 2280);
    // 2000 * 2280 / 3000 = 1520
    expect(compressedImage.height, 1520);

    // Clean up
    File(compressedPath).deleteSync();
  });

  test('image under max dimensions (e.g., 800x600) is not resized but is compressed', () async {
    final file = createTestImage(800, 600, 'jpg');

    final compressedPath = await compressAndResizeImageIsolate(file.path);
    final compressedBytes = File(compressedPath).readAsBytesSync();
    final compressedImage = img.decodeImage(compressedBytes);

    expect(compressedImage, isNotNull);
    expect(compressedImage!.width, 800);
    expect(compressedImage.height, 600);

    // Clean up
    File(compressedPath).deleteSync();
  });

  test('weird aspect ratio image (e.g. panorama 5000x1000) with short side <= 1280 is not resized', () async {
    // Aspect ratio = 5.0 (weird), short side = 1000 <= 1280
    final file = createTestImage(5000, 1000, 'jpg');

    final compressedPath = await compressAndResizeImageIsolate(file.path);
    final compressedBytes = File(compressedPath).readAsBytesSync();
    final compressedImage = img.decodeImage(compressedBytes);

    expect(compressedImage, isNotNull);
    expect(compressedImage!.width, 5000);
    expect(compressedImage.height, 1000);

    // Clean up
    File(compressedPath).deleteSync();
  });

  test('huge weird aspect ratio image (e.g. 10000x2000) is scaled capping short side to 1280', () async {
    // Aspect ratio = 5.0 (weird), short side = 2000 > 1280
    final file = createTestImage(10000, 2000, 'jpg');

    final compressedPath = await compressAndResizeImageIsolate(file.path);
    expect(compressedPath, isNot(equals(file.path)));

    final compressedBytes = File(compressedPath).readAsBytesSync();
    final compressedImage = img.decodeImage(compressedBytes);

    expect(compressedImage, isNotNull);
    // Short side (height) capped at 1280
    expect(compressedImage!.height, 1280);
    // Long side (width) scaled proportionally: 10000 * 1280 / 2000 = 6400
    expect(compressedImage.width, 6400);

    // Clean up
    File(compressedPath).deleteSync();
  });

  test('non-image file returns original path unmodified', () async {
    final file = File('${tempDir.path}/not_an_image.txt');
    file.writeAsStringSync('Hello World');

    final resultPath = await compressAndResizeImageIsolate(file.path);
    expect(resultPath, equals(file.path));
  });

  test('gif file returns original path unmodified to preserve animations', () async {
    final file = File('${tempDir.path}/test.gif');
    file.writeAsBytesSync([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0, 0, 0, 0]); // minimal GIF header

    final resultPath = await compressAndResizeImageIsolate(file.path);
    expect(resultPath, equals(file.path));
  });

  Uint8List jpegWithGps({required int width, required int height}) {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    final jpeg = Uint8List.fromList(img.encodeJpg(image));
    final exif = img.ExifData();
    exif.gpsIfd[0x0001] = img.IfdValueAscii('N');
    exif.gpsIfd[0x0002] = img.IfdValueRational(40785091, 1000000);
    exif.gpsIfd[0x0003] = img.IfdValueAscii('W');
    exif.gpsIfd[0x0004] = img.IfdValueRational(73968285, 1000000);
    return img.injectJpgExif(jpeg, exif)!;
  }

  test('compression preserves GPS EXIF on a JPEG that is re-encoded', () async {
    final file = File('${tempDir.path}/gps_small.jpg');
    file.writeAsBytesSync(jpegWithGps(width: 800, height: 600));
    expect(PhotoExif.readGpsFromBytes(file.readAsBytesSync()), isNotNull);

    final compressedPath = await compressAndResizeImageIsolate(file.path);
    final gps = PhotoExif.readGpsFromBytes(File(compressedPath).readAsBytesSync());
    expect(gps, isNotNull, reason: 're-encode must keep GPS EXIF');
    expect(gps!.latitude, closeTo(40.785091, 0.00001));
    expect(gps.longitude, closeTo(-73.968285, 0.00001));
    if (compressedPath != file.path) File(compressedPath).deleteSync();
  });

  test('compression preserves GPS EXIF on a JPEG that is resized', () async {
    final file = File('${tempDir.path}/gps_large.jpg');
    file.writeAsBytesSync(jpegWithGps(width: 3000, height: 2000));

    final compressedPath = await compressAndResizeImageIsolate(file.path);
    expect(compressedPath, isNot(equals(file.path)));
    final gps = PhotoExif.readGpsFromBytes(File(compressedPath).readAsBytesSync());
    expect(gps, isNotNull, reason: 'resize+re-encode must keep GPS EXIF');
    expect(gps!.latitude, closeTo(40.785091, 0.00001));
    expect(gps.longitude, closeTo(-73.968285, 0.00001));
    File(compressedPath).deleteSync();
  });
}
