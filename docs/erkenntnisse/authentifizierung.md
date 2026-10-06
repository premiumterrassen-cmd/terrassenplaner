# Authentifizierung (M0-08, 02./03.10.2026)

## Aufbau

| Rolle | Wer | Anmeldung | Rechte (Prefix) |
|---|---|---|---|
| `anonymous` (Kunde) | Besucher des Planers | anonym | `call`, `subscribe` auf `de.robinienwelt.terrassenplaner.kunde.` |
| `mitarbeiter` | Team | `wamp-scram` über `connectanum_auth_server` | zusätzlich `call`, `subscribe` auf `…mitarbeiter.` |
| `dienst` | Backend-Dienste auf unserem Server | interne Router-Sitzung (`PlanerRouter.dienstSitzung`), keine Netzwerk-Anmeldung | `register`, `unregister`, `publish`, `call`, `subscribe` auf `de.robinienwelt.terrassenplaner.` |

- **Zwei getrennte Dienste** (Diensttrennung, Vorgabe Alexander 03.10.2026): `bin/server.dart` (Planer-Router) und `bin/auth_server.dart` (eigener Router mit Realm `connectanum.authenticate`, an dem `connectanum_auth_server` `authenticate.hello/authenticate/abort` über eine interne Sitzung anbietet). Der Planer-Router delegiert Mitarbeiter-Anmeldungen per WAMP (`remote`-Authenticator mit `rpc`) an den RawSocket-Listener des Auth-Servers (`PLANER_AUTH_LISTEN`/`PLANER_AUTH_ADRESSE`, Standard `127.0.0.1:8082`, nur Ticket-Anmeldung). Gemeinsame Geheimnisse: `PLANER_AUTH_TOKEN`, `PLANER_AUTH_DIENST_TICKET` (Pflicht).
- Mitarbeiter-Zugänge: nur abgeleitete SCRAM-Schlüssel (PBKDF2, 100.000 Iterationen, zufälliges Salt), vorläufig aus `PLANER_MITARBEITER_DATEI` (JSON-Liste), später ObjectBox (M0-15). Eintrag erzeugen: `dart run bin/mitarbeiter_zugang.dart <authid>` (Passwort verdeckt).

## Befunde (für Alexander als Maintainer)

Stand beta.5; mit beta.6 (03.10.2026) funktioniert die Delegation an einen Auth-Server in einem **eigenen Prozess**.

1. **Methodenname SCRAM:** `ScramAuthentication.getName()` im Client liefert `wamp-scram`, der `ScramAuthenticatorFactory` im Router heißt `scram`. `resolveAuthenticatorSelection` gleicht die Client-Methoden 1:1 mit den Realm-Methoden ab → mit Realm-Methode `scram` kommt „No acceptable authentication method“. Workaround: Realm-/Listener-Methode `wamp-scram` mit `authenticator`-Verweis auf eine Definition vom Typ `scram` bzw. `remote`.
2. **Anonyme Rolle nicht konfigurierbar:** Bei Methode `anonymous` liefert `resolveAuthenticatorSelection` fest `AuthenticatorSelection.anonymous()` ohne Optionen – `authrole` aus der Authenticator-Definition wird ignoriert, die Rolle ist immer `anonymous`. Workaround: Kunden-Rolle heißt technisch `anonymous`.
3. **Remote-Delegation per WAMP nicht erreichbar:** Mit `rpc`-Delegate (RawSocket, JSON, Ticket-Dienstanmeldung) auf einen Listener desselben Routers, an dem `AuthServerProcedureBinding` die Prozeduren über eine interne Sitzung registriert hat, endet jede SCRAM-Anmeldung nach ~5 s mit „Remote authentication service unavailable“. `AuthServer.onHello` wird nie erreicht. Gegenprobe: Ein Client im Hauptisolat meldet sich mit demselben Ticket über denselben Listener an (Rolle `auth-client`) und erreicht `authenticate.hello` (Antwort: Schemafehler für leere Nutzlast – also registriert und erlaubt). Ein In-Process-Delegate über `RemoteAuthenticatorRegistry.register` funktioniert nicht, weil die Router-Worker eigene Isolates ohne diese Registrierung sind. Längere Wartezeit oder zwei Worker ändern nichts.
4. **Health-Route an gleicher Adresse:** `withOpenMetricsHttpRoutes()` vergleicht die Listener-Adresse als Text; bei `host:0` für WebSocket und Health hängen die Routen am WebSocket-Listener. In Tests deshalb getrennte feste Ports.
5. **Eine native Transportschicht je Prozess:** Zwei Router in einem Testprozess → „runtime already started“; Server-Tests laufen deshalb mit `concurrency: 1`.

6. **beta.6 – Delegation im selben Prozess:** Delegiert ein Router an einen Auth-Server, der im selben Prozess am selben Router hängt, bleibt es bei „Remote authentication service unavailable“ (~5 s). Mit getrenntem Prozess läuft es – passt zur gewünschten Diensttrennung.
7. **beta.6 – Sperrdatei:** `connectanum_native_runtime.lock` galt rechnerweit je `TMPDIR`. **In beta.7 behoben** (Sperre je Prozess) – Router und Auth-Server teilen sich wieder ein `TMPDIR`; `PrivateTmp=yes` bleibt in den systemd-Units nur noch als Härtung.
8. **Prozessende – Korrektur 06.10.2026:** Der offene Prozess nach dem Stopp lag (zumindest auch) an unserem Code: Mit `Future.any([sigint.watch().first, sigterm.watch().first])` blieb das nicht ausgelöste Signal-Abo aktiv. Beide Programme melden jetzt beide Signale ab und beenden sich von selbst (beta.7 geprüft, ohne `exit(0)`).

Tests: `zugriff_test.dart` startet den Auth-Server als echten zweiten Prozess (`dart run bin/auth_server.dart`) und prüft Kunde und Mitarbeiter Ende-zu-Ende.
