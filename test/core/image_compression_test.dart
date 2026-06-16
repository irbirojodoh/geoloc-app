import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
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
}
