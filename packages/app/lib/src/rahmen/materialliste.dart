import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../artikel/artikelbild_widget.dart';
import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'steuerung.dart';
import 'stueckliste.dart';

/// Materialliste der ganzen Planung (M9-03, Fachkonzept 08), wie der
/// Server sie rechnet: Position, Bild, Artikel, Menge, Einzelpreis, Preis
/// je lfm, Gesamt-lfm und Positionspreis, darunter Summe und enthaltene
/// Mehrwertsteuer. Preise sind nur Anzeige (B-055) – die App rechnet nichts.
///
/// In der Mitarbeiter-Ansicht ([mitarbeiter], Fachkonzept 08) ist die Menge
/// je Position änderbar und wird mit dem Häkchen übernommen; die Planung
/// merkt sich die Menge, der Server rechnet mit ihr – aber nur für
/// angemeldete Mitarbeiter (M9-10).
class MateriallisteAnsicht extends StatelessWidget {
  const MateriallisteAnsicht({
    required this.berechnung,
    required this.planung,
    super.key,
    this.mitarbeiter = false,
  });

  final BerechnungsSteuerung berechnung;
  final PlanungsSteuerung planung;

  /// Ob die Mengen änderbar sind (Rolle Mitarbeiter, M9-10).
  final bool mitarbeiter;

  /// Betrag in Euro mit zwei Nachkommastellen im Format der Sprache
  /// („2.066,57 €“); „–“ ohne Preis.
  static String betrag(PlanerTexte t, Cent? preis) =>
      preis == null ? '–' : '${zahlText(t, preis.euro, '#,##0.00')} €';

  /// Laufmeter mit höchstens drei Nachkommastellen („240“, „13,5“); „–“
  /// ohne Länge.
  static String laufmeter(PlanerTexte t, Millimeter? laenge) =>
      laenge == null ? '–' : zahlText(t, laenge.m, '#,##0.###');

  /// Einheit der Menge in der Sprache der Oberfläche.
  static String einheit(PlanerTexte t, Mengeneinheit e) => switch (e) {
    Mengeneinheit.stueck => t.einheitStueck,
    Mengeneinheit.laufmeter => t.einheitLaufmeter,
    Mengeneinheit.quadratmeter => t.einheitQuadratmeter,
    Mengeneinheit.verpackungseinheit => t.einheitVerpackungseinheit,
    Mengeneinheit.karton => t.einheitKarton,
    Mengeneinheit.set => t.einheitSet,
    Mengeneinheit.kiste => t.einheitKiste,
    Mengeneinheit.liter => t.einheitLiter,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: berechnung,
    builder: (context, _) => _liste(context, berechnung.materialliste),
  );

