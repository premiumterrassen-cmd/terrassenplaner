import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'steuerung.dart';
import 'unterkonstruktion.dart';
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

/// Unterpunkt „Verblendung“ (Fachkonzept 4.2, M7-02): verblendete Seiten
/// werden gelb dargestellt; Seiten an Bauelementen stehen nicht zur Wahl.
/// Beim Kreis gibt es nur „Fläche verblenden“. Die Hinweise (Unterlüftung,
/// Belagstärke, Höhenunterschied, Artikel) kommen vom Server. Jede Wahl ist
/// ein Schritt für Rückgängig/Wiederherstellen.
class VerblendungWahl extends StatelessWidget {
  const VerblendungWahl({
    required this.planung,
    required this.onGeaendert,
    this.berechnung,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Berechnung des Servers mit den Hinweisen zum Anschluss.
  final BerechnungsSteuerung? berechnung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  void _setze(int seite, bool an) {
    planung.setze(planung.aktuell.mitVerblendet(seite, an: an));
    onGeaendert();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([planung, berechnung]),
    builder: (context, _) {
      final t = context.texte;
      final stand = planung.aktuell;
      final anschluss = stand.anschluss;
      final meldungen =
          berechnung?.ergebnis?.anschluss.meldungen ??
          const <Anschlussmeldung>[];
      return Column(
        key: const ValueKey('verblendung'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.verblendungFrage),
          if (stand.grundriss is KreisGrundriss)
            FilterChip(
              key: const ValueKey('verblendet-flaeche'),
              label: Text(t.flaecheVerblenden),
              selected: anschluss.verblendetAn(0),
              onSelected: (an) => _setze(0, an),
            )
          else
            Seitenwahl(
              name: 'verblendet',
              seitenzahl: stand.seitenzahl,
              gewaehlt: anschluss.verblendetAn,
              waehlbar: (seite) => !anschluss.grenztAn(seite),
              onGewaehlt: _setze,
            ),
          Hinweis(text: t.verblendungHinweis),
          for (final m in meldungen)
            Hinweis(
              key: ValueKey('anschluss-${m.name}'),
              text: anschlussmeldungText(t, m),
              warnung: true,
            ),
        ],
      );
    },
  );
}

/// Text eines Hinweises zum Terrassenanschluss.
String anschlussmeldungText(PlanerTexte t, Anschlussmeldung m) => switch (m) {
  Anschlussmeldung.unterlueftung => t.meldungUnterlueftung,
  Anschlussmeldung.keinHoehenunterschied => t.meldungKeinHoehenunterschied,
  Anschlussmeldung.belagstaerke => t.meldungBelagstaerke,
  Anschlussmeldung.ohneVerblendungsartikel => t.meldungOhneVerblendungsartikel,
};
