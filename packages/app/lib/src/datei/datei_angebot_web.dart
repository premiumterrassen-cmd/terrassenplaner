import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Download über einen unsichtbaren Link auf einen Blob – die Datei
/// entsteht im Browser, ohne einen weiteren Server zu berühren. Je nach
/// Einstellung speichert der Browser sie oder öffnet sie (PDF). Die
/// Blob-Adresse wird kurz danach wieder freigegeben.
void bieteDateiAn(String name, Uint8List inhalt, String typ) {
  final adresse = web.URL.createObjectURL(
    web.Blob([inhalt.toJS].toJS, web.BlobPropertyBag(type: typ)),
  );
  final link = web.HTMLAnchorElement()
    ..href = adresse
    ..download = name;
  link.style.display = 'none';
  web.document.body!.append(link);
  link.click();
  link.remove();
  Timer(const Duration(seconds: 10), () => web.URL.revokeObjectURL(adresse));
}
