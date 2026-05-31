import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/utils/id_generator.dart';

class ProductImageStorage {
  static const _directoryName = 'product_images';

  static Future<String> savePickedImage(XFile image) async {
    final directory = await _ensureImageDirectory();
    final extension = _safeExtension(image.path);
    final fileName = '${IdGenerator.localUuid()}$extension';
    final savedPath = p.join(directory.path, fileName);
    await image.saveTo(savedPath);
    return savedPath;
  }

  static Future<String> saveBytes({
    required List<int> bytes,
    required String sourceName,
  }) async {
    final directory = await _ensureImageDirectory();
    final extension = _safeExtension(sourceName);
    final fileName = '${IdGenerator.localUuid()}$extension';
    final savedPath = p.join(directory.path, fileName);
    await File(savedPath).writeAsBytes(bytes, flush: true);
    return savedPath;
  }

  static Future<void> deleteImage(String imagePath) async {
    final trimmedPath = imagePath.trim();
    if (trimmedPath.isEmpty) {
      return;
    }

    final file = File(trimmedPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<Directory> _ensureImageDirectory() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory(
      p.join(documentsDirectory.path, _directoryName),
    );
    if (!await imageDirectory.exists()) {
      await imageDirectory.create(recursive: true);
    }
    return imageDirectory;
  }

  static String _safeExtension(String sourcePath) {
    final extension = p.extension(sourcePath).toLowerCase();
    if (extension == '.jpg' ||
        extension == '.jpeg' ||
        extension == '.png' ||
        extension == '.webp' ||
        extension == '.heic') {
      return extension;
    }
    return '.jpg';
  }
}
