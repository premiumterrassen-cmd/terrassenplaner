import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'anschluss.dart';
import 'berechnung_steuerung.dart';
import 'steuerung.dart';
import 'unterkonstruktion.dart';

/// Unterpunkt „Treppen“ (Fachkonzept 5.1, M7-05): „Treppe hinzufügen“ legt
/// einen Block „Treppe 1“ an (weitere möglich). Je Treppe Start (nur freie
/// Seiten – nicht am Bauelement, ohne Rinne), Abstand vom Startpunkt,
/// Breite (reguläre Treppe), Konstruktionsart, Treppenart, Stufen und bei
/// der Fächertreppe das Podest; Treppenmaße (L × B × H) und Hinweise kommen
/// vom Server. Jede Änderung ist ein Schritt für Rückgängig/Wiederherstellen.
class TreppenWahl extends StatelessWidget {
  const TreppenWahl({
    required this.planung,
    required this.onGeaendert,
    this.berechnung,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Berechnung des Servers mit Treppenmaßen und Hinweisen.
  final BerechnungsSteuerung? berechnung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  void _setze(Planungsstand stand) {
    planung.setze(stand);
    onGeaendert();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([planung, berechnung]),
    builder: (context, _) {
      final t = context.texte;
      final stand = planung.aktuell;
      final anschluss = berechnung?.ergebnis?.anschluss;
      return Column(
        key: const ValueKey('treppen'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.treppenFrage),
          if (stand.seitenzahl == 0)
            Text(t.ohneSeiten, key: const ValueKey('treppen-leer'))
          else ...[
            for (final (i, treppe) in stand.treppen.indexed)
              TreppenBlock(
                key: ValueKey('treppe-$i'),
                nummer: i,
                treppe: treppe,
                stand: stand,
                masse: anschluss?.treppen.elementAtOrNull(i)?.masse,
                onGeaendert: (neu) => _setze(planung.aktuell.mitTreppe(i, neu)),
                onEntfernen: () => _setze(planung.aktuell.ohneTreppe(i)),
              ),
            OutlinedButton.icon(
              key: const ValueKey('treppe-hinzufuegen'),
              icon: const Icon(Icons.add),
              label: Text(t.treppeHinzufuegen),
              onPressed: () => _setze(planung.aktuell.mitNeuerTreppe()),
            ),
          ],
          if (anschluss?.meldungen.contains(Anschlussmeldung.treppeNichtFrei) ??
              false)
            Hinweis(
              key: const ValueKey('anschluss-treppeNichtFrei'),
              text: t.meldungTreppeNichtFrei,
              warnung: true,
            ),
        ],
      );
    },
  );
}

/// Ein Block „Treppe n“ mit allen Feldern einer Treppe.
class TreppenBlock extends StatelessWidget {
  const TreppenBlock({
    required this.nummer,
    required this.treppe,
    required this.stand,
    required this.onGeaendert,
    required this.onEntfernen,
    this.masse,
    super.key,
  });

  /// Index der Treppe (0 = „Treppe 1“).
  final int nummer;
  final Treppe treppe;

  /// Planungsstand für die Seiten zur Auswahl.
  final Planungsstand stand;

  /// Treppenmaße vom Server; `null`, solange keine Berechnung vorliegt.
  final Treppenmasse? masse;
  final ValueChanged<Treppe> onGeaendert;
  final VoidCallback onEntfernen;

