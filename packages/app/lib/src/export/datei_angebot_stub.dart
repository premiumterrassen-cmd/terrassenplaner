/// Außerhalb des Browsers (Dart-VM, Unit-Tests) gibt es keinen Download.
void bieteDateiAn(String name, String inhalt) =>
    throw UnsupportedError('Datei $name: nur im Browser');
