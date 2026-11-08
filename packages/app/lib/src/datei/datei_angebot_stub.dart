import 'dart:typed_data';

/// Außerhalb des Browsers (Dart-VM, Unit-Tests) gibt es keinen Download.
void bieteDateiAn(String name, Uint8List inhalt, String typ) =>
    throw UnsupportedError('Datei $name: nur im Browser');
