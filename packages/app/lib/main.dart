import 'package:flutter/material.dart';

import 'planer_app.dart';
import 'src/verbindung/planer_verbindung.dart';
import 'src/verbindung/wamp_adresse.dart';

void main() {
  final adresse = wampAdresse(
    Uri.base,
    vorgabe: const String.fromEnvironment('PLANER_WAMP_URL'),
  );
  runApp(PlanerApp(hallo: PlanerVerbindung(adresse).hallo));
}
