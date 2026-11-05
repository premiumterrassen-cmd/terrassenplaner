import 'package:flutter/material.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'steuerung.dart';
import 'zeichnung.dart';

/// Name der Seite [seite] wie in der Zeichnung: „A — B“.
String seitenname(int seite, int seitenzahl) =>
    '${ZeichnungsMaler.punktname(seite)} — '
    '${ZeichnungsMaler.punktname((seite + 1) % seitenzahl)}';

/// Schalter je Seite des Grundrisses als Chips: [gewaehlt] sagt, ob eine
/// Seite an ist, [waehlbar], ob sie in dieser Frage zur Wahl steht (eine
/// Seite hat nur eine Rolle, Fachkonzept 04). Ohne Seiten (Kreis) ein
/// Hinweis.
class Seitenwahl extends StatelessWidget {
  const Seitenwahl({
    required this.name,
    required this.seitenzahl,
    required this.gewaehlt,
    required this.onGewaehlt,
    this.waehlbar = _alle,
    super.key,
  });

  /// Teil der Schlüssel der Chips (`<name>-<seite>`).
  final String name;
  final int seitenzahl;
  final bool Function(int seite) gewaehlt;
  final bool Function(int seite) waehlbar;
  final void Function(int seite, bool an) onGewaehlt;

  static bool _alle(int seite) => true;

  @override
  Widget build(BuildContext context) {
    if (seitenzahl == 0) {
      return Text(context.texte.ohneSeiten, key: ValueKey('$name-leer'));
    }
    return Wrap(
      spacing: PlanerAbstand.klein,
      children: [
        for (var i = 0; i < seitenzahl; i++)
          if (waehlbar(i) || gewaehlt(i))
            FilterChip(
              key: ValueKey('$name-$i'),
              label: Text(seitenname(i, seitenzahl)),
              selected: gewaehlt(i),
              onSelected: (an) => onGewaehlt(i, an),
            ),
      ],
    );
  }
}

/// Unterpunkt „Angrenzende Bauelemente“ (Fachkonzept 4.1, M7-01): Seiten,
/// die an bestehende Bauelemente grenzen, werden grau dargestellt. Jede
/// Wahl ist ein Schritt für Rückgängig/Wiederherstellen.
class AngrenzendWahl extends StatelessWidget {
  const AngrenzendWahl({
    required this.planung,
    required this.onGeaendert,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planung,
    builder: (context, _) {
      final stand = planung.aktuell;
      return Column(
        key: const ValueKey('angrenzend'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.texte.angrenzendFrage),
          Seitenwahl(
            name: 'angrenzend',
            seitenzahl: stand.seitenzahl,
            gewaehlt: stand.anschluss.grenztAn,
            onGewaehlt: (seite, an) {
              planung.setze(planung.aktuell.mitAngrenzend(seite, an: an));
              onGeaendert();
            },
          ),
        ],
      );
    },
  );
}