  Widget _liste(BuildContext context, Materialliste liste) {
    final t = context.texte;
    if (liste.istLeer) {
      return Text(
        key: const ValueKey('materialliste-leer'),
        t.materiallisteLeer,
      );
    }
    final rechts = Theme.of(context).textTheme.bodyMedium;
    return Column(
      key: const ValueKey('materialliste'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mitarbeiter)
          Text(
            key: const ValueKey('materialliste-mitarbeiter'),
            t.materialMitarbeiter,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            dataRowMinHeight: 56,
            dataRowMaxHeight: mitarbeiter ? 120 : 88,
            columns: [
              DataColumn(label: Text(t.materialSpaltePosition), numeric: true),
              DataColumn(label: Text(t.materialSpalteBild)),
              DataColumn(label: Text(t.materialSpalteArtikel)),
              DataColumn(label: Text(t.materialSpalteMenge), numeric: true),
              DataColumn(
                label: Text(t.materialSpalteEinzelpreis),
                numeric: true,
              ),
              DataColumn(
                label: Text(t.materialSpaltePreisJeLfm),
                numeric: true,
              ),
              DataColumn(label: Text(t.materialSpalteGesamtLfm), numeric: true),
              DataColumn(
                label: Text(t.materialSpaltePositionspreis),
                numeric: true,
              ),
            ],
            rows: [
              for (final p in liste.positionen)
                DataRow(
                  key: ValueKey('position-${p.position}'),
                  cells: [
                    DataCell(Text('${p.position}')),
                    DataCell(Artikelbild.datei(p.bild, p.titel, groesse: 48)),
                    DataCell(_artikel(t, p)),
                    DataCell(_menge(t, p)),
                    DataCell(Text(betrag(t, p.einzelpreis))),
                    DataCell(
                      Text(p.laenge == null ? '' : betrag(t, p.preisJeLfm)),
                    ),
                    DataCell(
                      Text(
                        p.laenge == null ? '' : laufmeter(t, p.gesamtlaenge),
                      ),
                    ),
                    DataCell(Text(betrag(t, p.positionspreis))),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: PlanerAbstand.mittel),
        Text(
          key: const ValueKey('materialliste-summe'),
          t.materialSumme(betrag(t, liste.summe)),
          textAlign: TextAlign.end,
          style: rechts?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          key: const ValueKey('materialliste-mwst'),
          t.materialMehrwertsteuer(
            mehrwertsteuerSatz,
            betrag(t, liste.mehrwertsteuer),
          ),
          textAlign: TextAlign.end,
        ),
        if (!liste.vollstaendig)
          Text(
            key: const ValueKey('materialliste-ohne-preis'),
            t.materialOhnePreis,
            textAlign: TextAlign.end,
          ),
        const SizedBox(height: PlanerAbstand.klein),
        Text(t.materialPreishinweis, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// Titel wie im Shop (B-152), darunter Länge und Zusatz.
  static Widget _artikel(PlanerTexte t, Materialzeile p) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 360),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.titel, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (p.laenge case final l?)
          Text(t.materialLaenge(l.mm), style: const TextStyle(fontSize: 12)),
        if (switch (p.zusatz) {
              Materialzusatz.freidiele => t.materialFreidiele,
              Materialzusatz.verblendung => t.materialVerblendung,
              null => null,
            }
            case final zusatz?)
          Text(
            zusatz,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
      ],
    ),
  );

  Widget _menge(PlanerTexte t, Materialzeile p) {
    final text = '${p.anzahl} ${einheit(t, p.einheit)}';
    final berechnet = p.berechnet;
    if (!mitarbeiter) return Text(text);
    return Mengenfeld(
      key: ValueKey('menge-${p.position}-${p.anzahl}'),
      zeile: p,
      einheit: einheit(t, p.einheit),
      onUebernehmen: (anzahl) =>
          planung.setzePlanung(planung.planung.mitMenge(p.schluessel, anzahl)),
      onBerechnet: berechnet == null
          ? null
          : () => planung.setzePlanung(
              planung.planung.mitMenge(p.schluessel, null),
            ),
    );
  }
}

/// Änderbare Menge einer Position in der Mitarbeiter-Ansicht: Eingabe und
/// Häkchen zum Übernehmen; nach einer Änderung darunter die berechnete
/// Menge mit Knopf zurück zu ihr (R-D04).
class Mengenfeld extends StatefulWidget {
  const Mengenfeld({
    required this.zeile,
    required this.einheit,
    required this.onUebernehmen,
    super.key,
    this.onBerechnet,
  });

  final Materialzeile zeile;
  final String einheit;
  final ValueChanged<int> onUebernehmen;

  /// Zurück zur berechneten Menge; `null`, solange sie gilt.
  final VoidCallback? onBerechnet;

  @override
  State<Mengenfeld> createState() => _MengenfeldState();
}

class _MengenfeldState extends State<Mengenfeld> {
  late final _eingabe = TextEditingController(text: '${widget.zeile.anzahl}');

  @override
  void dispose() {
    _eingabe.dispose();
    super.dispose();
  }

  void _uebernimm() {
    final anzahl = int.tryParse(_eingabe.text);
    if (anzahl != null) widget.onUebernehmen(anzahl);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final position = widget.zeile.position;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              child: TextField(
                key: ValueKey('menge-eingabe-$position'),
                controller: _eingabe,
                textAlign: TextAlign.end,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _uebernimm(),
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: widget.einheit,
                ),
              ),
            ),
            IconButton(
              key: ValueKey('menge-uebernehmen-$position'),
              tooltip: t.materialMengeUebernehmen,
              icon: const Icon(Icons.check),
              onPressed: _uebernimm,
            ),
          ],
        ),
        if (widget.zeile.berechnet case final b?)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.materialBerechnet(b),
                style: const TextStyle(fontSize: 12),
              ),
              IconButton(
                key: ValueKey('menge-berechnet-$position'),
                tooltip: t.materialMengeBerechnet,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.undo),
                onPressed: widget.onBerechnet,
              ),
            ],
          ),
      ],
    );
  }
}

/// Dialog mit Materialliste (M9-03) und Stückliste (M9-04), umschaltbar;
/// [mitarbeiter] schaltet die Mitarbeiter-Ansicht der Materialliste frei
/// (Rollenprüfung, angeschlossen mit M9-10).
class MateriallisteDialog extends StatefulWidget {
  const MateriallisteDialog({
    required this.berechnung,
    required this.planung,
    super.key,
    this.mitarbeiter,
  });

  final BerechnungsSteuerung berechnung;
  final PlanungsSteuerung planung;

  /// Rolle der Sitzung; `null` = Kunde (keine Anmeldung).
  final ValueListenable<bool>? mitarbeiter;

  @override
  State<MateriallisteDialog> createState() => _MateriallisteDialogState();
}

/// Welche Liste der Dialog zeigt.
enum Ergebnisliste { material, stueck }

class _MateriallisteDialogState extends State<MateriallisteDialog> {
  static final _keinMitarbeiter = ValueNotifier(false);

  var _liste = Ergebnisliste.material;

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return AlertDialog(
      key: const ValueKey('materialliste-dialog'),
      title: SegmentedButton<Ergebnisliste>(
        key: const ValueKey('ergebnisliste-wahl'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: Ergebnisliste.material,
            label: Text(t.materialliste),
          ),
          ButtonSegment(
            value: Ergebnisliste.stueck,
            label: Text(key: const ValueKey('zur-stueckliste'), t.stueckliste),
          ),
        ],
        selected: {_liste},
        onSelectionChanged: (wahl) => setState(() => _liste = wahl.single),
      ),
      content: SizedBox(
        width: 1100,
        child: SingleChildScrollView(
          child: switch (_liste) {
            Ergebnisliste.material => ValueListenableBuilder(
              valueListenable: widget.mitarbeiter ?? _keinMitarbeiter,
              builder: (context, istMitarbeiter, _) => MateriallisteAnsicht(
                berechnung: widget.berechnung,
                planung: widget.planung,
                mitarbeiter: istMitarbeiter,
              ),
            ),
            Ergebnisliste.stueck => StuecklisteAnsicht(
              berechnung: widget.berechnung,
            ),
          },
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('materialliste-schliessen'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.schliessen),
        ),
      ],
    );
  }
}
