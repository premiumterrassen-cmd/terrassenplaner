# ObjectBox im Backend (M0-15, 06.10.2026)

## Umsetzung

- **Fachmodul:** `UuidV7` (RFC 9562, zeitlich sortierbare globale IDs) und `Hlc`/`HlcUhr` (Hybrid Logical Clock, Text `MMMMMMMMMMMMM-ZZZZ-knoten`, lexikografisch sortierbar).
- **Server** `lib/src/datenhaltung/`: `Basisdatensatz` (uid, partition, hlc, knoten, geloeschtAm, schema – ObjectBox-`id` bleibt intern), Entitäten `Aenderung` (Änderungsprotokoll, `knoten:seq` eindeutig) und `Benutzer` (Mitarbeiter-Zugang, Partition `global`). `Datenbank`: speichern/löschen (Grabstein) mit Protokolleintrag in **derselben Transaktion**, lückenlose Sequenz je Knoten, `aenderungenSeit`, Kennzahlen (Dateigröße, Sequenz, Anzahl), konsistente Sicherung (Kopie der Datenbankdatei in einer Schreibtransaktion).
- **Auth-Server:** Mitarbeiter-Zugänge aus ObjectBox (`PLANER_DATENVERZEICHNIS`, `PLANER_KNOTEN`); `PLANER_MITARBEITER_DATEI` wird beim Start übernommen (neu/geändert schreiben, gleich überspringen).
- **Code-Erzeugung:** `objectbox_generator` + `build_runner` → `lib/objectbox.g.dart` und `lib/objectbox-model.json` (**beide committen** – die Modell-Datei hält die festen IDs des Schemas). Nach Änderungen an Entitäten: `cd packages/server && dart run build_runner build --delete-conflicting-outputs`.

## Native Bibliothek

- objectbox-c **v5.3.2** (passend zum Dart-Paket 5.3.2), Bezug und Prüfsumme in `tool/objectbox_bibliothek.sh`: legt `libobjectbox.dylib` (macOS) bzw. `libobjectbox.so` (Linux) unter `packages/server/lib/` ab – dort sucht das Dart-Paket zuerst (macOS ignoriert `DYLD_LIBRARY_PATH` für die gehärtete Dart-VM). Nicht im Repository.
- Build-Chain: Skript in allen Test-Jobs; im Build-Job zusätzlich in beide Bündel (`artefakte/*/lib`), wo die Dienste sie über `LD_LIBRARY_PATH` finden (systemd-Unit bzw. Container-Bild).

## Offen

- Geplante Sicherung auf dem Server (Zeitplan, Aufbewahrung, Ablage außerhalb des Servers) – mit M0-14/M10-03.
- Kennzahlen als Prometheus-Metriken ausliefern – M0-14.
- ObjectBox erlaubt einen Prozess je Datenbank: Verwaltung von Mitarbeitern künftig über WAMP-Prozeduren des Auth-Servers statt über Dateien.
