import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Erzeugt einen Eintrag für die Mitarbeiter-Datei (PLANER_MITARBEITER_DATEI).
/// Aufruf: `dart run bin/mitarbeiter_zugang.dart <authid>`
/// Das Passwort wird verdeckt abgefragt und nicht gespeichert.
Future<void> main(List<String> argumente) async {
  if (argumente.length != 1) {
    stderr.writeln('Aufruf: dart run bin/mitarbeiter_zugang.dart <authid>');
    exitCode = 64;
    return;
  }
  stdout.write('Passwort für ${argumente.single}: ');
  stdin.echoMode = false;
  final passwort = stdin.readLineSync() ?? '';
  stdin.echoMode = true;
  stdout.writeln();
  final zugang = await MitarbeiterZugang.ableiten(
    authId: argumente.single,
    passwort: passwort,
  );
  stdout.writeln(jsonEncode(zugang.alsJson()));
}
