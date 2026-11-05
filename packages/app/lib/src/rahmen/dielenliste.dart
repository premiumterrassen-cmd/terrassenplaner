import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'planer_rahmen.dart';
import 'steuerung.dart';

/// Unterpunkt 7.1 (M5-08, M9-01): Verschnitt und „Benötigte Dielen“ der
/// ganzen Planung, wie der Server sie rechnet – Anzahl je Lieferlänge, bei
/// mehreren Belägen je Artikelnummer.
///
/// Ohne Optimierung zeigt sie die Verteilung je Teilfläche (M5-08), einen
/// Hinweis und „Optimierung erstellen“. Mit Optimierung (Planung, nicht
/// Server: so bleibt die Wahl auch ohne Dielen sichtbar) bis zu drei
/// Karten der Varianten, die gewählte hervorgehoben; ein Klick wählt eine
/// andere („Die Verschnittauswahl wurde geändert!“), „Optimierung
/// zurücksetzen“ kehrt zur Verteilung je Teilfläche zurück. Gerechnet wird
/// alles auf dem Server.
class DielenlisteAnzeige extends StatelessWidget {
  const DielenlisteAnzeige({
    required this.berechnung,
    required this.planung,
    super.key,
  });

  final BerechnungsSteuerung berechnung;
  final PlanungsSteuerung planung;

  /// „48 × 500 cm“ – Länge in cm wie in der Planungsunterlage.
  static String zeile(PlanerTexte t, Lieferposition p) =>
      '${p.anzahl} × ${zahlText(t, p.laenge.cm, '0.#')} cm';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([berechnung, planung]),
    builder: (context, _) => planung.planung.verschnittvariante == 0
        ? _ohneOptimierung(context)
        : _mitOptimierung(context),
  );

  Widget _ohneOptimierung(BuildContext context) {
    final t = context.texte;
    final liste = berechnung.dielenliste;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (liste.isEmpty)
          Text(key: const ValueKey('dielenliste-leer'), t.keineDielen)
        else ...[
          _dielen(
            context,
            liste,
            berechnung.verschnitt,
            const ValueKey('dielenliste'),
          ),
          const SizedBox(height: PlanerAbstand.klein),
          Text(
            key: const ValueKey('verschnitt-nicht-optimiert'),
            t.verschnittNichtOptimiert,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: PlanerAbstand.klein),
        FilledButton(
          key: const ValueKey('optimierung-erstellen'),
          onPressed: () => _waehle(1),
          child: Text(t.optimierungErstellen),
        ),
      ],
    );
  }

  Widget _mitOptimierung(BuildContext context) {
    final t = context.texte;
    final ergebnis = berechnung.ergebnis;
    final varianten = ergebnis?.verschnittvarianten ?? const [];
    final farben = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (varianten.isEmpty)
          Text(key: const ValueKey('dielenliste-leer'), t.keineDielen),
        for (final (i, v) in varianten.indexed)
          Card(
            key: ValueKey('verschnittvariante-${i + 1}'),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: i + 1 == ergebnis?.verschnittvariante
                    ? farben.primary
                    : farben.outlineVariant,
                width: i + 1 == ergebnis?.verschnittvariante ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: () => _wechsle(context, i + 1),
              child: Padding(
                padding: const EdgeInsets.all(PlanerAbstand.klein),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.verschnittvariante(i + 1),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    _dielen(context, v.dielen, v.verschnitt, null),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: PlanerAbstand.klein),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const ValueKey('optimierung-zuruecksetzen'),
            onPressed: () => _waehle(0),
            child: Text(t.optimierungZuruecksetzen),
          ),
        ),
      ],
    );
  }

  void _waehle(int variante) =>
      planung.setzePlanung(planung.planung.mitVerschnittvariante(variante));

  /// Wählt Variante [variante]; nur ein Wechsel meldet sich (Fachkonzept
  /// 7.1).
  void _wechsle(BuildContext context, int variante) {
    if (variante == berechnung.ergebnis?.verschnittvariante) return;
    _waehle(variante);
    final t = context.texte;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        key: const ValueKey('verschnittauswahl-geaendert'),
        content: Text(t.verschnittauswahlGeaendert),
        action: SnackBarAction(label: t.schliessen, onPressed: () {}),
      ),
    );
  }

  /// Verschnitt und „Benötigte Dielen“, bei mehreren Belägen je
  /// Artikelnummer.
  static Widget _dielen(
    BuildContext context,
    List<Lieferposition> liste,
    double? verschnitt,
    Key? key,
  ) {
    final t = context.texte;
    final belaege = {for (final p in liste) p.belag};
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.verschnitt(Kennzahlen.prozent(t, verschnitt))),
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
