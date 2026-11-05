import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'steuerung.dart';

/// Unterpunkt „Befestigungsart“ (Fachkonzept 2.6, M5-09): die zum Belag
/// passenden Arten – genutet mit Clips, glattkant direkt oder mit
/// Abstandshaltern verschraubt – und die Befestigungsartikel mit Anzahl.
/// Was wählbar ist und was gebraucht wird, rechnet der Server (B-094,
/// B-090); die App zeigt es nur an.
class BefestigungsartWahl extends StatelessWidget {
  const BefestigungsartWahl({
    required this.planung,
    required this.onGeaendert,
    this.berechnung,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Berechnung des Servers; ohne sie keine Auswahl.
  final BerechnungsSteuerung? berechnung;

  /// Meldet eine Änderung der Befestigungsart (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([planung, berechnung]),
    builder: (context, _) {
      final t = context.texte;
      final bedarf =
          berechnung?.ergebnis?.befestigung ?? Befestigungsbedarf.keiner;
      if (bedarf.arten.isEmpty) {
        return Text(
          t.befestigungOhneDielen,
          key: const ValueKey('befestigung'),
        );
      }
      return Column(
        key: const ValueKey('befestigung'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final art in bedarf.arten)
                ChoiceChip(
                  key: ValueKey('befestigungsart-${art.name}'),
                  label: Text(befestigungsartText(t, art)),
                  selected: art == bedarf.art,
                  onSelected: (an) {
                    if (an) {
                      planung.setze(planung.aktuell.mitBefestigungsart(art));
                      onGeaendert();
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: PlanerAbstand.klein),
          Text(t.befestigungspunkte(bedarf.punkte)),
          for (final m in bedarf.mittel)
            Text(
              t.befestigungsmittel(m.anzahl, m.titel),
              key: ValueKey('befestigungsmittel-${m.nummer.wert}'),
            ),
        ],
      );
    },
  );
}

String befestigungsartText(PlanerTexte t, Befestigungsart a) => switch (a) {
  Befestigungsart.clips => t.befestigungsartClips,
  Befestigungsart.verschraubt => t.befestigungsartVerschraubt,
  Befestigungsart.verschraubtMitAbstandshaltern =>
    t.befestigungsartAbstandshalter,
};
