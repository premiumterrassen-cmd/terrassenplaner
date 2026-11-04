# Speichern und Laden (M9-05, 04.11.2026)

## Umsetzung

- **Konfigurationsdienst** (`packages/server/lib/src/dienste/konfigurations_dienst.dart`) im Router-Prozess mit vier Kunden-Prozeduren:
  - `konfiguration.speichern` `[inhalt]` bzw. `[inhalt, kennung]` → `[kennung, version]`;
  - `konfiguration.laden` `[kennung, version]` → `[inhalt]` (Kennung = Nummer mit Prüfcode, siehe unten);
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

## Prüfcode (M9-05b, Entscheidung Alexander 04.11.2026)

Die fortlaufenden Nummern `JJJJ-MM-TT-NNNN` lassen sich erraten. Laden und Fortführen verlangen deshalb Nummer **und** Prüfcode („mit einem kurzen Prüfcode absichern“).

- **Domain** (`packages/domain/lib/src/konfiguration/konfigurationskennung.dart`):
  - `Pruefcode`: 5 Zeichen aus `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (ohne 0, O, 1, I, L), also 31⁵ ≈ 28,6 Mio. Möglichkeiten je Nummer. `Pruefcode.zufaellig(Random)` erzeugt ihn, `gleicht` vergleicht in konstanter Zeit (XOR über alle Zeichen, kein frühes Ende).
  - `Konfigurationskennung` (Nummer + Prüfcode): Text `JJJJ-MM-TT-NNNN-XXXXX`. `Konfigurationskennung.lies` ist tolerant: Großschreibung, Leerraum und Trenner (`-`, `–`, `—`, `_`, `.`, `/`) werden vor dem Prüfen entfernt. Ist die Nummer lesbar, der Code aber falsch geschrieben oder fehlt er, wirft `lies` `PruefcodeUngueltig` (mit der Nummer).
  - `KonfigurationsStand` trägt jetzt die Kennung (`kennung`, `nummer`, `version`).
- **Server:**
  - `Konfiguration.pruefcode` (neue Property 13, nur angehängt). Die Schema-Version bleibt 1: M9-05 ist noch nirgends live, es gibt keine Datensätze ohne Prüfcode. Das Feld ist kein eingebettetes Dokument.
  - `Konfigurationsablage` erzeugt den Code beim Anlegen des Kopfes mit `Random.secure()` (im Test austauschbar) und prüft ihn beim Laden, beim weiteren Speichern und beim Merken eines Entwurfs mit Bezug.
  - Falscher Code und unbekannte Nummer werfen dasselbe `KonfigurationUnbekannt`. Der Dienst antwortet für beides mit `fehler.konfiguration_unbekannt` und `[nummer, version]`. Auch eine Kennung ohne oder mit falsch geschriebenem Code beim Laden gilt als unbekannt, nicht als ungültiger Aufruf.
  - WAMP: Alle Prozeduren nehmen und liefern statt der Nummer die Kennung (`speichern` → `[kennung, version]`, `laden` `[kennung, version]`, Entwurf mit `kennung`). Der Entwurf liefert seinen Bezug mit Code zurück. Das gibt nichts preis, denn der Sitzungsschlüssel ist selbst geheim und ein Bezug wird nur mit passendem Code gemerkt.
  - **Stelle für Mitarbeiter (M9-10):** `KonfigurationsDienst.darfOhnePruefcodeLaden(aufruf)` liefert vorerst immer `false`. Mit der Mitarbeiter-Anmeldung prüft sie die Rolle aus den Aufrufdetails und lässt `Konfigurationsablage.lies(…, ohnePruefcode: true)` zu. Für Mitarbeiter, die nur die Nummer kennen, muss M9-10 dann auch das Einlesen ohne Code im Dienst zulassen.
- **App:**
  - Der Hinweis nach SPEICHERN zeigt die Kennung. Der Ladedialog liest sie aus einem Feld.
  - Fehlt der Code oder ist er falsch geschrieben, zeigt die App sofort „unbekannt“, ohne den Server zu fragen.
  - `LokaleEinstellungen` merkt `JJJJ-MM-TT-NNNN-XXXXX/Version`. Ein alter Eintrag ohne Code gilt als keiner.
- **Smoke-Test** `speichern_laden_test.dart`: Laden mit verändertem letzten Zeichen → „unbekannt“; danach lädt die richtige Kennung (in Kleinschreibung).
- Offen: Schutz gegen massenhaftes Durchprobieren (Rate-Limit je Verbindung oder IP im Router oder in Traefik). Der Code macht Raten teuer, eine Bremse fehlt aber noch.

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
