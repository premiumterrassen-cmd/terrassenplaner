# WAMP-Router (M0-07, 02.10.2026)

## Aufbau

- `packages/server/lib/src/router/router_einstellungen.dart` – Betriebsparameter (Host, Port, WebSocket-Pfad, Realm, Health-Adresse) aus Umgebungsvariablen `PLANER_*`; erzeugt die `RouterSettings` von `connectanum_router` 3.0.0-beta.5 per Builder-API (typisiert und testbar statt YAML).
- `packages/server/lib/src/router/planer_router.dart` – startet `NativeTransportRuntime` + `Router`, liefert die gebundenen Ports, beendet geordnet (`RouterBinding.dispose()` = Drain).
- Realm `de.robinienwelt.terrassenplaner`, WebSocket unter `/ws`, Health unter `http://<PLANER_HEALTH_LISTEN>/healthz` (200 bereit, 503 beim Start/Drain).
- **Vorläufig** anonyme Anmeldung mit vollen Rechten im Planer-Realm – Rollen und Rechte folgen in M0-08 (#8).

## Erkenntnisse

- Die native Transportschicht (`ct_ffi`, Rust) holt sich der Build-Hook von `connectanum_router`/`connectanum_client` automatisch als vorgebautes Release `v3.0.0-beta.5` von GitHub (konsultaner/connectanum-dart), wenn kein Rust installiert ist. Für reproduzierbare Builds kann der Release-Tag in der Wurzel-`pubspec.yaml` unter `hooks.user_defines` fest gesetzt werden.
- `dart build cli` erzeugt ein Bündel `build/server/bundle/{bin,lib}` mit der nativen Bibliothek – das ist das Deploy-Artefakt.
- Der Health-Endpunkt entsteht über `withOpenMetricsHttpRoutes()` als zusätzlicher HTTP-Listener; er wird im Deployment nicht nach außen freigegeben (nur Traefik-intern bzw. für Überwachung).
- **connectanum_bench** ist laut eigener Beschreibung ein internes Werkzeug des connectanum-Projekts und braucht einen Rust-Orchestrator; für uns ungeeignet. Stattdessen eigener Benchmark `server.Router.rpcRundlauf` (benchmark_harness) über die echte Router-Konfiguration.
- Erster Messwert (MacBook, lokal): ≈ 5,1 ms je RPC-Rundlauf (JSON über den Dart-WebSocket-Client). Für Bedienung ausreichend; in M10-02 (Lasttest) prüfen, ob MessagePack oder der native WebSocket-Client des connectanum-Pakets nennenswert schneller ist.

## Upgrade auf 3.0.0-beta.6 (03.10.2026, #103)

- Alle connectanum-Pakete gemeinsam auf beta.6; native Transportschicht als Release `v3.0.0-beta.6`.
- Neu: Sperrdatei `connectanum_native_runtime.lock` im temporären Verzeichnis – eine Transportschicht je `TMPDIR` (betrifft Diensttrennung Router/Auth-Server, siehe authentifizierung.md).
- `connectanum_auth_server` prüft Dienst-Zugangsdaten (Auth-Token) jetzt vor allem anderen; `authenticate.hello` ohne Token antwortet mit `status: failure` statt Schemafehler.
- Remote-Auth-Delegation an einen Auth-Server in einem eigenen Prozess funktioniert (Mitarbeiter-Anmeldung per `wamp-scram`).
