import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'planer_app.dart';
import 'src/einstellungen/einstellungs_speicher.dart';
import 'src/einstellungen/lokale_einstellungen.dart';
import 'src/modell3d/modell3d_seite.dart';
import 'src/sprache/sprache.dart';
import 'src/verbindung/planer_verbindung.dart';
import 'src/verbindung/wamp_adresse.dart';

void main() {
  final adresse = wampAdresse(
    Uri.base,
    vorgabe: const String.fromEnvironment('PLANER_WAMP_URL'),
  );
  final verbindung = PlanerVerbindung(adresse);
  // Nur Bedienungseinstellungen im Browser (M3-09).
  final einstellungen = LokaleEinstellungen(browserSpeicher());
  // Prototyp der 3D-Vorschau (M3-10): …/?prototyp=3d
  if (Uri.base.queryParameters['prototyp'] == '3d') {
    runApp(
      MaterialApp(
        onGenerateTitle: (context) => context.texte.modell3dTitel,
        locale: einstellungen.sprache().value,
        localizationsDelegates: PlanerTexte.localizationsDelegates,
        supportedLocales: SprachSteuerung.sprachen,
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
      berechne: verbindung.berechne,
      // Laden über den Server folgt mit M9-05; eine geladene Konfiguration
      // wird für „Weiterplanen“ gemerkt (M3-09).
      laden: einstellungen.merkend(
        (stand) =>
            Future.error(UnsupportedError('Laden folgt mit M9-05: $stand')),
      ),
      gespeichert: () async => einstellungen.letzteKonfiguration(),
      sprache: einstellungen.sprache(),
      darstellung: einstellungen.darstellung(),
    ),
  );
}
