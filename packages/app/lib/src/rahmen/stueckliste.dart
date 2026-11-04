import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';

/// Stückliste der bearbeiteten Fläche (M9-04, Fachkonzept 08): Artikel,
/// Länge, Stück und Farbe – dieselbe Farbe, mit der die Zeichnung das Stück
/// umrandet ([Stueckfarbe.argb]). Der Server ordnet die Farben zu.
class StuecklisteAnsicht extends StatelessWidget {
  const StuecklisteAnsicht({required this.berechnung, super.key});

  final BerechnungsSteuerung berechnung;

  /// Farbe eines Stücks für Zeichnung und Liste.
  static Color farbe(Stueckfarbe f) => Color(f.argb);

  /// Name der Farbe in der Sprache der Oberfläche.
  static String farbname(PlanerTexte t, Stueckfarbe f) => switch (f) {
    Stueckfarbe.rot => t.stueckfarbeRot,
    Stueckfarbe.blau => t.stueckfarbeBlau,
    Stueckfarbe.gruen => t.stueckfarbeGruen,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: berechnung,
    builder: (context, _) => _liste(context, berechnung.stueckliste),
  );

  Widget _liste(BuildContext context, Stueckliste liste) {
    final t = context.texte;
    if (liste.istLeer) {
      return Text(key: const ValueKey('stueckliste-leer'), t.stuecklisteLeer);
    }
    return Column(
      key: const ValueKey('stueckliste'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(t.stueckSpalteArtikel)),
              DataColumn(label: Text(t.stueckSpalteLaenge), numeric: true),
              DataColumn(label: Text(t.stueckSpalteStueck), numeric: true),
              DataColumn(label: Text(t.stueckSpalteFarbe)),
            ],
            rows: [
              for (final (i, z) in liste.zeilen.indexed)
                DataRow(
                  cells: [
                    DataCell(Text(z.titel)),
                    DataCell(Text(zahlText(t, z.laenge.cm, '#,##0.#'))),
                    DataCell(Text('${z.stueck}')),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            key: ValueKey('stueckfarbe-$i'),
                            width: 16,
                            height: 16,
                            color: farbe(z.farbe),
                          ),
                          const SizedBox(width: 8),
                          Text(farbname(t, z.farbe)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Text(t.stuecklisteHinweis, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
