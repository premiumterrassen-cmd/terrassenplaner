import 'dart:async';
import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Öffentlicher Planer-Router. Braucht einen laufenden Auth-Server
/// (bin/auth_server.dart) mit denselben Geheimnissen.
Future<void> main() async {
  final einstellungen = RouterEinstellungen.ausUmgebung(Platform.environment);
  final router = PlanerRouter.starte(einstellungen);
  final hallo = await HalloDienst.starte(router);
  final modell3d = await Modell3dDienst.starte(router);
  final planung = await PlanungsDienst.starte(router);
  final artikel = await ArtikelDienst.starte(router, ArtikeldateiQuelle.leer);
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
