import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';

/// Meldung zur Größe der Fläche (Planungskern v6 Regel 1.7) unter den Maßen
/// im Schritt Grundriss: Fehler in der Fehlerfarbe, Hinweise mit
/// Info-Zeichen. Die Fläche rechnet der Server, die Grenzen stehen im
/// domain-Paket (`pruefeFlaeche`).
class FlaechenMeldung extends StatelessWidget {
  const FlaechenMeldung({required this.berechnung, super.key});

  final BerechnungsSteuerung berechnung;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: berechnung,
    builder: (context, _) {
      final meldung = berechnung.ergebnis?.flaechenmeldung;
      if (meldung == null) return const SizedBox.shrink();
      final farbe = meldung.fehler
          ? context.farben.error
          : context.farben.primary;
      return Padding(
        key: ValueKey('flaechenmeldung-${meldung.name}'),
        padding: const EdgeInsets.only(top: PlanerAbstand.klein),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              meldung.fehler ? Icons.error_outline : Icons.info_outline,
              color: farbe,
            ),
            const SizedBox(width: PlanerAbstand.klein),
            Expanded(
              child: Text(
                flaechenmeldungText(context.texte, meldung),
                style: meldung.fehler ? TextStyle(color: farbe) : null,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Text der Meldung zur Fläche.
String flaechenmeldungText(PlanerTexte t, Flaechenmeldung m) => switch (m) {
  Flaechenmeldung.masseFalsch => t.flaechenmeldungMasseFalsch,
  Flaechenmeldung.unplausibelGross => t.flaechenmeldungUnplausibelGross,
  Flaechenmeldung.ungewoehnlich => t.flaechenmeldungUngewoehnlich,
};
