part of 'slide_editor_library.dart';

/// Controller für Auswahl / Studio-Dock (außerhalb der Leinwand).
class SlideCanvasController extends ChangeNotifier {
  final LinkedHashSet<String> selectedIds = LinkedHashSet();

  /// Primäre Auswahl (zuletzt gewählt) für das Studio-Panel.
  String? get selectedId =>
      selectedIds.isEmpty ? null : selectedIds.last;

  void select(String? id, {bool notify = true}) {
    final next = <String>{?id};
    if (setEquals(selectedIds, next)) return;
    selectedIds
      ..clear()
      ..addAll(next);
    if (notify) notifyListeners();
  }

  void selectMany(Iterable<String> ids, {bool notify = true}) {
    final next = LinkedHashSet<String>.from(ids);
    if (setEquals(selectedIds, next)) return;
    selectedIds
      ..clear()
      ..addAll(next);
    if (notify) notifyListeners();
  }

  void toggle(String id, {bool notify = true}) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    if (notify) notifyListeners();
  }

  void ping() => notifyListeners();
}

bool setEquals(Set<String> a, Set<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final e in a) {
    if (!b.contains(e)) return false;
  }
  return true;
}

bool _isModifierPressed() {
  final keys = HardwareKeyboard.instance.logicalKeysPressed;
  return keys.contains(LogicalKeyboardKey.controlLeft) ||
      keys.contains(LogicalKeyboardKey.controlRight) ||
      keys.contains(LogicalKeyboardKey.metaLeft) ||
      keys.contains(LogicalKeyboardKey.metaRight) ||
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;
}
