import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:snackautomat_yakup_leandro/features_snack/services/obj_model_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/local_file_cache.dart';

const _modelExtensions = {'.glb', '.gltf', '.obj'};
const _companionExtensions = {
  '.mtl',
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.bmp',
  '.tga',
  '.tif',
  '.tiff',
  '.bin',
  '.glb',
  '.gltf',
};

abstract final class ProductAssetStorage {
  static Future<String> storeImage(String sourcePath) async {
    final sourceFile = File(sourcePath);

    if (!sourceFile.existsSync()) {
      throw StateError('Bilddatei nicht gefunden: $sourcePath');
    }

    final assetDir = await _createAssetDirectory('images');
    final extension = p.extension(sourcePath).toLowerCase();
    final safeExtension = extension.isEmpty ? '.png' : extension;
    final destination = p.join(assetDir.path, 'image$safeExtension');

    await sourceFile.copy(destination);
    LocalFileCache.invalidate(destination);
    return destination;
  }

  static Future<String> storeModel(String sourcePath) async {
    final sourceFile = File(sourcePath);

    if (!sourceFile.existsSync()) {
      throw StateError('3D-Datei nicht gefunden: $sourcePath');
    }

    final extension = p.extension(sourcePath).toLowerCase();

    if (!_modelExtensions.contains(extension)) {
      throw ArgumentError(
        'Nicht unterstütztes 3D-Format: $extension (erlaubt: glb, gltf, obj)',
      );
    }

    final assetDir = await _createAssetDirectory('models');
    final destination = p.join(assetDir.path, 'model$extension');
    await sourceFile.copy(destination);

    if (extension == '.obj') {
      await _copyAllFilesFromDirectory(
        sourceDirectory: sourceFile.parent,
        destinationDirectory: assetDir,
        skipFileName: p.basename(sourcePath),
      );
    } else {
      await _copyCompanionFiles(
        sourceDirectory: sourceFile.parent,
        destinationDirectory: assetDir,
        mainFileName: p.basename(sourcePath),
      );
    }

    LocalFileCache.invalidate(destination);
    return destination;
  }

  static Future<void> deleteAssetsForProduct(Product product) async {
    await _deleteManagedAsset(product.imagePath);
    await _deleteManagedAsset(product.modelPath);
  }

  static Future<void> _deleteManagedAsset(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }

    if (!await _isManagedAsset(path)) {
      return;
    }

    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }

    LocalFileCache.invalidate(path);

    final parent = file.parent;

    if (await parent.exists() && parent.path.contains('product_assets')) {
      try {
        final entries = await parent.list().toList();

        if (entries.isEmpty) {
          await parent.delete(recursive: true);
        }
      } catch (_) {
        // Ordner evtl. noch geöffnet.
      }
    }
  }

  static String normalizePath(String path) {
    return p.normalize(path);
  }

  static Future<String?> persistImagePath(String? path) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    if (await _isManagedAsset(path)) {
      return path;
    }

    return storeImage(path);
  }

  static Future<String?> persistModelPath(String? path) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    if (await _isManagedAsset(path)) {
      LocalFileCache.invalidate(path);
      return path;
    }

    return storeModel(path);
  }

  /// Kopiert das Modell sofort in den App-Ordner (für Vorschau nach dem Hochladen).
  static Future<String> ensureModelForPreview(String path) async {
    final normalized = normalizePath(path);
    final persisted = await persistModelPath(normalized);

    if (persisted == null) {
      throw StateError('3D-Modell konnte nicht vorbereitet werden.');
    }

    LocalFileCache.invalidate(persisted);
    return persisted;
  }

  static Future<void> deleteManagedAsset(String? path) async {
    await _deleteManagedAsset(path);
  }

  /// Bei Multi-Object-OBJ wird das gewählte Teil als eigene Datei gespeichert.
  static Future<String?> finalizeModelSelection({
    required String? modelPath,
    required String? modelPart,
    required List<String> availableParts,
  }) async {
    if (modelPath == null || modelPath.isEmpty) {
      return null;
    }

    if (!modelPath.toLowerCase().endsWith('.obj')) {
      return modelPath;
    }

    if (modelPart == null ||
        modelPart.isEmpty ||
        !ModelPartsHelper.hasMultipleParts(availableParts)) {
      return modelPath;
    }

    final assetDir = Directory(p.dirname(modelPath));
    final activePath = p.join(assetDir.path, 'model_active.obj');

    final extracted = await ObjModelParser.extractPart(
      sourcePath: modelPath,
      partName: modelPart,
      destinationPath: activePath,
    );

    LocalFileCache.invalidate(extracted);
    return extracted;
  }

  static Future<Directory> _createAssetDirectory(String category) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final assetDir = Directory(
      p.join(
        documentsDir.path,
        'product_assets',
        category,
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );

    await assetDir.create(recursive: true);
    return assetDir;
  }

  static Future<void> _copyAllFilesFromDirectory({
    required Directory sourceDirectory,
    required Directory destinationDirectory,
    required String skipFileName,
  }) async {
    for (final entity in await sourceDirectory.list().toList()) {
      if (entity is! File) {
        continue;
      }

      final fileName = p.basename(entity.path);

      if (fileName == skipFileName) {
        continue;
      }

      await entity.copy(p.join(destinationDirectory.path, fileName));
    }
  }

  static Future<void> _copyCompanionFiles({
    required Directory sourceDirectory,
    required Directory destinationDirectory,
    required String mainFileName,
  }) async {
    for (final entity in await sourceDirectory.list().toList()) {
      if (entity is! File) {
        continue;
      }

      final fileName = p.basename(entity.path);

      if (fileName == mainFileName) {
        continue;
      }

      final extension = p.extension(fileName).toLowerCase();

      if (!_companionExtensions.contains(extension)) {
        continue;
      }

      await entity.copy(p.join(destinationDirectory.path, fileName));
    }
  }

  static Future<bool> _isManagedAsset(String path) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final managedRoot = p.normalize(
      p.join(documentsDir.path, 'product_assets'),
    );
    final normalizedPath = p.normalize(path);

    return p.isWithin(managedRoot, normalizedPath);
  }
}
