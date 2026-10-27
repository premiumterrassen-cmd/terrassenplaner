import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'steuerung.dart';

/// Terrassenmaße des Rechtecks (Fachkonzept 1.2, M4-02): A — B und B — C in
/// cm. Wie im alten Planer zeigen die Felder nur Platzhalter, die aktuellen
/// Maße stehen in der Zeichnung; Enter übernimmt den Wert in den
/// Planungsstand.
class RechteckMasse extends StatefulWidget {
  const RechteckMasse({
    required this.planung,
    required this.onGeaendert,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Meldet eine übernommene Eingabe (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  State<RechteckMasse> createState() => _RechteckMasseState();
}

class _RechteckMasseState extends State<RechteckMasse> {
  final _felder = [TextEditingController(), TextEditingController()];
  final _fehler = <String?>[null, null];

  static const _kanten = ['A — B', 'B — C'];

  @override
  void dispose() {
    for (final feld in _felder) {
      feld.dispose();
    }
    super.dispose();
  }

  void _uebernimm(int index, String text) {
    final cm = num.tryParse(text.trim().replaceAll(',', '.'));
    final mm = cm == null ? null : Millimeter.ausCm(cm);
    if (mm == null ||
        mm < Grundriss.kleinsteSeite ||
        mm > Grundriss.groessteSeite) {
      setState(
        () => _fehler[index] = context.texte.massUngueltig(
          Grundriss.kleinsteSeite.mm ~/ 10,
          Grundriss.groessteSeite.mm ~/ 10,
        ),
      );
      return;
    }
    final stand = widget.planung.aktuell;
    final rechteck = switch (stand.grundriss) {
      final RechteckGrundriss r => r,
    };
    widget.planung.setze(
      stand.mitGrundriss(
        index == 0
            ? RechteckGrundriss(mm, rechteck.bc)
            : RechteckGrundriss(rechteck.ab, mm),
      ),
    );
    widget.onGeaendert();
    _felder[index].clear();
    setState(() => _fehler[index] = null);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < _kanten.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: PlanerAbstand.klein),
          child: TextField(
            key: ValueKey('mass-$i'),
            controller: _felder[i],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              hintText: context.texte.massPlatzhalter(_kanten[i]),
              errorText: _fehler[i],
            ),
            onSubmitted: (text) => _uebernimm(i, text),
          ),
        ),
    ],
  );
}
