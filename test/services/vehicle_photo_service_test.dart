import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:gasmaster/services/vehicle_photo_service.dart';

Uint8List _jpeg({required int width, required int height, int quality = 95}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 40, 40));
  // Add some noise so JPEG doesn't compress too aggressively.
  for (var y = 0; y < height; y += 8) {
    for (var x = 0; x < width; x += 8) {
      image.setPixelRgba(x, y, (x * 3) % 255, (y * 5) % 255, 80, 255);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gasmaster_photo_');
    VehiclePhotoService.documentsOverride = tempDir;
  });

  tearDown(() async {
    VehiclePhotoService.documentsOverride = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });
  group('VehiclePhotoService.optimizeBytes', () {
    test('downsizes large images and reports savings', () {
      final original = _jpeg(width: 3000, height: 2000, quality: 95);
      final result = VehiclePhotoService.optimizeBytes(original);

      expect(result.originalBytes, original.lengthInBytes);
      expect(result.optimizedBytes, lessThan(result.originalBytes));
      expect(result.wasReduced, isTrue);
      expect(result.savedBytes, greaterThan(0));
      expect(result.savingsSummary, contains('→'));
      expect(result.savingsSummary, contains('saved'));

      final decoded = img.decodeImage(result.bytes)!;
      expect(decoded.width <= VehiclePhotoService.maxEdge, isTrue);
      expect(decoded.height <= VehiclePhotoService.maxEdge, isTrue);
    });

    test('formatBytes formats KB and MB', () {
      expect(formatBytes(500), '500 B');
      expect(formatBytes(2048), contains('KB'));
      expect(formatBytes(2 * 1024 * 1024), contains('MB'));
    });
  });

  test('saves an optimized file and deletes it by relative path', () async {
    final source = File('${tempDir.path}/source.jpg')
      ..writeAsBytesSync(_jpeg(width: 300, height: 200));

    final saved = await VehiclePhotoService.saveOptimized(
      vehicleId: 'vehicle-1',
      sourceFile: source,
    );
    final destination = File(
      await VehiclePhotoService.absolutePath(saved.relativePath),
    );

    expect(saved.relativePath, 'vehicle_photos/vehicle-1.jpg');
    expect(await destination.exists(), isTrue);
    expect((await destination.readAsBytes()), saved.result.bytes);

    await VehiclePhotoService.deletePhoto(saved.relativePath);

    expect(await destination.exists(), isFalse);
  });
}
