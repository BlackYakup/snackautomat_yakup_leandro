part of 'power3d_controller.dart';

/// Erweiterung von [Power3DController] für Animationsverwaltung.
extension Power3DAnimationExtension on Power3DController {
  /// Ruft die Liste aller im aktuellen Modell verfügbaren Animationen ab.
  Future<void> getAnimationsList() async {
    if (!value.isInitialized || _webViewController == null) return;
    await _webViewController!.evaluateJavascript(source: 'getAnimationsList()');
  }

  /// Spielt eine bestimmte Animation anhand von [name] ab.
  ///
  /// [loop] legt fest, ob die Animation wiederholt werden soll.
  /// [speed] setzt das Wiedergabe-Geschwindigkeitsverhältnis.
  Future<void> playAnimation(
    String name, {
    bool loop = true,
    double speed = 1.0,
  }) async {
    if (!value.isInitialized || _webViewController == null) return;

    await _webViewController!.evaluateJavascript(
      source: 'playAnimation("$name", $loop, $speed)',
    );
  }

  /// Pausiert eine bestimmte Animation anhand von [name].
  Future<void> pauseAnimation(String name) async {
    if (!value.isInitialized || _webViewController == null) return;
    await _webViewController!.evaluateJavascript(
      source: 'pauseAnimation("$name")',
    );
  }

  /// Stoppt eine bestimmte Animation anhand von [name].
  Future<void> stopAnimation(String name) async {
    if (!value.isInitialized || _webViewController == null) return;
    await _webViewController!.evaluateJavascript(
      source: 'stopAnimation("$name")',
    );
  }

  /// Setzt die Wiedergabegeschwindigkeit für eine bestimmte Animation.
  Future<void> setAnimationSpeed(String name, double speed) async {
    if (!value.isInitialized || _webViewController == null) return;
    await _webViewController!.evaluateJavascript(
      source: 'setAnimationSpeed("$name", $speed)',
    );
  }

  /// Legt fest, ob eine bestimmte Animation in einer Schleife laufen soll.
  Future<void> setAnimationLoop(String name, bool loop) async {
    if (!value.isInitialized || _webViewController == null) return;
    await _webViewController!.evaluateJavascript(
      source: 'setAnimationLoop("$name", $loop)',
    );
  }

  /// Pausiert eine Animation nach einer angegebenen [duration].
  void pauseAfter(String name, Duration duration) {
    Timer(duration, () {
      pauseAnimation(name);
    });
  }

  /// Stoppt alle aktuell aktiven Animationen.
  Future<void> stopAllAnimations() async {
    if (!value.isInitialized || _webViewController == null) return;
    await _webViewController!.evaluateJavascript(source: 'stopAllAnimations()');
  }

  /// Startet oder setzt alle verfügbaren Animationen fort.
  Future<void> startAllAnimations() async {
    if (!value.isInitialized || _webViewController == null) return;
    await _webViewController!.evaluateJavascript(
      source: 'startAllAnimations()',
    );
  }

  /// Legt fest, ob mehrere Animationen gleichzeitig abgespielt werden können.
  Future<void> setPlayMultiple(bool enabled) async {
    if (!value.isInitialized || _webViewController == null) return;
    value = value.copyWith(playMultiple: enabled);
    await _webViewController!.evaluateJavascript(
      source: 'window.playMultiple = $enabled',
    );
  }
}