  String get _k => 'treppe-$nummer';

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final anschluss = stand.anschluss;
    Widget chips<T>(
      String name,
      List<(T, String)> werte,
      T wert,
      Treppe Function(T) neu,
    ) => Wrap(
      spacing: PlanerAbstand.klein,
      children: [
        for (final (w, text) in werte)
          ChoiceChip(
            key: ValueKey('$_k-$name-$w'),
            label: Text(text),
            selected: w == wert,
            onSelected: (an) {
              if (an) onGeaendert(neu(w));
            },
          ),
      ],
    );
    CmFeld feld(
      String name,
      String titel,
      Millimeter wert,
      bool Function(Millimeter) erlaubt,
      Treppe Function(Millimeter) neu,
    ) => CmFeld(
      key: ValueKey('$_k-$name'),
      titel: titel,
      wert: wert,
      gueltig: erlaubt,
      fehler: t.treppeUngueltig,
      onGeaendert: (mm) => onGeaendert(neu(mm)),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: PlanerAbstand.klein),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(t.treppeName(nummer + 1)),
        trailing: IconButton(
          key: ValueKey('$_k-entfernen'),
          tooltip: t.treppeEntfernen,
          icon: const Icon(Icons.delete_outline),
          onPressed: onEntfernen,
        ),
        childrenPadding: const EdgeInsets.all(PlanerAbstand.klein),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.treppeStart),
          Seitenwahl(
            name: '$_k-seite',
            seitenzahl: stand.seitenzahl,
            gewaehlt: (seite) => seite == treppe.seite,
            waehlbar: (seite) =>
                !anschluss.grenztAn(seite) && anschluss.rinneAn(seite) == null,
            onGewaehlt: (seite, an) {
              if (an) onGeaendert(treppe.mit(seite: seite));
            },
          ),
          feld(
            'abstand',
            t.treppeAbstand,
            treppe.abstand,
            Treppe.abstandErlaubt,
            (mm) => treppe.mit(abstand: mm),
          ),
          Text(t.treppeKonstruktionsart),
          chips(
            'bau',
            [
              (Treppenbau.fundament, t.treppeFundament),
              (Treppenbau.konstruktion, t.treppeKonstruktion),
            ],
            treppe.bau,
            (b) => treppe.mit(bau: b),
          ),
          Text(t.treppeArt),
          chips(
            'art',
            [
              (Treppenart.regulaer, t.treppeRegulaer),
              (Treppenart.zweiteilig, t.treppeZweiteilig),
              (Treppenart.dreiteilig, t.treppeDreiteilig),
            ],
            treppe.art,
            (a) => treppe.mit(art: a),
          ),
          if (treppe.art == Treppenart.regulaer)
            feld(
              'breite',
              t.treppeBreite,
              treppe.breite,
              Treppe.massErlaubt,
              (mm) => treppe.mit(breite: mm),
            ),
          Text(t.treppeIndividuell),
          chips(
            'individuell',
            [(false, t.nein), (true, t.ja)],
            treppe.individuell,
            (i) => treppe.mit(individuell: i),
          ),
          Row(
            children: [
              Expanded(child: Text(t.treppeAnzahl)),
              IconButton(
                key: ValueKey('$_k-weniger'),
                icon: const Icon(Icons.remove),
                onPressed: Treppe.anzahlErlaubt(treppe.anzahl - 1)
                    ? () => onGeaendert(treppe.mit(anzahl: treppe.anzahl - 1))
                    : null,
              ),
              Text('${treppe.anzahl}', key: ValueKey('$_k-anzahl')),
              IconButton(
                key: ValueKey('$_k-mehr'),
                icon: const Icon(Icons.add),
                onPressed: Treppe.anzahlErlaubt(treppe.anzahl + 1)
                    ? () => onGeaendert(treppe.mit(anzahl: treppe.anzahl + 1))
                    : null,
              ),
            ],
          ),
          Text(t.treppeStufenmasse),
          if (treppe.individuell)
            for (final (i, s) in treppe.stufenmasse.indexed) ...[
              Text(t.treppeStufe(i + 1)),
              ..._stufe(t, '$_k-stufe-$i', s, (m) => treppe.mitStufe(i, m)),
            ]
          else
            ..._stufe(
              t,
              '$_k-stufe',
              treppe.stufe,
              (m) => treppe.mit(stufe: m),
            ),
          if (treppe.art.mitPodest) ...[
            Text(t.treppePodest),
            feld(
              'podest-tiefe',
              t.treppeTiefe,
              treppe.podest.tiefe,
              Treppe.massErlaubt,
              (mm) => treppe.mit(
                podest: (
                  tiefe: mm,
                  breite: treppe.podest.breite,
                  hoehe: treppe.podest.hoehe,
                ),
              ),
            ),
            feld(
              'podest-breite',
              t.treppeBreite,
              treppe.podest.breite,
              Treppe.massErlaubt,
              (mm) => treppe.mit(
                podest: (
                  tiefe: treppe.podest.tiefe,
                  breite: mm,
                  hoehe: treppe.podest.hoehe,
                ),
              ),
            ),
            feld(
              'podest-hoehe',
              t.treppeHoehe,
              treppe.podest.hoehe,
              Treppe.hoeheErlaubt,
              (mm) => treppe.mit(
                podest: (
                  tiefe: treppe.podest.tiefe,
                  breite: treppe.podest.breite,
                  hoehe: mm,
                ),
              ),
            ),
          ],
          if (masse case final m?)
            Padding(
              padding: const EdgeInsets.only(top: PlanerAbstand.klein),
              child: Text(
                t.treppeMasse(
                  cmText(t, m.laenge),
                  cmText(t, m.breite),
                  cmText(t, m.hoehe),
                ),
                key: ValueKey('$_k-masse'),
              ),
            ),
        ],
      ),
    );
  }

  /// Felder Tiefe und Höhe einer Stufe.
  List<Widget> _stufe(
    PlanerTexte t,
    String schluessel,
    Stufenmass mass,
    Treppe Function(Stufenmass) neu,
  ) => [
    CmFeld(
      key: ValueKey('$schluessel-tiefe'),
      titel: t.treppeTiefe,
      wert: mass.tiefe,
      gueltig: Treppe.tiefeErlaubt,
      fehler: t.treppeUngueltig,
      onGeaendert: (mm) => onGeaendert(neu((tiefe: mm, hoehe: mass.hoehe))),
    ),
    CmFeld(
      key: ValueKey('$schluessel-hoehe'),
      titel: t.treppeHoehe,
      wert: mass.hoehe,
      gueltig: Treppe.hoeheErlaubt,
      fehler: t.treppeUngueltig,
      onGeaendert: (mm) => onGeaendert(neu((tiefe: mass.tiefe, hoehe: mm))),
    ),
  ];
}
