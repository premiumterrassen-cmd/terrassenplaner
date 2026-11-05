import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'steuerung.dart';
import 'zeichnung.dart';

/// Wert in cm mit höchstens einer Nachkommastelle im Format der Sprache
/// („8,6“).
String cmText(PlanerTexte t, Millimeter mm) => zahlText(t, mm.cm, '0.#');

/// Liest eine Eingabe in cm („8,6“ oder „8.6“) als ganze mm; `null`, wenn
/// es keine Zahl ist.
Millimeter? cmAusText(String text) {
  final cm = num.tryParse(text.trim().replaceAll(',', '.'));
  return cm == null || !cm.isFinite ? null : Millimeter.ausCm(cm);
}

/// Unterpunkt „Art der Terrasse“ (Fachkonzept 3.1, M6-01): normale
/// Terrasse (Vorgabe), Hochterrasse oder vorhandene UK mit ihrer
/// Vorgabehöhe; bei vorhandener UK dazu das Feld „Spannweite“. Jede Wahl
/// ist ein Schritt für Rückgängig/Wiederherstellen.
class TerrassenartWahl extends StatelessWidget {
  const TerrassenartWahl({
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
      final t = context.texte;
      final stand = planung.aktuell;
      final gewaehlt = stand.terrassenart;
      return Column(
        key: const ValueKey('terrassenart'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final art in Terrassenart.values)
                ChoiceChip(
                  key: ValueKey('terrassenart-${art.name}'),
                  label: Text(terrassenartText(t, art)),
                  selected: art == gewaehlt,
                  onSelected: (an) {
                    if (an) {
                      planung.setze(planung.aktuell.mitTerrassenart(art));
                      onGeaendert();
                    }
                  },
                ),
            ],
          ),
          Text(t.vorgabehoehe(cmText(t, gewaehlt.vorgabehoehe))),
          if (gewaehlt.mitSpannweite) ...[
            const SizedBox(height: PlanerAbstand.klein),
            Text(t.spannweiteFrage),
            CmFeld(
              key: const ValueKey('spannweite'),
              titel: t.spannweite,
              wert: stand.spannweite,
              gueltig: Terrassenart.spannweiteGueltig,
              fehler: t.spannweiteUngueltig,
              onGeaendert: (mm) {
                planung.setze(planung.aktuell.mitSpannweite(mm));
                onGeaendert();
              },
            ),
          ],
        ],
      );
    },
  );
}

/// Unterpunkt „Höhenpunkte“ (Fachkonzept 3.2, M6-02): ohne Gefälle eine
/// Höhe für alle Eckpunkte, mit Gefälle je Eckpunkt A, B … – gemessen von
/// Oberkante Belag bis Boden, Vorgabe die Höhe der Terrassenart. Prüfung,
/// Aufbauhöhe und Hinweise kommen vom Server (`pruefeHoehen`).
class HoehenpunkteWahl extends StatelessWidget {
  const HoehenpunkteWahl({
    required this.planung,
    required this.onGeaendert,
    this.berechnung,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Berechnung des Servers; ohne sie keine Aufbauhöhe und keine Hinweise.
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
      final punkte = berechnung?.ergebnis?.hoehenpunkte;
      return Column(
        key: const ValueKey('hoehenpunkte'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.hoehenpunkteHilfe),
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final (name, mit, text) in [
                ('ohne', false, t.ohneGefaelle),
                ('mit', true, t.mitGefaelle),
              ])
                ChoiceChip(
                  key: ValueKey('gefaelle-$name'),
                  label: Text(text),
                  selected: stand.gefaelle == mit,
                  onSelected: (an) {
                    if (an) _setze(planung.aktuell.mitGefaelle(mit));
                  },
                ),
            ],
          ),
          if (stand.gefaelle)
            for (final (i, hoehe) in stand.hoehen.indexed)
              CmFeld(
                key: ValueKey('hoehe-$i'),
                titel: ZeichnungsMaler.punktname(i),
                wert: hoehe,
                gueltig: Planungsstand.hoeheGueltig,
                fehler: t.hoeheUngueltig,
                onGeaendert: (mm) => _setze(planung.aktuell.mitEckhoehe(i, mm)),
              )
          else
            CmFeld(
              key: const ValueKey('hoehe-alle'),
              titel: t.hoeheAlle,
              wert: stand.alleHoehe,
              gueltig: Planungsstand.hoeheGueltig,
              fehler: t.hoeheUngueltig,
              onGeaendert: (mm) => _setze(planung.aktuell.mitHoehe(mm)),
            ),
          if (punkte?.aufbauhoehe case final a?)
            Padding(
              padding: const EdgeInsets.only(top: PlanerAbstand.klein),
              child: Text(t.aufbauhoehe(cmText(t, a))),
            ),
          if (punkte != null && punkte.gedreht)
            _Hinweis(key: const ValueKey('uk-gedreht'), text: t.ukGedreht),
          if (punkte != null && punkte.korrigiert)
            _Hinweis(
              key: const ValueKey('hoehe-korrigiert'),
              text: t.hoeheKorrigiert(cmText(t, punkte.mindesthoehe!)),
              warnung: true,
            ),
        ],
      );
    },
  );
}

