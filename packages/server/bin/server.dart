import 'dart:async';
import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Mitarbeiter-Zugänge aus `PLANER_MITARBEITER_DATEI` (JSON), sonst keine.
MitarbeiterVerzeichnis _mitarbeiter() {
  final datei = Platform.environment['PLANER_MITARBEITER_DATEI'];
  return datei == null
      ? MitarbeiterVerzeichnis.leer()
      : MitarbeiterVerzeichnis.ausDatei(datei);
}

Future<void> main() async {
  final einstellungen = RouterEinstellungen.ausUmgebung(Platform.environment);
  final router = await PlanerRouter.starte(
    einstellungen,
    mitarbeiter: _mitarbeiter(),
  );
  stdout.writeln(
    '${startMeldung()} – WAMP ws://${einstellungen.host}:'
    '${router.webSocketPort}${einstellungen.webSocketPfad}, '
    'Realm ${einstellungen.realm}, Health ${einstellungen.healthListen}',
  );
  await Future.any([
    ProcessSignal.sigint.watch().first,
    ProcessSignal.sigterm.watch().first,
  ]);
  await router.stoppe();
  stdout.writeln('Server beendet');
}
