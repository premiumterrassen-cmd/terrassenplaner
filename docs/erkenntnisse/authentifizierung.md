# Authentifizierung (M0-08, 02.10.2026)

## Aufbau

| Rolle | Wer | Anmeldung | Rechte (Prefix) |
|---|---|---|---|
| `anonymous` (Kunde) | Besucher des Planers | anonym | `call`, `subscribe` auf `de.robinienwelt.terrassenplaner.kunde.` |
| `mitarbeiter` | Team | `wamp-scram` über `connectanum_auth_server` | zusätzlich `call`, `subscribe` auf `…mitarbeiter.` |
| `dienst` | Backend-Dienste auf unserem Server | interne Router-Sitzung (`PlanerRouter.dienstSitzung`), keine Netzwerk-Anmeldung | `register`, `unregister`, `publish`, `call`, `subscribe` auf `de.robinienwelt.terrassenplaner.` |

- Der Auth-Server (`connectanum_auth_server`) bietet `authenticate.hello/authenticate/abort` im Realm `connectanum.authenticate` über eine interne Sitzung an. Der Router delegiert Mitarbeiter-Anmeldungen per WAMP (`remote`-Authenticator mit `rpc`) über einen **internen RawSocket-Listener** (`PLANER_AUTH_LISTEN`, Standard `127.0.0.1:8082`, nur Ticket-Anmeldung mit zufälligem Dienst-Ticket je Start). So kann der Auth-Server später ohne Umbau in einen eigenen Prozess umziehen.
- Mitarbeiter-Zugänge: nur abgeleitete SCRAM-Schlüssel (PBKDF2, 100.000 Iterationen, zufälliges Salt), vorläufig aus `PLANER_MITARBEITER_DATEI` (JSON-Liste), später ObjectBox (M0-15). Eintrag erzeugen: `dart run bin/mitarbeiter_zugang.dart <authid>` (Passwort verdeckt).

## Befunde in connectanum 3.0.0-beta.5 (für Alexander als Maintainer)

1. **Methodenname SCRAM:** `ScramAuthentication.getName()` im Client liefert `wamp-scram`, der `ScramAuthenticatorFactory` im Router heißt `scram`. `resolveAuthenticatorSelection` gleicht die Client-Methoden 1:1 mit den Realm-Methoden ab → mit Realm-Methode `scram` kommt „No acceptable authentication method“. Workaround: Realm-/Listener-Methode `wamp-scram` mit `authenticator`-Verweis auf eine Definition vom Typ `scram` bzw. `remote`.
2. **Anonyme Rolle nicht konfigurierbar:** Bei Methode `anonymous` liefert `resolveAuthenticatorSelection` fest `AuthenticatorSelection.anonymous()` ohne Optionen – `authrole` aus der Authenticator-Definition wird ignoriert, die Rolle ist immer `anonymous`. Workaround: Kunden-Rolle heißt technisch `anonymous`.
3. **Remote-Delegation per WAMP nicht erreichbar:** Mit `rpc`-Delegate (RawSocket, JSON, Ticket-Dienstanmeldung) auf einen Listener desselben Routers, an dem `AuthServerProcedureBinding` die Prozeduren über eine interne Sitzung registriert hat, endet jede SCRAM-Anmeldung nach ~5 s mit „Remote authentication service unavailable“. `AuthServer.onHello` wird nie erreicht. Gegenprobe: Ein Client im Hauptisolat meldet sich mit demselben Ticket über denselben Listener an (Rolle `auth-client`) und erreicht `authenticate.hello` (Antwort: Schemafehler für leere Nutzlast – also registriert und erlaubt). Ein In-Process-Delegate über `RemoteAuthenticatorRegistry.register` funktioniert nicht, weil die Router-Worker eigene Isolates ohne diese Registrierung sind. Längere Wartezeit oder zwei Worker ändern nichts.
4. **Health-Route an gleicher Adresse:** `withOpenMetricsHttpRoutes()` vergleicht die Listener-Adresse als Text; bei `host:0` für WebSocket und Health hängen die Routen am WebSocket-Listener. In Tests deshalb getrennte feste Ports.
5. **Eine native Transportschicht je Prozess:** Zwei Router in einem Testprozess → „runtime already started“; Server-Tests laufen deshalb mit `concurrency: 1`.

Bis zur Klärung von Punkt 3 sind die Router-Tests für Mitarbeiter-Anmeldungen übersprungen (`zugriff_test.dart`), Einheiten-Tests für Zugänge, Verzeichnis, Zugangsdaten-Provider und Rollen laufen.
