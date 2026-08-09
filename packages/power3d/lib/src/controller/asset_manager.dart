import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';

class Power3DAssetManager {
  static const String _zipPath = 'packages/power3d/assets/power3d_assets.zip';
  static const String _libDirName = 'power3d_assets';

  static Future<HttpServer>? _modelServerFuture;
  static String? _modelsDir;

  /// Stellt sicher, dass die Assets im Anwendungsverzeichnis entpackt sind.
  /// Gibt den Pfad zur index.html-Datei zurück.
  static Future<String> prepareAssets() async {
    final appDir = await getApplicationSupportDirectory();
    final targetDir = Directory(p.join(appDir.path, _libDirName));
    final indexFile = File(p.join(targetDir.path, 'index.html'));
    final tooltipFile = File(
      p.join(targetDir.path, 'js', 'annotation', 'styles', 'tooltip.js'),
    );
    final babylonFile = File(p.join(targetDir.path, 'babylon', 'babylon.js'));

    // `babylon\babylon.js` NICHT über path.join unter Windows prüfen — das löst
    // auf die gültige verschachtelte Datei auf und erzwingt bei jedem Start ein Neu-Entpacken.

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
      await _unzipAssets(targetDir.path);
    } else if (!await indexFile.exists() ||
        !await tooltipFile.exists() ||
        !await babylonFile.exists()) {
      debugPrint(
        'Power3DAssetManager: Assets incomplete - cleaning and re-unzipping...',
      );
      try {
        await targetDir.delete(recursive: true);
        await targetDir.create(recursive: true);
      } catch (e) {
        debugPrint('Power3DAssetManager: Error cleaning targetDir: $e');
      }
      await _unzipAssets(targetDir.path);
    }

    final styleDir = Directory(
      p.join(targetDir.path, 'js', 'annotation', 'styles'),
    );
    if (!await styleDir.exists()) {
      await styleDir.create(recursive: true);
    }

    return indexFile.path;
  }

  static Future<void> _unzipAssets(String targetPath) async {
    try {
      final ByteData data = await rootBundle.load(_zipPath);
      final List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name.replaceAll('\\', '/');

        if (file.isFile) {
          final fileData = file.content as List<int>;
          final outFile = File(p.join(targetPath, filename));
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(fileData);
        } else {
          await Directory(p.join(targetPath, filename)).create(recursive: true);
        }
      }
      debugPrint('Power3DAssetManager: Assets ready at $targetPath');
    } catch (e) {
      debugPrint('Power3DAssetManager: ERROR unzipping: $e');
      rethrow;
    }
  }

  /// Liefert die Basis-URL der entpackten Assets.
  static Future<String> getBaseUrl() async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, _libDirName);
  }

  /// Lokaler HTTP-Server — WebView2/Babylon kann benachbarte `file://`-
  /// Pfade nicht zuverlässig laden (Status 0), aber `http://127.0.0.1` funktioniert und bleibt schnell.
  static Future<String> _modelHttpOrigin() async {
    final server = await (_modelServerFuture ??= _startModelServer());
    return 'http://127.0.0.1:${server.port}';
  }

  static Future<HttpServer> _startModelServer() async {
    final base = await getBaseUrl();
    _modelsDir = p.join(base, 'models');
    await Directory(_modelsDir!).create(recursive: true);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        if (request.method == 'OPTIONS') {
          request.response.headers
            ..set('Access-Control-Allow-Origin', '*')
            ..set('Access-Control-Allow-Methods', 'GET, OPTIONS')
            ..set('Access-Control-Allow-Headers', '*');
          request.response.statusCode = 204;
          await request.response.close();
          return;
        }
        if (request.method != 'GET') {
          request.response.statusCode = 405;
          await request.response.close();
          return;
        }

        final name = p.basename(Uri.decodeComponent(request.uri.path));
        if (name.isEmpty || name == '/' || name.contains('..')) {
          request.response.statusCode = 400;
          await request.response.close();
          return;
        }

        final file = File(p.join(_modelsDir!, name));
        if (!await file.exists()) {
          request.response.statusCode = 404;
          await request.response.close();
          return;
        }

        request.response.headers
          ..set('Access-Control-Allow-Origin', '*')
          ..set('Cache-Control', 'public, max-age=3600')
          ..contentType = ContentType('model', 'gltf-binary');
        request.response.contentLength = await file.length();
        await request.response.addStream(file.openRead());
        await request.response.close();
      } catch (e, st) {
        debugPrint('Power3DAssetManager: model serve error: $e\n$st');
        try {
          request.response.statusCode = 500;
          await request.response.close();
        } catch (_) {}
      }
    });

    debugPrint(
      'Power3DAssetManager: Model HTTP server on 127.0.0.1:${server.port}',
    );
    return server;
  }

  /// Kopiert ein Flutter-Asset-GLB nach `models/` und gibt eine `http://127.0.0.1`-
  /// URL für Babylon zurück (vermeidet riesiges Base64-IPC und kaputte relative file://-Loads).
  static Future<String> ensureAssetModelUrl(String assetPath) async {
    await prepareAssets();
    final base = await getBaseUrl();
    final name = p.basename(assetPath);
    final out = File(p.join(base, 'models', name));
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    if (!await out.exists() || await out.length() != bytes.length) {
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes, flush: true);
      debugPrint(
        'Power3DAssetManager: Cached model ${out.path} (${bytes.length} bytes)',
      );
    }
    final origin = await _modelHttpOrigin();
    return '$origin/$name';
  }

  /// Kopiert eine absolute Datei in den Viewer-Models-Ordner; gibt HTTP-URL zurück.
  static Future<String> ensureFileModelUrl(String filePath) async {
    await prepareAssets();
    final base = await getBaseUrl();
    final name = p.basename(filePath);
    final out = File(p.join(base, 'models', name));
    final src = File(filePath);
    if (!await src.exists()) {
      throw Exception('File not found: $filePath');
    }
    final len = await src.length();
    if (!await out.exists() || await out.length() != len) {
      await out.parent.create(recursive: true);
      await src.copy(out.path);
    }
    final origin = await _modelHttpOrigin();
    return '$origin/$name';
  }
}
