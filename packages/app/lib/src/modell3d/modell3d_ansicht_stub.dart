import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../sprache/sprache.dart';

/// Hinweis außerhalb des Browsers (z. B. in Unit-Tests auf der Dart-VM).
Widget modell3dAnsicht(Uint8List glb, {required String titel}) => Builder(
  builder: (context) =>
      Center(child: Text(context.texte.nurImBrowser, semanticsLabel: titel)),
);
