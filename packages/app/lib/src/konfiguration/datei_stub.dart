import 'dart:typed_data';

/// Außerhalb des Browsers (Dart-VM, Unit-Tests) gibt es keinen Download.
void dateiAnbieten(Uint8List inhalt, String dateiname) =>
    throw UnsupportedError('Datei anbieten nur im Browser');
