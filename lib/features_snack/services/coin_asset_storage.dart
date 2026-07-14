import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract final class CoinAssetStorage {
  static Future<String> storeDesign(String sourcePath) async {
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw StateError('Münz-Design nicht gefunden: $sourcePath');
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final assetDir = Directory(
      p.join(
        documentsDir.path,
        'coin_assets',
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );

    await assetDir.create(recursive: true);

    final extension = p.extension(sourcePath).toLowerCase();
    final safeExtension = extension.isEmpty ? '.png' : extension;
    final destination = p.join(assetDir.path, 'coin$safeExtension');

    await sourceFile.copy(destination);
    return destination;
  }

  static Future<String?> persistDesignPath(String? path) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    if (await _isManagedAsset(path)) {
      return path;
    }

    return storeDesign(path);
  }

  static Future<void> deleteDesign(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }

    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }

    final parent = file.parent;

    if (await parent.exists() &&
        p.basename(parent.path) != 'coin_assets' &&
        parent.path.contains('coin_assets')) {
      try {
        await parent.delete(recursive: true);
      } catch (_) {
        // Ordner evtl. noch in Benutzung.
      }
    }
  }

  static Future<bool> _isManagedAsset(String path) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final managedRoot = p.normalize(
      p.join(documentsDir.path, 'coin_assets'),
    );
    final normalizedPath = p.normalize(path);

    return p.isWithin(managedRoot, normalizedPath);
  }
}
