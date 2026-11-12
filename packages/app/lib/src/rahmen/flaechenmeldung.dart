import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'unterkonstruktion.dart';

/// Meldungen zu den Maßen im Schritt Grundriss: zur Größe der Fläche
/// (Planungskern v6 Regel 1.7) – Fehler in der Fehlerfarbe, Hinweise mit
/// Info-Zeichen – und zu unplausiblen Kanten unter 10 cm oder über 30 m
/// (Planungskern v7 Regel 9.6, Hinweise). Fläche und Ecken rechnet der
/// Server, die Grenzen stehen im domain-Paket (`pruefeFlaeche`,
/// `pruefeKanten`).
class FlaechenMeldung extends StatelessWidget {
  const FlaechenMeldung({required this.berechnung, super.key});

  final BerechnungsSteuerung berechnung;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: berechnung,
    builder: (context, _) {
      final ergebnis = berechnung.ergebnis;
      final meldung = ergebnis?.flaechenmeldung;
      final kanten = ergebnis?.kantenwarnungen ?? const <Kantenwarnung>[];
      final t = context.texte;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (meldung != null)
            _zeile(
              context,
              ValueKey('flaechenmeldung-${meldung.name}'),
              flaechenmeldungText(t, meldung),
              fehler: meldung.fehler,
            ),
          for (final k in kanten)
            _zeile(
              context,
              ValueKey('kantenwarnung-${k.kante}'),
              kantenwarnungText(t, k),
              fehler: false,
            ),
        ],
      );
    },
  );

  static Widget _zeile(
    BuildContext context,
    Key key,
    String text, {
    required bool fehler,
  }) {
    final farbe = fehler ? context.farben.error : context.farben.primary;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: PlanerAbstand.klein),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(fehler ? Icons.error_outline : Icons.info_outline, color: farbe),
          const SizedBox(width: PlanerAbstand.klein),
          Expanded(
            child: Text(text, style: fehler ? TextStyle(color: farbe) : null),
          ),
        ],
      ),
    );
  }
}

/// Text der Meldung zur Fläche.
String flaechenmeldungText(PlanerTexte t, Flaechenmeldung m) => switch (m) {
  Flaechenmeldung.masseFalsch => t.flaechenmeldungMasseFalsch,
  Flaechenmeldung.unplausibelGross => t.flaechenmeldungUnplausibelGross,
  Flaechenmeldung.ungewoehnlich => t.flaechenmeldungUngewoehnlich,
};

/// Text der Warnung zu einer Kante (Planungskern v7 Regel 9.6).
String kantenwarnungText(PlanerTexte t, Kantenwarnung k) => switch (k.art) {
  Kantenmeldung.zuKurz => t.kantenwarnungZuKurz(k.kante, cmText(t, k.laenge)),
  Kantenmeldung.zuLang => t.kantenwarnungZuLang(k.kante, cmText(t, k.laenge)),
};
