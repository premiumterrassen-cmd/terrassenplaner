import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'planer_rahmen.dart';

/// Unterpunkt 7.1 (M5-08): Verschnitt und „Benötigte Dielen“ der ganzen
/// Planung, wie der Server sie aus der Verlegung rechnet – Anzahl je
/// Lieferlänge, bei mehreren Belägen je Artikelnummer. Die Auswahl von
/// Verschnittvarianten folgt mit M9-01.
class DielenlisteAnzeige extends StatelessWidget {
  const DielenlisteAnzeige({required this.berechnung, super.key});

  final BerechnungsSteuerung berechnung;

  /// „48 × 500 cm“ – Länge in cm wie in der Planungsunterlage.
  static String zeile(PlanerTexte t, Lieferposition p) =>
      '${p.anzahl} × ${zahlText(t, p.laenge.cm, '0.#')} cm';

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final liste = berechnung.dielenliste;
    if (liste.isEmpty) {
      return Text(key: const ValueKey('dielenliste-leer'), t.keineDielen);
    }
    final belaege = {for (final p in liste) p.belag};
    return Column(
      key: const ValueKey('dielenliste'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.verschnitt(Kennzahlen.prozent(t, berechnung.verschnitt))),
        const SizedBox(height: PlanerAbstand.klein),
        Text(t.benoetigteDielen),
        for (final belag in belaege) ...[
          if (belaege.length > 1)
            Text(
              belag.wert,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          for (final p in liste)
            if (p.belag == belag) Text(zeile(t, p)),
        ],
      ],
    );
  }
}
