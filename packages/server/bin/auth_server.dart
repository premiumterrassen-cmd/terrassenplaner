import 'dart:async';
import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Auth-Server (connectanum_auth_server) als eigener Prozess.
/// Mitarbeiter-Zugänge liegen in ObjectBox (`PLANER_DATENVERZEICHNIS`);
/// `PLANER_MITARBEITER_DATEI` (JSON) wird beim Start übernommen.
Future<void> main() async {
  final umgebung = Platform.environment;
  final einstellungen = AuthServerEinstellungen.ausUmgebung(umgebung);
  final verzeichnis = umgebung['PLANER_DATENVERZEICHNIS'];
  final datei = umgebung['PLANER_MITARBEITER_DATEI'];
  final datenbank = verzeichnis == null
      ? null
      : Datenbank.oeffne(
          verzeichnis,
          knoten: umgebung['PLANER_KNOTEN'] ?? Platform.localHostname,
        );
  final MitarbeiterQuelle mitarbeiter;
  if (datenbank != null) {
    final quelle = DatenbankMitarbeiter(datenbank);
    if (datei != null) {
      quelle.uebernimm(MitarbeiterVerzeichnis.ausDatei(datei).alle);
    }
    mitarbeiter = quelle;
  } else {
    mitarbeiter = datei == null
        ? MitarbeiterVerzeichnis.leer()
        : MitarbeiterVerzeichnis.ausDatei(datei);
  }
  final auth = await AuthServerProzess.starte(
    einstellungen,
    mitarbeiter: mitarbeiter,
  );
  stdout.writeln(
    'Auth-Server bereit – ${einstellungen.listen}, '
    'Datenbank ${verzeichnis ?? '(keine)'}, Health ${einstellungen.healthListen}',
  );
  await _warteAufStoppsignal();
  await auth.stoppe();
  datenbank?.schliesse();
  stdout.writeln('Auth-Server beendet');
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
