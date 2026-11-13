import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'steuerung.dart';
import 'unterkonstruktion.dart';

/// Name der Seite [seite] von [stand] wie in der Zeichnung: „A — B“
/// (Eckbuchstaben R-E03).
String seitenname(Planungsstand stand, int seite) =>
    '${stand.grundriss.eckname(seite)} — '
    '${stand.grundriss.eckname((seite + 1) % stand.seitenzahl)}';

/// Schalter je Seite des Grundrisses als Chips: [gewaehlt] sagt, ob eine
/// Seite an ist, [waehlbar], ob sie in dieser Frage zur Wahl steht (eine
/// Seite hat nur eine Rolle, Fachkonzept 04). Ohne Seiten (Kreis) ein
/// Hinweis.
class Seitenwahl extends StatelessWidget {
  const Seitenwahl({
    required this.name,
    required this.stand,
    required this.gewaehlt,
    required this.onGewaehlt,
    this.waehlbar = _alle,
    super.key,
  });

  /// Teil der Schlüssel der Chips (`<name>-<seite>`).
  final String name;

  /// Planungsstand mit den Seiten und den Namen ihrer Ecken.
  final Planungsstand stand;
  final bool Function(int seite) gewaehlt;
  final bool Function(int seite) waehlbar;
  final void Function(int seite, bool an) onGewaehlt;

  static bool _alle(int seite) => true;

  @override
  Widget build(BuildContext context) {
    final seitenzahl = stand.seitenzahl;
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
              label: Text(seitenname(stand, i)),
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
            stand: stand,
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
              stand: stand,
              gewaehlt: anschluss.verblendetAn,
              waehlbar: (seite) => !anschluss.grenztAn(seite),
              onGewaehlt: _setze,
            ),
          for (final seite in anschluss.verblendet)
            BlendeJeSeite(
              key: ValueKey('blende-$seite'),
              planung: planung,
              seite: seite,
              onGeaendert: onGeaendert,
            ),
          if (anschluss.verblendet.isNotEmpty)
            Hinweis(text: t.blendeJeSeiteHilfe),
          Hinweis(text: t.verblendungHinweis),
          for (final m in meldungen)
            if (zurVerblendung.contains(m))
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

/// Seitenblende je Seite (Planungskern v7, Regel 9.4): eigene Blendenhöhe
/// (leer = automatisch, die niedrigste Stelle der Seite) und Teilstücke von
/// … bis … cm ab der ersten Ecke der Seite; beim Kreis nur die Höhe. Was
/// daraus folgt, rechnet der Server. Jede Änderung ist ein Schritt für
/// Rückgängig/Wiederherstellen.
class BlendeJeSeite extends StatelessWidget {
  const BlendeJeSeite({
    required this.planung,
    required this.seite,
    required this.onGeaendert,
    super.key,
  });

  final PlanungsSteuerung planung;
  final int seite;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  void _setze(Planungsstand stand) {
    planung.setze(stand);
    onGeaendert();
  }

