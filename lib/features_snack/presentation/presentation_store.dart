import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/overlay_models.dart';

/// Lokale Persistenz der Overlay-Bearbeitungen.
abstract final class PresentationStore {
  static const _fileName = 'presentation_overlays_v11.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, _fileName));
  }

  static Future<OverlayDoc> loadOverlays() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return {};
      final out = <String, List<OverlayEl>>{};
      raw.forEach((key, value) {
        if (value is! List) return;
        out[key.toString()] = value
            .whereType<Map>()
            .map((e) => OverlayEl.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveOverlays(OverlayDoc doc) async {
    final file = await _file();
    final encoded = <String, dynamic>{};
    doc.forEach((key, list) {
      encoded[key] = list.map((e) => e.toJson()).toList();
    });
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(encoded));
  }
}
