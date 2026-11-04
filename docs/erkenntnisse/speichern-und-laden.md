# Speichern und Laden (M9-05, 04.11.2026)

## Umsetzung

- **Konfigurationsdienst** (`packages/server/lib/src/dienste/konfigurations_dienst.dart`) im Router-Prozess mit vier Kunden-Prozeduren:
  - `konfiguration.speichern` `[inhalt]` bzw. `[inhalt, nummer]` → `[nummer, version]`;
  - `konfiguration.laden` `[nummer, version]` → `[inhalt]`;
  - `konfiguration.entwurf_speichern` / `konfiguration.entwurf_laden` für das automatische Zwischenspeichern je Sitzungsschlüssel.
  - Fehler-URIs `fehler.konfiguration_unbekannt`, `fehler.entwurf_unbekannt`, `fehler.konfiguration_ungueltig`.
- **Inhalt** ist die Planung im vorhandenen Transportformat (`Planung.zuBytes`, mit eigener Schema-Version) als Binärargument. Der Dienst prüft nur, dass sie lesbar ist (`Planung.ausBytes`) und höchstens 1 MiB groß – was gespeichert ist, lässt sich immer laden. Kein PPT, weil Nummer und Version neben dem Inhalt reisen.
- **ObjectBox** (`konfigurationen.dart`, Regeln aus `docs/architektur/datenmodell.md`):
  - `Konfiguration`: Kopf, eindeutig über die Nummer, Partition = Nummer, laufende Nummer je Tag (Index `tag`), `aktuelleVersion`, `erstelltAm` (HLC von Version 1).
  - `KonfigurationsVersion`: append-only, Schlüssel `nummer/version`.
  - `Zwischenstand`: ein Datensatz je Sitzungsschlüssel, wird überschrieben, Frist 30 Tage.
  - Version und Kopf entstehen in **einer** Transaktion (`Datenbank.transaktion`) samt Änderungsprotokoll.
- **Nummernvergabe:** Ortszeit des Servers bestimmt den Tag, `NNNN` zählt je Tag ab 1 (höchstens 9999). Gleicht die Planung der letzten Version, entsteht keine neue Version.
- **App:**
  - SPEICHERN und LADEN in der Kopfzeile. SPEICHERN ohne Rückfrage, Nummer und Version als Hinweis.
  - LADEN öffnet „Konfiguration laden“, vorbelegt mit der geöffneten Konfiguration und mit „Konfiguration Speichern“.
  - `KonfigurationsSteuerung` hält die Planung; `PlanerVerbindung` ist die `KonfigurationsAblage`.
  - ZURÜCKSETZEN beginnt eine neue Planung ohne Nummer.

## Entscheidung: Zwischenspeichern als Entwurf, nicht als Version

- 5 s nach der letzten Änderung geht die Planung als Entwurf an den Server.
- Jede weitere Änderung verschiebt den Zeitpunkt; unveränderte Stände werden weder gesendet noch geschrieben.
- Versionen entstehen nur mit SPEICHERN – so gibt es keine Versionsflut, und Versionsnummern bleiben die Stände, die der Kunde bewusst notiert.
- Der Entwurf hängt am Sitzungsschlüssel (128 Bit Zufall, `localStorage` `terrassenplaner.sitzung`), nicht an der Nummer. Er kennt die Konfiguration, auf der er beruht.
- „Weiterplanen“ setzt den Entwurf fort, sonst die gemerkte Konfiguration. Schließt der Kunde den Browser ohne SPEICHERN, geht nichts verloren.
- Ist der Server nicht erreichbar, bleibt das Zwischenspeichern still; die nächste Änderung versucht es erneut.

## Gefunden

- **ObjectBox lehnt Rückrufe mit Rückgabetyp `Never` ab** („Given transaction callback always fails“): Ein Test-Rückruf, der nur wirft, muss bedingt werfen. Echte Fehler (unbekannte Nummer) brechen die Transaktion ab und kommen unverändert heraus.
- Verschachtelte Schreibtransaktionen: `Datenbank.speichere` innerhalb von `Datenbank.transaktion` schließt sich der äußeren an; ein Fehler verwirft beide Schreibvorgänge samt Protokolleinträgen.
- Die App-Tests laufen ohne native ObjectBox-Bibliothek (Flutter findet `libobjectbox` nicht). Der Dienst hängt deshalb an der Schnittstelle `KonfigurationsSpeicher`; die App-Tests nutzen einen Speicher im Arbeitsspeicher, ObjectBox prüfen die Server-Tests.
- Kopfzeile: Mit SPEICHERN und LADEN braucht sie mit Beschriftung 1627 px (Englisch). Beschriftete Knöpfe gibt es deshalb erst ab 1680 px (`Kopfzeile.textAb`), darunter Symbole mit Tooltip.
- Der Eingangsdialog erscheint erst, nachdem der Server nach einem Entwurf gefragt wurde. `pumpAndSettle` wartet nicht auf das Netz; die Smoke-Tests starten die App deshalb über `integration_test/start.dart` (`starteApp` wartet auf den Dialog).
- Ohne `PLANER_DATENVERZEICHNIS` (Entwicklung, Smoke-Tests) speichert der Router nur im Arbeitsspeicher (`memory:`) und warnt beim Start.

## Betrieb

- Router und Auth-Server haben je eine eigene Datenbank, weil ObjectBox nur einen Prozess je Datenbank erlaubt:
  - systemd: `/var/lib/terrassenplaner/planer-router/datenbank`;
  - Container: Volume `router-daten`, `/daten/datenbank`.
  - Molecule prüft in beiden Szenarien, dass `data.mdb` angelegt ist.
- Offen: Sicherung der Konfigurationen (ObjectBox-Sicherung mit M10-03), Datenbank-Metriken des Routers für Prometheus, Aufräumen abgelaufener Entwürfe.

## Benchmark

`server.Konfiguration.speichernLaden`: Eine typische Planung (drei Flächen: O-Form, L-Form, Rechteck zweifach) wird als neue Version gespeichert und wieder geladen – zwei RPC-Rundläufe über den Router, ObjectBox auf der Platte. Vorwert in `benchmarks/baseline-lokal.json`.
