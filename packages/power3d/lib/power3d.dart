import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'src/controller/asset_manager.dart';
import 'src/models/power3d_model.dart';
import 'src/controller/power3d_controller.dart';

export 'src/models/power3d_model.dart';
export 'src/controller/power3d_controller.dart';
export 'src/controller/asset_manager.dart';

/// Ein leistungsstarkes, industrieorientiertes 3D-Modell-Viewer-Widget auf Basis von Babylon.js.
///
/// [Power3D] bietet eine High-Level-API zum Rendern komplexer GLB/GLTF-Modelle
/// mit Unterstützung für erweiterte Funktionen wie hardwarebeschleunigte Screenshots,
/// Skelettanimationen, PBR-Material-Overrides und interaktive Annotationen.
///
/// Es ist architekturagnostisch und funktioniert nahtlos mit
/// gängigen State-Management-Lösungen wie Bloc, Riverpod oder Provider.
class Power3D extends StatefulWidget {
  /// Optionaler Controller für die programmatische Interaktion mit der 3D-Szene.
  final Power3DController? controller;

  /// Initiale Modelldaten, die beim Initialisieren des Widgets geladen werden.
  final Power3DData? initialModel;

  /// Callback zum Empfangen von Nachrichten aus der darunterliegenden JavaScript-Schicht.
  final Function(String)? onMessage;

  /// Callback, der ausgelöst wird, wenn ein 3D-Modell erfolgreich geladen wurde.
  final VoidCallback? onModelLoaded;

  /// Wenn auf `true` gesetzt, startet die interne WebView-Engine erst,
  /// wenn die Methode `initialize()` des Controllers aufgerufen wird. Nützlich zur
  /// Performance-Optimierung in UIs mit mehreren Tabs oder komplexen Layouts.
  final bool lazy;

  /// Widget, das angezeigt wird, wenn beim Laden des Modells ein Fehler auftritt.
  final Widget? errorWidget;

  /// Benutzerdefinierte UI, die während des Modellladens angezeigt wird.
  final Widget Function(BuildContext context, Power3DController controller)?
  loadingUi;

  /// Builder-Funktion zum Überlagern benutzerdefinierter Flutter-Widgets über der 3D-Szene.
  /// Ideal zum Hinzufügen von Umgebungs-Hintergründen, eigenen HUDs
  /// oder schwebenden Kamerasteuerungen, die auf den Viewer-Status reagieren.
  final Widget Function(BuildContext context, Power3DState state)?
  environmentBuilder;

  /// Initiale Lichter für die Szene.
  final List<LightingConfig>? lights;

  /// Initialer Exposure-Wert der Szene.
  final double? exposure;

  /// Initialer Kontrastwert der Szene.
  final double? contrast;

  /// JSON-String mit den Annotationen.
  final String? annotations;

  /// Visueller Stil der Annotationen.
  ///
  /// Kann ein direkter HTML/CSS/JS-String für eigenes Styling, ein lokaler JS-Dateipfad
  /// oder ein abstrakter Typ sein (z. B. das Enum `Power3DAnnotationStyle` aus
  /// dem Plugin `power3d_annotations`).
  final dynamic annotationStyle;

  /// Steuert, wie empfindlich Pinch-to-Zoom und Mausrad-Zoom reagieren.
  ///
  /// Bereich: 0.0 (schnellste) bis 1.0 (langsamste). Standard: 0.5.
  final double zoomSensitivity;

  /// Erstellt einen neuen [Power3D]-Viewer.
  const Power3D({
    super.key,
    this.controller,
    this.initialModel,
    this.onMessage,
    this.lazy = false,
    this.errorWidget,
    this.loadingUi,
    this.environmentBuilder,
    this.lights,
    this.exposure,
    this.contrast,
    this.annotations,
    this.annotationStyle,
    this.onModelLoaded,
    this.onAnnotationMore,
    this.zoomSensitivity = 0.5,
  });

