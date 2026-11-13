import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'steuerung.dart';

/// Meldungen des Servers zum Belag (M5-10, Fachkonzept 2.8) unter dem
/// Unterpunkt [unterpunkt] des Schritts Terrassenbelag – dort, wo die
/// Eingabe passiert. Warnungen in der Fehlerfarbe, Hinweise mit Info-Zeichen;
/// geprüft wird nur auf dem Server (`belagmeldungen`).
class BelagMeldungen extends StatelessWidget {
  const BelagMeldungen({
    required this.berechnung,
    required this.planung,
    required this.unterpunkt,
    super.key,
  });

  final BerechnungsSteuerung berechnung;
  final PlanungsSteuerung planung;
  final int unterpunkt;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: berechnung,
    builder: (context, _) {
      final t = context.texte;
      final meldungen = [
        for (final m
            in berechnung.ergebnis?.belagmeldungen ?? const <Belagmeldung>[])
          if (m.unterpunkt == unterpunkt) m,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in meldungen)
            Padding(
              key: ValueKey('belagmeldung-${m.name}'),
              padding: const EdgeInsets.only(top: PlanerAbstand.klein),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    m.warnung ? Icons.warning_amber : Icons.info_outline,
                    color: m.warnung
                        ? context.farben.error
                        : context.farben.primary,
                  ),
                  const SizedBox(width: PlanerAbstand.klein),
                  Expanded(
                    child: Text(
                      belagmeldungText(t, m, planung.aktuell),
                      style: m.warnung
                          ? TextStyle(color: context.farben.error)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// Text einer Meldung; die Länge nennt die erzwungene Länge des [stand].
String belagmeldungText(
  PlanerTexte t,
  Belagmeldung m,
  Planungsstand stand,
) => switch (m) {
  Belagmeldung.belagErsetzt => t.belagmeldungBelagErsetzt,
  Belagmeldung.belagOhneMasse => t.belagmeldungOhneMasse,
  Belagmeldung.systemdieleOhneVerlegung => t.belagmeldungSystemdiele,
  Belagmeldung.flaecheKleinerAlsBelag => t.belagmeldungFlaecheKleiner,
  Belagmeldung.fliesenSpitzeWinkel => t.belagmeldungFliesenSpitzeWinkel,
  Belagmeldung.bombierungEmpfohlen => t.belagmeldungBombierung,
  Belagmeldung.laengeNichtLieferbar => t.belagmeldungLaengeNichtLieferbar(
    (stand.dielenlaenge?.mm ?? 0) ~/ 10,
  ),
  Belagmeldung.laengenvorgabeNichtErfuellbar => t.belagmeldungLaengenvorgabe,
  Belagmeldung.befestigungsartNichtMoeglich => t.belagmeldungBefestigungsart,
  Belagmeldung.befestigungOhneArtikel => t.belagmeldungOhneBefestigung,
  Belagmeldung.schraubeZuKurz => t.belagmeldungSchraubeZuKurz,
};
