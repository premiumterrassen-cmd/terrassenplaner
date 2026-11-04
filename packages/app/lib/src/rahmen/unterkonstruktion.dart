import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'steuerung.dart';

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