  /// Wird ausgelöst, wenn die Aktion „Learn More“ einer Annotation angeklickt wird.
  ///
  /// [id] ist die eindeutige Kennung des Annotationspunkts.
  /// [data] enthält das vollständige JSON-Objekt der Annotation, wie in der
  /// Quellkonfiguration definiert.
  final Function(String id, Map<String, dynamic> data)? onAnnotationMore;

  /// Erstellt einen [Power3D]-Viewer, der ein 3D-Modell aus dem Flutter-Asset-Bundle lädt.
  ///
  /// [path] sollte der logische Pfad zum Asset sein (z. B. 'assets/models/car.glb').
  /// Stelle sicher, dass das Asset korrekt in der `pubspec.yaml` eingetragen ist.
  factory Power3D.fromAsset(
    String path, {
    Key? key,
    Power3DController? controller,
    String? fileName,
    Widget? errorWidget,
    Function(String)? onMessage,
    bool lazy = false,
    Widget Function(BuildContext context, Power3DController controller)?
    loadingUi,
    Widget Function(BuildContext context, Power3DState state)?
    environmentBuilder,
    List<LightingConfig>? lights,
    double? exposure,
    double? contrast,
    String? annotations,
    dynamic annotationStyle,
    VoidCallback? onModelLoaded,
    Function(String id, Map<String, dynamic> data)? onAnnotationMore,
    double zoomSensitivity = 0.5,
  }) {
    return Power3D(
      key: key,
      controller: controller,
      initialModel: Power3DData(
        path: path,
        source: Power3DSource.asset,
        fileName: fileName,
      ),
      onMessage: onMessage,
      lazy: lazy,
      errorWidget: errorWidget,
      loadingUi: loadingUi,
      environmentBuilder: environmentBuilder,
      lights: lights,
      exposure: exposure,
      contrast: contrast,
      annotations: annotations,
      annotationStyle: annotationStyle,
      onModelLoaded: onModelLoaded,
      onAnnotationMore: onAnnotationMore,
      zoomSensitivity: zoomSensitivity,
    );
  }

  /// Erstellt einen [Power3D]-Viewer, der ein 3D-Modell von einer Remote-URL lädt.
  ///
  /// [url] muss ein direkter Link zu einer GLB- oder GLTF-Datei sein.
  /// Hinweis: Stelle sicher, dass der Host-Server CORS-Anfragen für Web-Plattformen erlaubt.
  factory Power3D.fromNetwork(
    String url, {
    Key? key,
    Power3DController? controller,
    String? fileName,
    Widget? errorWidget,
    Function(String)? onMessage,
    bool lazy = false,
    Widget Function(BuildContext context, Power3DController controller)?
    loadingUi,
    Widget Function(BuildContext context, Power3DState state)?
    environmentBuilder,
    List<LightingConfig>? lights,
    double? exposure,
    double? contrast,
    String? annotations,
    dynamic annotationStyle,
    VoidCallback? onModelLoaded,
    Function(String id, Map<String, dynamic> data)? onAnnotationMore,
    double zoomSensitivity = 0.5,
  }) {
    return Power3D(
      key: key,
      controller: controller,
      initialModel: Power3DData(
        path: url,
        source: Power3DSource.network,
        fileName: fileName,
      ),
      onMessage: onMessage,
      lazy: lazy,
      errorWidget: errorWidget,
      loadingUi: loadingUi,
      environmentBuilder: environmentBuilder,
      lights: lights,
      exposure: exposure,
      contrast: contrast,
      annotations: annotations,
      annotationStyle: annotationStyle,
      onModelLoaded: onModelLoaded,
      onAnnotationMore: onAnnotationMore,
      zoomSensitivity: zoomSensitivity,
    );
  }

