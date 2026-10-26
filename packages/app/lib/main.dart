import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'planer_app.dart';
import 'src/modell3d/modell3d_seite.dart';
import 'src/verbindung/planer_verbindung.dart';
import 'src/verbindung/wamp_adresse.dart';

void main() {
  final adresse = wampAdresse(
    Uri.base,
    vorgabe: const String.fromEnvironment('PLANER_WAMP_URL'),
  );
  final verbindung = PlanerVerbindung(adresse);
  // Prototyp der 3D-Vorschau (M3-10): …/?prototyp=3d
  if (Uri.base.queryParameters['prototyp'] == '3d') {
    runApp(
      MaterialApp(
        title: Modell3dSeite.titel,
        home: Modell3dSeite(
          lade: () => verbindung.modell3dRechteck(
            const Millimeter(4000),
            const Millimeter(3000),
          ),
        ),
      ),
    );
    return;
  }
  runApp(
    PlanerApp(
      hallo: verbindung.hallo,
      // Laden über den Server folgt mit M9-05, der Browser-Zwischenspeicher
      // für „Weiterplanen“ mit M3-09.
      laden: (stand) =>
          Future.error(UnsupportedError('Laden folgt mit M9-05: $stand')),
      gespeichert: () async => null,
    ),
  );
}
