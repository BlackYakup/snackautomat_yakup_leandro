import 'dart:convert';
import 'dart:io';

/// Liest OBJ-Objekt-/Gruppennamen und extrahiert ein einzelnes Teil.
abstract final class ObjModelParser {
  static Future<List<String>> extractObjectNames(String objPath) async {
    final file = File(objPath);

    if (!await file.exists() || !objPath.toLowerCase().endsWith('.obj')) {
      return const [];
    }

    final names = <String>[];
    final seen = <String>{};

    await for (final line in file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final trimmed = line.trim();

      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      String? name;

      if (trimmed.startsWith('o ')) {
        name = trimmed.substring(2).trim();
      } else if (trimmed.startsWith('g ')) {
        name = trimmed.substring(2).trim();
      } else if (trimmed.startsWith('usemtl ')) {
        name = trimmed.substring(7).trim();
      }

      if (name != null && name.isNotEmpty && seen.add(name)) {
        names.add(name);
      }
    }

    return names;
  }

  /// Extrahiert ein einzelnes Objekt aus einer Multi-Object-OBJ-Datei.
  static Future<String> extractPart({
    required String sourcePath,
    required String partName,
    required String destinationPath,
  }) async {
    final source = File(sourcePath);

    if (!await source.exists()) {
      throw StateError('OBJ-Datei nicht gefunden: $sourcePath');
    }

    final lines = await source.readAsLines();
    final headerLines = <String>[];
    final sections = <String, List<String>>{};
    String? currentPart;

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        continue;
      }

      if (trimmed.startsWith('o ') || trimmed.startsWith('g ')) {
        currentPart = trimmed.substring(2).trim();
        sections.putIfAbsent(currentPart, () => <String>[]);
        sections[currentPart]!.add(line);
        continue;
      }

      if (trimmed.startsWith('usemtl ')) {
        currentPart = trimmed.substring(7).trim();
        sections.putIfAbsent(currentPart, () => <String>[]);
        sections[currentPart]!.add(line);
        continue;
      }

      if (currentPart == null) {
        headerLines.add(line);
      } else {
        sections[currentPart]!.add(line);
      }
    }

    if (sections.isEmpty) {
      throw StateError(
        'OBJ enthält keine getrennten Objekte (o/g/usemtl).',
      );
    }

    final matchedKey = resolvePartName(sections.keys.toList(), partName);

    if (matchedKey == null) {
      throw StateError('OBJ-Teil "$partName" nicht gefunden.');
    }

    final output = <String>[
      ...headerLines,
      ...sections[matchedKey]!,
    ];

    final outFile = File(destinationPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsString('${output.join('\n')}\n');

    return outFile.path;
  }

  static String? resolvePartName(List<String> parts, String selected) {
    if (parts.isEmpty) {
      return null;
    }

    if (parts.contains(selected)) {
      return selected;
    }

    final lowerSelected = selected.toLowerCase().trim();

    for (final part in parts) {
      if (part.toLowerCase() == lowerSelected) {
        return part;
      }
    }

    for (final part in parts) {
      final lowerPart = part.toLowerCase();
      if (lowerPart.contains(lowerSelected) ||
          lowerSelected.contains(lowerPart)) {
        return part;
      }
    }

    final selectedTokens = _tokens(lowerSelected);
    String? bestMatch;
    var bestScore = 0;

    for (final part in parts) {
      final score = _overlapScore(selectedTokens, _tokens(part.toLowerCase()));
      if (score > bestScore) {
        bestScore = score;
        bestMatch = part;
      }
    }

    return bestScore > 0 ? bestMatch : parts.first;
  }

  static List<String> _tokens(String value) {
    return value
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 2)
        .toList();
  }

  static int _overlapScore(List<String> a, List<String> b) {
    var score = 0;

    for (final token in a) {
      if (b.contains(token)) {
        score += 1;
      }
    }

    return score;
  }
}

abstract final class ModelPartsHelper {
  static List<String> merge(List<String> current, List<String> discovered) {
    final merged = <String>[];
    final seen = <String>{};

    void addAll(Iterable<String> values) {
      for (final value in values) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        final key = trimmed.toLowerCase();
        if (seen.add(key)) {
          merged.add(trimmed);
        }
      }
    }

    addAll(current);
    addAll(discovered);

    return merged;
  }

  static bool hasMultipleParts(List<String> parts) => parts.length >= 2;
}
