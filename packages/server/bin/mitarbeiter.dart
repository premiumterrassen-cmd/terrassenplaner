import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Mitarbeiter-Konten verwalten (M9-10, docs/betrieb/mitarbeiter.md):
/// `mitarbeiter anlegen|passwort|sperren|entsperren <email>`,
/// `mitarbeiter liste`. Das Passwort kommt über stdin – am Terminal
/// verdeckt und zweimal –, nie als Argument.
Future<void> main(List<String> argumente) async {
  final verbindung = await MitarbeiterWerkzeug.verbinde(Platform.environment);
  final interaktiv = stdin.hasTerminal;
  exitCode = await MitarbeiterWerkzeug(
    rufe: verbindung.rufe,
    interaktiv: interaktiv,
    passwortLesen: (frage) {
      if (!interaktiv) return stdin.readLineSync();
      stdout.write(frage);
      stdin.echoMode = false;
      try {
        return stdin.readLineSync();
      } finally {
        stdin.echoMode = true;
        stdout.writeln();
      }
    },
    ausgabe: stdout.writeln,
    fehler: stderr.writeln,
  ).fuehreAus(argumente);
  await verbindung.schliesse();
}
