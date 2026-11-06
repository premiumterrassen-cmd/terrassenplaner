import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../sprache/sprache.dart';
import 'steuerung.dart';
import 'unterkonstruktion.dart';

/// Weitere Höhenreferenzpunkte (M7-04, Fachkonzept 3.2) bearbeiten:
/// hinzufügen, per Eingabe ändern, in der Zeichnung ziehen, entfernen.
class HoehenpunktBedienung {
  HoehenpunktBedienung({required this.planung, required this.onGeaendert});

  final PlanungsSteuerung planung;

  /// Meldet eine übernommene Eingabe (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  Planungsstand? _vorZiehen;

  void _setze(Planungsstand stand) {
    planung.setze(stand);
    onGeaendert();
  }

  /// „Weiteren Höhenreferenzpunkt einplanen“.
  void fuegeHinzu() => _setze(planung.aktuell.mitNeuemHoehenpunkt());

  void entferne(int index) => _setze(planung.aktuell.ohneHoehenpunkt(index));

  /// Ersetzt Punkt [index] durch das Ergebnis von [neu].
  void aendere(
    int index,
    Hoehenreferenzpunkt Function(Hoehenreferenzpunkt) neu,
  ) {
    final stand = planung.aktuell;
    _setze(stand.mitHoehenpunkt(index, neu(stand.hoehenpunkte[index])));
  }

  /// Verschiebt Punkt [index] um [versatz] mm seit Beginn (Ziehen in der
  /// Zeichnung); ein Schritt für Rückgängig je Zug.
  void ziehe(int index, Punkt versatz, {required bool beginn}) {
    if (beginn) _vorZiehen = planung.aktuell;
    final alt = _vorZiehen!.hoehenpunkte[index];
    final neu = _vorZiehen!.mitHoehenpunkt(index, (
      x: Millimeter(alt.x.mm + versatz.x.round()),
      y: Millimeter(alt.y.mm + versatz.y.round()),
      hoehe: alt.hoehe,
    ));
    if (beginn) {
      _setze(neu);
    } else {
      planung.ersetze(neu);
    }
  }
}

/// Eingaben der weiteren Höhenreferenzpunkte unter 3.2 (nur mit Gefälle,
/// M7-04): je Punkt Waagerecht und Senkrecht ab Punkt A (negativ erlaubt)
/// und die Höhe, dazu „entfernen“ und „Weiteren Höhenreferenzpunkt
/// einplanen“. In der Zeichnung lässt sich jeder Punkt ziehen.
class HoehenpunktEingabe extends StatelessWidget {
  const HoehenpunktEingabe({required this.bedienung, super.key});

  final HoehenpunktBedienung bedienung;

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final punkte = bedienung.planung.aktuell.hoehenpunkte;
    Hoehenreferenzpunkt Function(Hoehenreferenzpunkt) mitLage({
      Millimeter? x,
      Millimeter? y,
      Millimeter? hoehe,
    }) =>
        (alt) => (x: x ?? alt.x, y: y ?? alt.y, hoehe: hoehe ?? alt.hoehe);
    return Column(
      key: const ValueKey('hoehenpunkte-weitere'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, p) in punkte.indexed) ...[
          Row(
            key: ValueKey('hoehenpunkt-$i'),
            children: [
              Expanded(child: Text(t.hoehenpunktName(i + 1))),
              IconButton(
                key: ValueKey('hoehenpunkt-$i-entfernen'),
                tooltip: t.hoehenpunktEntfernen,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => bedienung.entferne(i),
              ),
            ],
          ),
          CmFeld(
            key: ValueKey('hoehenpunkt-$i-x'),
            titel: t.hoehenpunktWaagerecht,
            wert: p.x,
            gueltig: Planungsstand.hoehenpunktLageGueltig,
            fehler: t.hoehenpunktLageUngueltig,
            onGeaendert: (mm) => bedienung.aendere(i, mitLage(x: mm)),
          ),
          CmFeld(
            key: ValueKey('hoehenpunkt-$i-y'),
            titel: t.hoehenpunktSenkrecht,
            wert: p.y,
            gueltig: Planungsstand.hoehenpunktLageGueltig,
            fehler: t.hoehenpunktLageUngueltig,
            onGeaendert: (mm) => bedienung.aendere(i, mitLage(y: mm)),
          ),
          CmFeld(
            key: ValueKey('hoehenpunkt-$i-hoehe'),
            titel: t.hoehenpunktHoehe,
            wert: p.hoehe,
            gueltig: Planungsstand.hoeheGueltig,
            fehler: t.hoeheUngueltig,
            onGeaendert: (mm) => bedienung.aendere(i, mitLage(hoehe: mm)),
          ),
        ],
        Text(t.hoehenpunktHilfe),
        TextButton.icon(
          key: const ValueKey('hoehenpunkt-hinzufuegen'),
          icon: const Icon(Icons.add),
          label: Text(t.hoehenpunktHinzufuegen),
          onPressed: bedienung.fuegeHinzu,
        ),
      ],
    );
  }
}
