import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Pfad der model-viewer-Bibliothek in der Web-App (`web/model-viewer/`).
const _skript = 'model-viewer/model-viewer.min.js';

Future<void>? _geladen;

/// Lädt model-viewer erst beim ersten Öffnen einer 3D-Ansicht (1 MB).
Future<void> _ladeModelViewer() => _geladen ??= () async {
  web.document.head!.append(
    web.HTMLScriptElement()
      ..type = 'module'
      ..src = _skript,
  );
  await web.window.customElements.whenDefined('model-viewer').toDart;
}();

var _naechsteNummer = 0;

Widget modell3dAnsicht(Uint8List glb, {required String titel}) =>
    _Modell3dAnsicht(glb, titel);

class _Modell3dAnsicht extends StatefulWidget {
  const _Modell3dAnsicht(this.glb, this.titel);

  final Uint8List glb;
  final String titel;

  @override
  State<_Modell3dAnsicht> createState() => _Modell3dAnsichtState();
}

class _Modell3dAnsichtState extends State<_Modell3dAnsicht> {
  late final String _adresse = web.URL.createObjectURL(
    web.Blob(
      [widget.glb.toJS].toJS,
      web.BlobPropertyBag(type: 'model/gltf-binary'),
    ),
  );
  final String _ansicht = 'modell3d-${_naechsteNummer++}';
  late final Future<void> _bereit = _ladeModelViewer();

  @override
  void initState() {
    super.initState();
    ui_web.platformViewRegistry.registerViewFactory(_ansicht, (int _) {
      final element =
          web.document.createElement('model-viewer') as web.HTMLElement;
      for (final (name, wert) in [
        ('src', _adresse),
        ('alt', widget.titel),
        ('camera-controls', ''),
        ('shadow-intensity', '1'),
        // AR mit derselben Datei (M12): Android, iOS, WebXR.
        ('ar', ''),
        ('ar-modes', 'webxr scene-viewer quick-look'),
      ]) {
        element.setAttribute(name, wert);
      }
      element.style
        ..width = '100%'
        ..height = '100%';
      return element;
    });
  }

  @override
  void dispose() {
    web.URL.revokeObjectURL(_adresse);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _bereit,
    builder: (context, stand) => stand.connectionState == ConnectionState.done
        ? HtmlElementView(viewType: _ansicht)
        : const SizedBox.shrink(),
  );
}