  /// Erstellt einen [Power3D]-Viewer aus einer lokalen Datei.
  factory Power3D.fromFile(
    dynamic file, {
    Key? key,
    Power3DController? controller,
    String? fileName,
    Widget? errorWidget,
    Function(String)? onMessage,
    bool lazy = false,
    Widget Function(BuildContext context, Power3DController controller)?
    loadingUi,
    Widget Function(BuildContext context, Power3DState state)?
    environmentBuilder,
    List<LightingConfig>? lights,
    double? exposure,
    double? contrast,
    String? annotations,
    dynamic annotationStyle,
    VoidCallback? onModelLoaded,
    Function(String id, Map<String, dynamic> data)? onAnnotationMore,
    double zoomSensitivity = 0.5,
  }) {
    final String path = file is String ? file : file.path;
    return Power3D(
      key: key,
      controller: controller,
      initialModel: Power3DData(
        path: path,
        source: Power3DSource.file,
        fileName: fileName,
      ),
      onMessage: onMessage,
      lazy: lazy,
      errorWidget: errorWidget,
      loadingUi: loadingUi,
      environmentBuilder: environmentBuilder,
      lights: lights,
      exposure: exposure,
      contrast: contrast,
      annotations: annotations,
      annotationStyle: annotationStyle,
      onModelLoaded: onModelLoaded,
      onAnnotationMore: onAnnotationMore,
      zoomSensitivity: zoomSensitivity,
    );
  }

  @override
  State<Power3D> createState() => _Power3DState();
}

class _Power3DState extends State<Power3D> {
  InAppWebViewController? _webViewController;
  late Power3DController _controller;
  // _libReady: Assets entpackt, _libPath: Pfad zu index.html
  bool _libReady = false;
  String? _libPath;
  Future<bool>? _libExistsFuture;
  // _sceneInitialized: JS-Szene wurde einmal initialisiert
  bool _sceneInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? Power3DController();
    debugPrint('Power3D: initState - preparing assets');

    if (widget.lights != null) {
      _controller.setLights(widget.lights!);
    }
    if (widget.exposure != null || widget.contrast != null) {
      _controller.updateSceneProcessing(
        exposure: widget.exposure,
        contrast: widget.contrast,
      );
    }
    // Initiale Zoom-Empfindlichkeit auf den Controller-State anwenden
    _controller.value = _controller.value.copyWith(
      zoomSensitivity: widget.zoomSensitivity,
    );

    _controller.addListener(_onStateChanged);

    if (widget.annotations != null) {
      _controller.setAnnotations(widget.annotations!);
    }
    if (widget.annotationStyle != null) {
      _controller.setAnnotationStyle(widget.annotationStyle!);
    }
    
