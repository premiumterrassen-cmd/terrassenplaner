import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'modell3d_ansicht_stub.dart'
    if (dart.library.js_interop) 'modell3d_ansicht_web.dart'
    as umsetzung;

/// Zeigt ein GLB an (M3-10): im Browser mit model-viewer (WebGL, später AR
/// mit derselben Datei), sonst ein Hinweis. Die App rechnet nichts – das
/// Modell kommt fertig vom Server.
Widget modell3dAnsicht(Uint8List glb, {required String titel}) =>
    umsetzung.modell3dAnsicht(glb, titel: titel);
