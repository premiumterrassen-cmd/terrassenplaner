import 'dart:async';
import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Öffentlicher Planer-Router. Braucht einen laufenden Auth-Server
/// (bin/auth_server.dart) mit denselben Geheimnissen.
Future<void> main() async {
  final einstellungen = RouterEinstellungen.ausUmgebung(Platform.environment);
  final router = PlanerRouter.starte(einstellungen);
  stdout.writeln(
    '${startMeldung()} – WAMP ws://${einstellungen.host}:'
    '${router.webSocketPort}${einstellungen.webSocketPfad}, '
    'Realm ${einstellungen.realm}, Health ${einstellungen.healthListen}, '
    'Auth-Server ${einstellungen.authAdresse}',
  );
  await Future.any([
    ProcessSignal.sigint.watch().first,
    ProcessSignal.sigterm.watch().first,
  ]);
  await router.stoppe();
  stdout.writeln('Server beendet');
  // Native Threads der Transportschicht halten den Prozess sonst offen.
  exit(0);
}