    _initLib();
  }

  Future<void> _initLib() async {
    try {
      debugPrint('Power3D: _initLib - loading zip asset...');
      final indexPath = await Power3DAssetManager.prepareAssets();
      debugPrint('Power3D: _initLib - assets ready at: $indexPath');
      if (mounted) {
        setState(() {
          _libPath = indexPath;
          _libReady = true;
          _libExistsFuture = File(indexPath).exists();
        });
      }
    } catch (e) {
      debugPrint('Power3D: _initLib FAILED: $e');
    }
  }

  @override
  void didUpdateWidget(Power3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller = widget.controller ?? Power3DController();
      if (_webViewController != null) {
        _controller.setWebViewController(_webViewController!);
      }
    }

    if (widget.lights != oldWidget.lights && widget.lights != null) {
      _controller.setLights(widget.lights!);
    }
    if ((widget.exposure != oldWidget.exposure ||
            widget.contrast != oldWidget.contrast) &&
        (widget.exposure != null || widget.contrast != null)) {
      _controller.updateSceneProcessing(
        exposure: widget.exposure,
        contrast: widget.contrast,
      );
    }

    if (widget.annotations != oldWidget.annotations &&
        widget.annotations != null) {
      _controller.setAnnotations(widget.annotations!);
    }
    if (widget.annotationStyle != oldWidget.annotationStyle &&
        widget.annotationStyle != null) {
      _controller.setAnnotationStyle(widget.annotationStyle!);
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onStateChanged);
    }
    super.dispose();
  }

  void _onStateChanged() {
    final state = _controller.value;

    if (state.status == Power3DStatus.loaded) {
      final modelKey = state.currentModelName;
      if (modelKey != null) {
        widget.onModelLoaded?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Power3DState>(
      valueListenable: _controller,
      builder: (context, state, child) {
        // Wenn der Viewer sichtbar sein soll
        if (!widget.lazy || state.status != Power3DStatus.initial) {
          return SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.environmentBuilder != null)
                  IgnorePointer(
                    child: widget.environmentBuilder!(context, state),
                  ),
                if (_libReady && _libPath != null)
                  FutureBuilder<bool>(
                    future: _libExistsFuture,
                    builder: (context, snapshot) {
                      final exists = snapshot.data ?? false;
                      if (!exists &&
                          snapshot.connectionState == ConnectionState.done) {
                        return const Center(
                          child: Text("Library file not found on disk"),
                        );
                      }
                      return InAppWebView(
                        initialUrlRequest: URLRequest(
                          url: WebUri.uri(Uri.file(_libPath!)),
                        ),
                        initialSettings: InAppWebViewSettings(
                          transparentBackground: true,
                          supportZoom: false,
                          isInspectable: kDebugMode,
                          allowFileAccess: true,
                          allowFileAccessFromFileURLs: true,
                          allowUniversalAccessFromFileURLs: true,
                        ),
                        onWebViewCreated: (controller) {
                          _webViewController = controller;
                          _controller.setWebViewController(controller);

                          _controller.onAnnotationMoreCallback =
                              widget.onAnnotationMore;

                          controller.addJavaScriptHandler(
                            handlerName: 'onMessage',
                            callback: (args) {
                              if (args.isNotEmpty && mounted) {
                                final String message = args[0];
                                // Microtask, um State-Updates während der Build-Phase zu vermeiden,
                                // die auftreten können, wenn die WebView Nachrichten synchron
                                // während Erstellung oder initialem Laden auslöst.
                                Future.microtask(() {
                                  if (mounted) {
                                    _controller.handleWebViewMessage(message);
                                    widget.onMessage?.call(message);
                                  }
                                });
                              }
                            },
                          );
                        },
                        onLoadStop: (controller, url) async {
                          // Initialisierung verzögern, um Konflikte in der Build-Phase zu vermeiden
                          await Future.microtask(() {});
                          if (!mounted) return;

                          debugPrint(
                            'Power3D: onLoadStop - url=$url, sceneInit=$_sceneInitialized',
                          );
                          if (!_sceneInitialized) {
                            _sceneInitialized = true;
                            _controller.initialize();
                            debugPrint(
                              'Power3D: onLoadStop - calling initialize()',
                            );
                            if (widget.initialModel != null) {
                              debugPrint(
                                'Power3D: onLoadStop - loading model: ${widget.initialModel!.path}',
                              );
                              _controller.loadModel(widget.initialModel!);
                            }
                          }
                        },
                        onReceivedError: (controller, request, error) {
                          debugPrint(
                            'Power3D: onReceivedError - url=${request.url} code=${error.type} msg=${error.description}',
                          );
                        },
                        onConsoleMessage: (controller, consoleMessage) {
                          debugPrint(
                            'JS [${consoleMessage.messageLevel.toString()}]: ${consoleMessage.message}',
                          );
                        },
                      );
                  },
                ),
                // Lade-UI oben anzeigen, falls geladen wird
                if (state.status == Power3DStatus.loading ||
                    state.status == Power3DStatus.initial)
                  widget.loadingUi?.call(context, _controller) ??
                      const Center(child: CircularProgressIndicator()),

                // Fehler-Widget anzeigen, falls Fehler
                if (state.status == Power3DStatus.error)
                  widget.errorWidget ?? const Center(child: Text("Error")),
              ],
            ),
          );
        }

        // Platzhalter bei Lazy-Initialisierung
        return widget.loadingUi?.call(context, _controller) ??
            const Center(child: CircularProgressIndicator());
      },
    );
  }
}
