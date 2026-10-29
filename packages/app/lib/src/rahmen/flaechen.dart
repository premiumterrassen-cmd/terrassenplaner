import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'steuerung.dart';

/// Reiter der Flächen über dem Menü (M4-14): Fläche 1, 2 … wählen,
/// hinzufügen, die bearbeitete löschen und ihre Häufigkeit einstellen. Jede
/// Fläche hat eigene Einstellungen in allen Schritten.
class FlaechenReiter extends StatelessWidget {
  const FlaechenReiter({
    required this.planung,
    required this.onGeaendert,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Meldet eine Änderung der Planung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  void _setze(Planung neu) {
    planung.setzePlanung(neu);
    onGeaendert();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final p = planung.planung;
    return Padding(
      key: const ValueKey('flaechen-reiter'),
      padding: const EdgeInsets.all(PlanerAbstand.mittel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: PlanerAbstand.klein,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (i, _) in p.flaechen.indexed)
                ChoiceChip(
                  key: ValueKey('flaeche-$i'),
                  label: Text(t.flaecheReiter(i + 1)),
                  selected: i == p.aktiv,
                  // ohne Wechsel kein Schritt im Verlauf
                  onSelected: (_) => planung.setzePlanung(p.gewaehlt(i)),
                ),
              IconButton(
                key: const ValueKey('flaeche-hinzufuegen'),
                tooltip: t.flaecheHinzufuegen,
                icon: const Icon(Icons.add),
                onPressed: () => _setze(p.mitNeuerFlaeche()),
              ),
              IconButton(
                key: const ValueKey('flaeche-loeschen'),
                tooltip: t.flaecheLoeschen,
                icon: const Icon(Icons.delete_outline),
                onPressed: p.flaechen.length > 1
                    ? () => _setze(p.ohneFlaeche(p.aktiv))
                    : null,
              ),
            ],
          ),
          Tooltip(
            message: t.haeufigkeitHinweis,
            child: Row(
              children: [
                Expanded(child: Text(t.haeufigkeit)),
                IconButton(
                  key: const ValueKey('haeufigkeit-weniger'),
                  tooltip: t.haeufigkeitWeniger,
                  icon: const Icon(Icons.remove),
                  onPressed: p.haeufigkeit > 1
                      ? () => _setze(p.mitHaeufigkeit(p.haeufigkeit - 1))
                      : null,
                ),
                Text(
                  '${p.haeufigkeit}',
                  key: const ValueKey('haeufigkeit-wert'),
                ),
                IconButton(
                  key: const ValueKey('haeufigkeit-mehr'),
                  tooltip: t.haeufigkeitMehr,
                  icon: const Icon(Icons.add),
                  onPressed:
                      p.haeufigkeit < Terrassenflaeche.hoechsteHaeufigkeit
                      ? () => _setze(p.mitHaeufigkeit(p.haeufigkeit + 1))
                      : null,
                ),
              ],
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
