import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bereitet Power3D-Assets einmalig vor und behebt Windows-Pfad-Probleme,
/// bevor irgendein WebView gestartet wird.
abstract final class Power3dBootstrap {
  static const _zipPath = 'packages/power3d/assets/power3d_assets.zip';
  static const _libDirName = 'power3d_assets';

  static Future<void>? _prepareFuture;

  static Future<void> ensureReady() {
    return _prepareFuture ??= _prepare();
  }

  static Future<void> _prepare() async {
    final appDir = await getApplicationSupportDirectory();
    final targetDir = Directory(p.join(appDir.path, _libDirName));
    final indexFile = File(p.join(targetDir.path, 'index.html'));
    final tooltipFile = File(
      p.join(targetDir.path, 'js', 'annotation', 'styles', 'tooltip.js'),
    );
    final babylonFile = File(p.join(targetDir.path, 'babylon', 'babylon.js'));
    // Hinweis: `p.join(..., r'babylon\babylon.js')` ist unter Windows identisch
    // mit dem korrekten Pfad und darf NICHT als „fehlerhaft“ gewertet werden.

    final needsUnzip = !await targetDir.exists() ||
        !await indexFile.exists() ||
        !await tooltipFile.exists() ||
        !await babylonFile.exists();

    if (needsUnzip) {
      debugPrint('Power3dBootstrap: Assets unvollständig – werden neu entpackt.');
      await _rebuildTargetDir(targetDir);
      await _unzipAssets(targetDir.path);
    }

    final styleDir = Directory(
      p.join(targetDir.path, 'js', 'annotation', 'styles'),
    );
    if (!await styleDir.exists()) {
      await styleDir.create(recursive: true);
    }

    debugPrint('Power3dBootstrap: Assets bereit unter ${indexFile.path}');
  }

  static Future<void> _rebuildTargetDir(Directory targetDir) async {
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
      return;
    }

    try {
      await targetDir.delete(recursive: true);
      await targetDir.create(recursive: true);
      return;
    } catch (error) {
      debugPrint('Power3dBootstrap: Löschen fehlgeschlagen: $error');
    }

    final renamed = Directory(
      p.join(
        targetDir.parent.path,
        '${_libDirName}_broken_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    try {
      await targetDir.rename(renamed.path);
    } catch (error) {
      debugPrint('Power3dBootstrap: Umbenennen fehlgeschlagen: $error');
    }

    await targetDir.create(recursive: true);
  }

  static Future<void> _unzipAssets(String targetPath) async {
    final data = await rootBundle.load(_zipPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name.replaceAll('\\', '/');

      if (file.isFile) {
        final outFile = File(p.join(targetPath, filename));
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(p.join(targetPath, filename)).create(recursive: true);
      }
    }
  }
}

/// Erlaubt nur eine aktive Power3D-WebView in der gesamten App.
abstract final class ProductModelViewerLock {
  static bool _inUse = false;

  static bool tryAcquire() {
    if (_inUse) {
      return false;
    }

    _inUse = true;
    return true;
  }

  static void release() {
    _inUse = false;
  }
}
