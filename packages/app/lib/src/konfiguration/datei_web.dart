import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Bietet [inhalt] als Download [dateiname] an: Der Browser speichert die
/// Datei oder öffnet sie (PDF), je nach seiner Einstellung.
void dateiAnbieten(Uint8List inhalt, String dateiname) {
  final blob = web.Blob(
    [inhalt.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final adresse = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = adresse
    ..download = dateiname
    ..style.display = 'none';
  web.document.body!.append(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(adresse);
}
