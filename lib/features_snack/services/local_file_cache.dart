import 'dart:io';

import 'package:path/path.dart' as p;

/// Cached Datei-Existenzprüfung – vermeidet wiederholtes `existsSync` im Build.
abstract final class LocalFileCache {
  static final Map<String, bool> _cache = {};

  static String _key(String path) => p.normalize(path);

  static bool exists(String? path) {
    if (path == null || path.isEmpty) {
      return false;
    }

    final key = _key(path);
    final cached = _cache[key];

    // Positive Treffer cachen, negative regelmäßig neu prüfen.
    if (cached == true) {
      return true;
    }

    final result = File(key).existsSync();
    _cache[key] = result;
    return result;
  }

  static void invalidate(String? path) {
    if (path == null || path.isEmpty) {
      return;
    }

    _cache.remove(_key(path));
  }

  static void clear() {
    _cache.clear();
  }
}
