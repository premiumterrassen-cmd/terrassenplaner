import 'dart:async';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Öffentlicher Planer-Router. Braucht einen laufenden Auth-Server
/// (bin/auth_server.dart) mit denselben Geheimnissen.
Future<void> main() async {
  final einstellungen = RouterEinstellungen.ausUmgebung(Platform.environment);
  final router = PlanerRouter.starte(einstellungen);
  final hallo = await HalloDienst.starte(router);
  final modell3d = await Modell3dDienst.starte(router);
  final artikel = await ArtikelDienst.starte(router, ArtikeldateiQuelle.leer);
  Artikel? unterkonstruktion(Planungsstand stand) =>
      artikel.unterkonstruktion(stand.belag, stand.unterkonstruktion);
  final planung = await PlanungsDienst.starte(
    router,
    belag: artikel.belag,
    regelwerk: () => artikel.regelwerk,
    unterkonstruktion: unterkonstruktion,
  );
  // Export für GrandTotal (M9-08) aus der Materialliste.
  final export = await ExportDienst.starte(
    router,
    belag: artikel.belag,
    regelwerk: () => artikel.regelwerk,
    unterkonstruktion: unterkonstruktion,
  );
  // Konfigurationen (M9-05) in einer eigenen ObjectBox-Datenbank – ObjectBox
  // erlaubt einen Prozess je Datenbank, der Auth-Server hat seine eigene.
  // Ohne Verzeichnis (Entwicklung, Smoke-Tests) nur im Arbeitsspeicher.
  final verzeichnis = Platform.environment['PLANER_DATENVERZEICHNIS'];
  if (verzeichnis == null) {
    stderr.writeln('WARNUNG: Konfigurationen nur im Arbeitsspeicher');
  }
  final datenbank = Datenbank.oeffne(
    verzeichnis ?? 'memory:terrassenplaner',
    knoten: Platform.environment['PLANER_KNOTEN'] ?? Platform.localHostname,
  );
  // Betrieb (M10-03): Datenbank-Kennzahlen für Prometheus (nur lokal) und
  // Sicherung im laufenden Betrieb auf SIGUSR1 (Rolle `sicherung`).
  final umgebung = Platform.environment;
  final metrikAdresse = umgebung['PLANER_DATENBANK_METRIKEN'];
  final metriken = verzeichnis == null || metrikAdresse == null
      ? null
      : await MetrikServer.starte(
          metrikAdresse,
          () => datenbankMetriken(
            datenbank.kennzahlen(),
            dienst: 'planer-router',
          ),
        );
  final sicherungsZiel = umgebung['PLANER_SICHERUNG_ZIEL'];
  final sicherung = verzeichnis == null || sicherungsZiel == null
      ? null
      : Sicherungsdienst.starte(
          datenbank,
          sicherungsZiel,
          ProcessSignal.sigusr1.watch(),
          protokoll: stdout.writeln,
        );
  final konfiguration = await KonfigurationsDienst.starte(
    router,
    Konfigurationsablage(datenbank),
  );
  final quelle = ArtikeldateiQuelle(
    Platform.environment[ArtikeldateiQuelle.umgebungsvariable] ??
        ArtikeldateiQuelle.standardPfad,
  );
  await artikel.aktualisiere(quelle, stdout.writeln);
  if (artikel.datei.version == ArtikeldateiQuelle.leer.version) {
    stderr.writeln('WARNUNG: keine Artikeldatei unter ${quelle.pfad}');
  }
  // Neue Artikeldaten wirken ohne Neustart und ohne App-Update (M2-06).
  final nachladen = Timer.periodic(
    const Duration(seconds: 30),
    (_) => artikel.aktualisiere(quelle, stdout.writeln),
  );
  stdout.writeln(
    '${startMeldung()} – WAMP ws://${einstellungen.host}:'
    '${router.webSocketPort}${einstellungen.webSocketPfad}, '
    'Realm ${einstellungen.realm}, Health ${einstellungen.healthListen}, '
    'Auth-Server ${einstellungen.authAdresse}',
  );
  await _warteAufStoppsignal();
  nachladen.cancel();
  await artikel.stoppe();
  await planung.stoppe();
  await export.stoppe();
  await konfiguration.stoppe();
  await sicherung?.stoppe();
  await metriken?.stoppe();
  datenbank.schliesse();
  await modell3d.stoppe();
  await hallo.stoppe();
  await router.stoppe();
  stdout.writeln('Server beendet');
}

/// Wartet auf SIGINT oder SIGTERM und meldet beide Signale wieder ab, damit
/// sich der Prozess danach von selbst beendet.
Future<void> _warteAufStoppsignal() async {
  final signal = Completer<void>();
  final abos = [
    for (final s in [ProcessSignal.sigint, ProcessSignal.sigterm])
      s.watch().listen((_) {
        if (!signal.isCompleted) signal.complete();
      }),
  ];
  await signal.future;
  for (final abo in abos) {
    await abo.cancel();
  }
}
