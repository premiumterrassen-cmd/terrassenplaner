import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';

/// Zuschnittpläne der ganzen Planung (M9-02, Fachkonzept 08): je Bereich
/// (Belag, Unterkonstruktion) und Artikel die Ausgangslänge, die Menge und
/// die Schnittmaße – wie „Zuschnitt Deckbelag“ und „Zuschnitt
/// Unterkonstruktion“ in den Planungsunterlagen. Der Server rechnet sie
/// (mit der gewählten Verschnittvariante, M9-01); die App zeigt sie nur an.
class ZuschnittplanAnsicht extends StatelessWidget {
  const ZuschnittplanAnsicht({required this.berechnung, super.key});

  final BerechnungsSteuerung berechnung;

  /// Schnittmaße in cm, getrennt durch „|“ („200 | 200“).
  static String schnitte(PlanerTexte t, Zuschnittzeile z) =>
      [for (final s in z.schnitte) zahlText(t, s.cm, '#,##0.#')].join(' | ');

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: berechnung,
    builder: (context, _) {
      final t = context.texte;
      final belag = berechnung.zuschnittBelag;
      final uk = berechnung.zuschnittUk;
      if (belag.istLeer && uk.istLeer) {
        return Text(key: const ValueKey('zuschnittplan-leer'), t.zuschnittLeer);
      }
      return Column(
        key: const ValueKey('zuschnittplan'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (name, plan, schluessel) in [
            (t.zuschnittBelag, belag, 'zuschnitt-belag'),
            (t.zuschnittUk, uk, 'zuschnitt-uk'),
          ])
            if (!plan.istLeer) ...[
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              _tabelle(t, plan, ValueKey(schluessel)),
              const SizedBox(height: PlanerAbstand.mittel),
            ],
          Text(t.zuschnittHinweis, style: const TextStyle(fontSize: 12)),
        ],
      );
    },
  );

  static Widget _tabelle(PlanerTexte t, Zuschnittplan plan, Key key) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          key: key,
          columns: [
            DataColumn(label: Text(t.stueckSpalteArtikel)),
            DataColumn(
              label: Text(t.zuschnittSpalteAusgangslaenge),
              numeric: true,
            ),
            DataColumn(label: Text(t.zuschnittSpalteMenge), numeric: true),
            DataColumn(label: Text(t.zuschnittSpalteSchnitte)),
          ],
          rows: [
            for (final z in plan.zeilen)
              DataRow(
                cells: [
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Text(
                        z.titel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(Text(zahlText(t, z.ausgangslaenge.cm, '#,##0.#'))),
                  DataCell(Text('${z.menge}')),
                  DataCell(Text(schnitte(t, z))),
                ],
              ),
          ],
        ),
      );
}