/// Unterpunkt „Untergrund“ (Fachkonzept 3.5, M6-04): Schotter (Vorgabe),
/// Beton oder Bitumenabdichtung – nur Information für die Planer, ohne
/// Wirkung auf die Berechnung (R-C07). Jede Wahl ist ein Schritt für
/// Rückgängig/Wiederherstellen.
class UntergrundWahl extends StatelessWidget {
  const UntergrundWahl({
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
      final t = context.texte;
      final gewaehlt = planung.aktuell.untergrund;
      return Column(
        key: const ValueKey('untergrund'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.untergrundFrage),
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final u in Untergrund.values)
                ChoiceChip(
                  key: ValueKey('untergrund-${u.name}'),
                  label: Text(untergrundText(t, u)),
                  selected: u == gewaehlt,
                  onSelected: (an) {
                    if (an) {
                      planung.setze(planung.aktuell.mitUntergrund(u));
                      onGeaendert();
                    }
                  },
                ),
            ],
          ),
          _Hinweis(text: t.untergrundHinweis),
        ],
      );
    },
  );
}

/// Hinweis mit Symbol; als [warnung] in der Fehlerfarbe.
class _Hinweis extends StatelessWidget {
  const _Hinweis({required this.text, this.warnung = false, super.key});

  final String text;
  final bool warnung;

  @override
  Widget build(BuildContext context) {
    final farbe = warnung ? context.farben.error : context.farben.onSurface;
    return Padding(
      padding: const EdgeInsets.only(top: PlanerAbstand.klein),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warnung ? Icons.warning_amber : Icons.info_outline,
            color: farbe,
          ),
          const SizedBox(width: PlanerAbstand.klein),
          Expanded(
            child: Text(text, style: TextStyle(color: farbe)),
          ),
        ],
      ),
    );
  }
}

/// Eingabefeld in cm: der aktuelle Wert steht als Platzhalter darin, Enter
/// übernimmt eine gültige Eingabe, sonst erscheint [fehler].
class CmFeld extends StatefulWidget {
  const CmFeld({
    required this.titel,
    required this.wert,
    required this.gueltig,
    required this.fehler,
    required this.onGeaendert,
    super.key,
  });

  final String titel;

  /// Aktueller Wert.
  final Millimeter wert;

  /// Prüft eine Eingabe in mm.
  final bool Function(Millimeter mm) gueltig;

  /// Meldung bei ungültiger Eingabe.
  final String fehler;

  final ValueChanged<Millimeter> onGeaendert;

  @override
  State<CmFeld> createState() => _CmFeldState();
}

class _CmFeldState extends State<CmFeld> {
  final _feld = TextEditingController();
  String? _fehler;

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  void _uebernimm(String text) {
    final mm = cmAusText(text);
    if (mm == null || !widget.gueltig(mm)) {
      setState(() => _fehler = widget.fehler);
      return;
    }
    widget.onGeaendert(mm);
    _feld.clear();
    setState(() => _fehler = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return Padding(
      padding: const EdgeInsets.only(top: PlanerAbstand.klein),
      child: TextField(
        key: const ValueKey('feld'),
        controller: _feld,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: widget.titel,
          hintText: cmText(t, widget.wert),
          suffixText: 'cm',
          errorText: _fehler,
        ),
        onSubmitted: _uebernimm,
      ),
    );
  }
}

String terrassenartText(PlanerTexte t, Terrassenart a) => switch (a) {
  Terrassenart.normal => t.terrassenartNormal,
  Terrassenart.hochterrasse => t.terrassenartHochterrasse,
  Terrassenart.vorhandeneUk => t.terrassenartVorhandeneUk,
};

String untergrundText(PlanerTexte t, Untergrund u) => switch (u) {
  Untergrund.schotter => t.untergrundSchotter,
  Untergrund.beton => t.untergrundBeton,
  Untergrund.bitumen => t.untergrundBitumen,
};
