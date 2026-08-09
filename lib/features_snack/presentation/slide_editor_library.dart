import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/overlay_models.dart';
import 'package:snackautomat_yakup_leandro/features_snack/presentation/slide_widgets.dart';


part 'slide_canvas_controller.dart';
part 'slide_canvas.dart';
part 'presentation_editor_dock.dart';
part 'canvas_item.dart';
part 'canvas_snap.dart';
