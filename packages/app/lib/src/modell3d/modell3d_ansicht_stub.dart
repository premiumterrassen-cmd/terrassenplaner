import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Hinweis außerhalb des Browsers (z. B. in Unit-Tests auf der Dart-VM).
const nurImBrowser = 'Die 3D-Ansicht gibt es nur im Browser.';

Widget modell3dAnsicht(Uint8List glb, {required String titel}) =>
    Center(child: Text(nurImBrowser, semanticsLabel: titel));
