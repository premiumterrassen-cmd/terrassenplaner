import 'dart:typed_data';

import 'datei_angebot_stub.dart'
    if (dart.library.js_interop) 'datei_angebot_web.dart'
    as umsetzung;

/// Bietet die Datei [name] mit [inhalt] vom MIME-Typ [typ] zum Speichern
/// oder Öffnen an (Planungsunterlagen M9-06, Export für GrandTotal M9-08);
/// in Tests austauschbar.
typedef DateiAnbieten = void Function(
  String name,
  Uint8List inhalt,
  String typ,
);

/// Im Browser ein Download; außerhalb des Browsers nicht möglich.
void bieteDateiAn(String name, Uint8List inhalt, String typ) =>
    umsetzung.bieteDateiAn(name, inhalt, typ);