  void _teile(List<({Millimeter von, Millimeter bis})> teile) =>
      _setze(planung.aktuell.mitBlendenteilen(seite, teile));

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final stand = planung.aktuell;
    final kreis = stand.grundriss is KreisGrundriss;
    final hoehe = stand.anschluss.blendenhoeheAn(seite);
    final teile = stand.anschluss.teileAn(seite);
    final ecke = kreis ? '' : stand.grundriss.eckname(seite);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: PlanerAbstand.klein),
        Text(
          kreis ? t.flaecheVerblenden : t.blendeSeite(seitenname(stand, seite)),
        ),
        Row(
          children: [
            Expanded(
              child: CmFeld(
                key: ValueKey('blende-$seite-hoehe'),
                titel: t.blendenhoehe,
                wert: hoehe,
                ohneWert: t.blendenhoeheAutomatisch,
                gueltig: Planungsstand.hoeheGueltig,
                fehler: t.hoeheUngueltig,
                onGeaendert: (mm) =>
                    _setze(planung.aktuell.mitBlendenhoehe(seite, mm)),
              ),
            ),
            if (hoehe != null)
              IconButton(
                key: ValueKey('blende-$seite-automatisch'),
                tooltip: t.blendenhoeheZuruecksetzen,
                icon: const Icon(Icons.undo),
                onPressed: () =>
                    _setze(planung.aktuell.mitBlendenhoehe(seite, null)),
              ),
          ],
        ),
        if (!kreis) ...[
          for (final (i, teil) in teile.indexed) ...[
            Row(
              children: [
                Expanded(child: Text(t.blendenteil(i + 1))),
                IconButton(
                  key: ValueKey('blende-$seite-teil-$i-entfernen'),
                  tooltip: t.blendenteilEntfernen,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _teile([...teile]..removeAt(i)),
                ),
              ],
            ),
            CmFeld(
              key: ValueKey('blende-$seite-teil-$i-von'),
              titel: t.blendenteilVon(ecke),
              wert: teil.von,
              gueltig: (mm) => Planungsstand.blendenteilGueltig(mm, teil.bis),
              fehler: t.blendenteilUngueltig,
              onGeaendert: (mm) =>
                  _teile([...teile]..[i] = (von: mm, bis: teil.bis)),
            ),
            CmFeld(
              key: ValueKey('blende-$seite-teil-$i-bis'),
              titel: t.blendenteilBis(ecke),
              wert: teil.bis,
              gueltig: (mm) => Planungsstand.blendenteilGueltig(teil.von, mm),
              fehler: t.blendenteilUngueltig,
              onGeaendert: (mm) =>
                  _teile([...teile]..[i] = (von: teil.von, bis: mm)),
            ),
          ],
          TextButton.icon(
            key: ValueKey('blende-$seite-teil-hinzufuegen'),
            icon: const Icon(Icons.add),
            label: Text(t.blendenteilHinzufuegen),
            onPressed: () => _teile([
              ...teile,
              (
                von: const Millimeter(0),
                bis: Millimeter(stand.seitenlaenge(seite).round()),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

/// Hinweise, die unter 4.2 Verblendung stehen.
const zurVerblendung = {
  Anschlussmeldung.unterlueftung,
  Anschlussmeldung.keinHoehenunterschied,
  Anschlussmeldung.blendeFehlt,
};

/// Text eines Hinweises zum Terrassenanschluss.
String anschlussmeldungText(PlanerTexte t, Anschlussmeldung m) => switch (m) {
  Anschlussmeldung.unterlueftung => t.meldungUnterlueftung,
  Anschlussmeldung.keinHoehenunterschied => t.meldungKeinHoehenunterschied,
  Anschlussmeldung.ohneRinnenartikel => t.meldungOhneRinnenartikel,
  Anschlussmeldung.treppeNichtFrei => t.meldungTreppeNichtFrei,
  Anschlussmeldung.blendeFehlt => t.meldungBlendeFehlt,
  Anschlussmeldung.rinneNichtMoeglich => t.meldungRinneNichtMoeglich,
  Anschlussmeldung.rinnenfarbeFehlt => t.meldungRinnenfarbeFehlt,
  Anschlussmeldung.rinnenmontage => t.meldungRinnenmontage,
  Anschlussmeldung.eckwinkelFehlt => t.meldungEckwinkelFehlt,
};

/// Hinweise, die unter 4.3 Entwässerungsrinnen stehen; alle außer der
/// Annahme zur Montage sind Warnungen.
const zurRinne = [
  Anschlussmeldung.ohneRinnenartikel,
  Anschlussmeldung.rinneNichtMoeglich,
  Anschlussmeldung.rinnenfarbeFehlt,
  Anschlussmeldung.eckwinkelFehlt,
  Anschlussmeldung.rinnenmontage,
];

/// Text einer Rinnenfarbe (Planungskern v11, Regel 13.1.5).
String rinnenfarbeText(PlanerTexte t, Rinnenfarbe f) => switch (f) {
  Rinnenfarbe.eloxiert => t.rinnenfarbeEloxiert,
  Rinnenfarbe.anthrazit => t.rinnenfarbeAnthrazit,
};

/// Text einer Rinnenlage wie im alten Planer.
String rinnenlageText(PlanerTexte t, Rinnenlage l) => switch (l) {
  Rinnenlage.gesamteSeite => t.rinnenlageGesamteSeite,
  Rinnenlage.imElement => t.rinnenlageImElement,
  Rinnenlage.ausserhalbElement => t.rinnenlageAusserhalbElement,
  Rinnenlage.vorElement => t.rinnenlageVorElement,
};

/// Unterpunkt „Entwässerungsrinnen“ (Fachkonzept 4.3, M7-03): je Seite ein
/// Schalter – nicht an verblendeten Seiten, an Bauelementen schon (F38),
/// nur an geraden, waagerechten oder senkrechten Seiten ab 30 cm
/// (Planungskern v11, Regel 13.1.1, `rinneMoeglich`) –, danach die Lage
/// (Vorgabe „Gesamte Seite (innen)“) und mit einer Rinne die Farbe aller
/// Rinnen (eloxiert/anthrazit, Regel 13.1.5). Seiten mit Rinne werden blau
/// dargestellt. Jede Wahl ist ein Schritt für Rückgängig/Wiederherstellen.
class RinnenWahl extends StatelessWidget {
  const RinnenWahl({
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

  void _setze(int seite, Rinnenlage? lage) {
    planung.setze(planung.aktuell.mitRinne(seite, lage));
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
        key: const ValueKey('rinnen'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.rinnenFrage),
          Seitenwahl(
            name: 'rinne',
            stand: stand,
            gewaehlt: (seite) => anschluss.rinneAn(seite) != null,
            // eine gewählte Rinne bleibt abwählbar, auch wenn die Seite
            // nicht mehr passt
            waehlbar: (seite) =>
                anschluss.rinneAn(seite) != null ||
                (!anschluss.verblendetAn(seite) && rinneMoeglich(stand, seite)),
            onGewaehlt: (seite, an) =>
                _setze(seite, an ? Rinnenlage.gesamteSeite : null),
          ),
          for (final (:seite, :lage) in anschluss.rinnen) ...[
            const SizedBox(height: PlanerAbstand.klein),
            Text(t.rinnenLage(seitenname(stand, seite))),
            Wrap(
              spacing: PlanerAbstand.klein,
              children: [
                for (final l in Rinnenlage.values)
                  ChoiceChip(
                    key: ValueKey('rinne-$seite-${l.name}'),
                    label: Text(rinnenlageText(t, l)),
                    selected: l == lage,
                    onSelected: (an) {
                      if (an) _setze(seite, l);
                    },
                  ),
              ],
            ),
          ],
          if (anschluss.rinnen.isNotEmpty) ...[
            const SizedBox(height: PlanerAbstand.klein),
            Text(t.rinnenFarbe),
            Wrap(
              spacing: PlanerAbstand.klein,
              children: [
                for (final f in Rinnenfarbe.values)
                  ChoiceChip(
                    key: ValueKey('rinnenfarbe-${f.name}'),
                    label: Text(rinnenfarbeText(t, f)),
                    selected: f == anschluss.rinnenfarbe,
                    onSelected: (an) {
                      if (!an) return;
                      planung.setze(planung.aktuell.mitRinnenfarbe(f));
                      onGeaendert();
                    },
                  ),
              ],
            ),
          ],
          Hinweis(text: t.rinnenHinweis),
          for (final m in zurRinne)
            if (meldungen.contains(m))
              Hinweis(
                key: ValueKey('anschluss-${m.name}'),
                text: anschlussmeldungText(t, m),
                warnung: m != Anschlussmeldung.rinnenmontage,
              ),
        ],
      );
    },
  );
}
