import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageOptimizationResult {
  final Uint8List bytes;
  final int originalBytes;
  final int optimizedBytes;
  final int maxEdge;
  final int quality;

  const ImageOptimizationResult({
    required this.bytes,
    required this.originalBytes,
    required this.optimizedBytes,
    required this.maxEdge,
    required this.quality,
  });

  int get savedBytes =>
      originalBytes > optimizedBytes ? originalBytes - optimizedBytes : 0;

  double get savedPercent =>
      originalBytes > 0 ? (savedBytes / originalBytes) * 100.0 : 0.0;

  bool get wasReduced => optimizedBytes < originalBytes;

  String get savingsSummary {
    if (!wasReduced) {
      return 'Stored at ${formatBytes(optimizedBytes)} (already efficient)';
    }
    return '${formatBytes(originalBytes)} → ${formatBytes(optimizedBytes)} '
        '(saved ${formatBytes(savedBytes)}, ${savedPercent.toStringAsFixed(0)}%)';
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}

class VehiclePhotoService {
  static const photosDirName = 'vehicle_photos';
  static const maxEdge = 1280;
  static const jpegQuality = 80;

  /// Override in tests.
  static Directory? documentsOverride;

  static Future<Directory> _docs() async =>
      documentsOverride ?? await getApplicationDocumentsDirectory();

  static Future<String> absolutePath(String relativePath) async {
    return p.join((await _docs()).path, relativePath);
  }

  static String relativePathFor(String vehicleId) =>
      p.join(photosDirName, '$vehicleId.jpg');

  /// Decode, downsize if needed, and JPEG-encode for storage.
  static ImageOptimizationResult optimizeBytes(
    Uint8List source, {
    int maxEdgePx = maxEdge,
    int quality = jpegQuality,
  }) {
    final originalBytes = source.lengthInBytes;
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw StateError('Could not decode image');
    }

    img.Image processed = decoded;
    final longest = processed.width > processed.height ? processed.width : processed.height;
    if (longest > maxEdgePx) {
      if (processed.width >= processed.height) {
        processed = img.copyResize(processed, width: maxEdgePx);
      } else {
        processed = img.copyResize(processed, height: maxEdgePx);
      }
    }

    final encoded = Uint8List.fromList(img.encodeJpg(processed, quality: quality));
    return ImageOptimizationResult(
      bytes: encoded,
      originalBytes: originalBytes,
      optimizedBytes: encoded.lengthInBytes,
      maxEdge: maxEdgePx,
      quality: quality,
    );
  }

  static Future<ImageOptimizationResult> optimizeFile(File file) async {
    final bytes = await file.readAsBytes();
    return optimizeBytes(Uint8List.fromList(bytes));
  }

  /// Optimizes [sourceFile] and writes `vehicle_photos/{vehicleId}.jpg`.
  static Future<({String relativePath, ImageOptimizationResult result})> saveOptimized({
    required String vehicleId,
    required File sourceFile,
  }) async {
    final result = await optimizeFile(sourceFile);
    final relative = relativePathFor(vehicleId);
    final dest = File(await absolutePath(relative));
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(result.bytes, flush: true);
    return (relativePath: relative, result: result);
  }

  static Future<({String relativePath, ImageOptimizationResult result})> saveOptimizedBytes({
    required String vehicleId,
    required ImageOptimizationResult result,
  }) async {
    final relative = relativePathFor(vehicleId);
    final dest = File(await absolutePath(relative));
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(result.bytes, flush: true);
    return (relativePath: relative, result: result);
  }

  static Future<void> deletePhoto(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    final file = File(await absolutePath(relativePath));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
