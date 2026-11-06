import 'datei_angebot_stub.dart'
    if (dart.library.js_interop) 'datei_angebot_web.dart'
    as umsetzung;

/// Bietet eine Textdatei zum Speichern an (M9-08); in Tests austauschbar.
typedef TextdateiAnbieten = void Function(String name, String inhalt);

/// Im Browser ein Download der Datei [name] mit [inhalt] (UTF-8); außerhalb
/// des Browsers nicht möglich.
void bieteDateiAn(String name, String inhalt) =>
    umsetzung.bieteDateiAn(name, inhalt);
