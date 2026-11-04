import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../artikel/artikelbild_widget.dart';
import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'lade_quelle.dart';
import 'planer_schritt.dart';
import 'steuerung.dart';

/// Lädt die Zubehörauswahl vom Server (M8-01); in Tests austauschbar.
typedef ZubehoerLaden = Future<Zubehoerauswahl> Function();

/// Hält das Zubehör des Servers in seinen acht Gruppen (M8-01).
class ZubehoerQuelle extends LadeQuelle<Zubehoerauswahl> {
  ZubehoerQuelle(super.lade);
}

/// Schritt „Zubehör“ (Fachkonzept 06, M8-01): Akkordeon mit den acht
/// Gruppen, es ist immer nur eine geöffnet. Jede Gruppe zeigt eine Tabelle
/// „Bezeichnung | Tatsächlich“ mit Bild, Artikelname und Mengenfeld; die
/// Artikel und ihre Reihenfolge kommen vom Server (B-122).
class ZubehoerBereich extends StatefulWidget {
  const ZubehoerBereich({
    required this.planung,
    required this.onGeaendert,
    super.key,
    this.quelle,
    this.berechnung,
  });

  /// Zubehör vom Server; ohne Quelle nur die Gruppen.
  final ZubehoerQuelle? quelle;
  final PlanungsSteuerung planung;

  /// Berechnete Mengen des Servers (M8-02); ohne sie 0.
  final BerechnungsSteuerung? berechnung;

  /// Meldet eine geänderte Menge (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  State<ZubehoerBereich> createState() => _ZubehoerBereichState();
}

class _ZubehoerBereichState extends State<ZubehoerBereich> {
  /// Geöffnete Gruppe; `null` = alle zu. Am Anfang die erste wie im alten
  /// Planer.
  Zubehoergruppe? _offen = Zubehoergruppe.values.first;

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final titel = PlanerSchritt.zubehoer.nummerierteUnterpunkte(t);
    return Column(
      key: const ValueKey('zubehoer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, gruppe) in Zubehoergruppe.values.indexed) ...[
          InkWell(
            key: ValueKey('zubehoergruppe-${gruppe.name}'),
            onTap: () =>
                setState(() => _offen = _offen == gruppe ? null : gruppe),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: PlanerAbstand.klein,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(titel[i])),
                  Icon(
                    gruppe == _offen ? Icons.expand_less : Icons.expand_more,
                  ),
                ],
              ),
            ),
          ),
          if (gruppe == _offen)
            ZubehoerTabelle(
              gruppe: gruppe,
              quelle: widget.quelle,
              berechnung: widget.berechnung,
              planung: widget.planung,
              onGeaendert: widget.onGeaendert,
            ),
        ],
      ],
    );
  }
}

/// Tabelle einer Zubehörgruppe (M8-01) samt Lade-, Fehler- und Leertext.
class ZubehoerTabelle extends StatelessWidget {
  const ZubehoerTabelle({
    required this.gruppe,
    required this.planung,
    required this.onGeaendert,
    super.key,
    this.quelle,
    this.berechnung,
  });

  final Zubehoergruppe gruppe;
  final ZubehoerQuelle? quelle;
  final BerechnungsSteuerung? berechnung;
  final PlanungsSteuerung planung;
  final VoidCallback onGeaendert;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([quelle, planung, berechnung]),
    builder: (context, _) {
      final t = context.texte;
      final q = quelle;
      if (q?.fehler != null) {
        return Row(
          children: [
            Expanded(child: Text(t.zubehoerFehler)),
            TextButton(
              key: const ValueKey('zubehoer-neu-laden'),
              onPressed: q!.ladeNeu,
              child: Text(t.erneutVersuchen),
            ),
          ],
        );
      }
      final auswahl = q?.auswahl;
      if (q != null && auswahl == null) return Text(t.zubehoerLaedt);
      final artikel = auswahl?.gruppen[gruppe] ?? const <Artikel>[];
      if (artikel.isEmpty) return Text(t.zubehoerKeine);
      final stil = Theme.of(context).textTheme.labelMedium;
      final berechnet = {
        for (final z
            in berechnung?.ergebnis?.zubehoer ?? const <Zubehoerposition>[])
          z.nummer: z.berechnet,
      };
      return Column(
        key: ValueKey('zubehoertabelle-${gruppe.name}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.zubehoerBezeichnung, style: stil)),
              SizedBox(
                width: ZubehoerZeile.feldbreite,
                child: Text(t.zubehoerTatsaechlich, style: stil),
              ),
            ],
          ),
          for (final a in artikel)
            ZubehoerZeile(
              artikel: a,
              berechnet: berechnet[a.nummer] ?? 0,
              // die Eingabe sofort, nicht erst nach der Antwort des Servers
              menge:
                  planung.aktuell.zubehoer[a.nummer] ??
                  berechnet[a.nummer] ??
                  0,
              onMenge: (anzahl) {
                planung.setze(
                  planung.aktuell.mitZubehoermenge(a.nummer, anzahl),
                );
                onGeaendert();
              },
            ),
        ],
      );
    },
  );
}

/// Eine Zeile „Bild, Bezeichnung | Tatsächlich“ (M8-01). Wie die Maßfelder
/// zeigt das Feld die aktuelle Menge als Platzhalter; Enter übernimmt die
/// Eingabe, ein leeres Feld nimmt sie zurück (wieder die berechnete Menge,
/// M8-02).
class ZubehoerZeile extends StatefulWidget {
  const ZubehoerZeile({
    required this.artikel,
    required this.menge,
    required this.onMenge,
    super.key,
    this.berechnet = 0,
  });

  /// Breite der Spalte „Tatsächlich“.
  static const feldbreite = 88.0;

  final Artikel artikel;

  /// Angezeigte Menge „Tatsächlich“ in Verkaufseinheiten.
  final int menge;

  /// Vom Planer berechnete Menge (M8-02); weicht die Eingabe ab, steht sie
  /// unter dem Namen.
  final int berechnet;

  /// Neue Eingabe; `null` = zurück auf den berechneten Wert.
  final ValueChanged<int?> onMenge;

  @override
  State<ZubehoerZeile> createState() => _ZubehoerZeileState();
}

class _ZubehoerZeileState extends State<ZubehoerZeile> {
  final _feld = TextEditingController();
  String? _fehler;

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  void _uebernimm(String text) {
    final eingabe = text.trim();
    final anzahl = int.tryParse(eingabe);
    if (eingabe.isNotEmpty &&
        (anzahl == null ||
            anzahl < 0 ||
            anzahl > Planungsstand.hoechsteZubehoermenge)) {
      setState(
        () => _fehler = context.texte.zubehoerMengeUngueltig(
          Planungsstand.hoechsteZubehoermenge,
        ),
      );
      return;
    }
    _feld.clear();
    setState(() => _fehler = null);
    widget.onMenge(anzahl);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.artikel;
    return Padding(
      key: ValueKey('zubehoer-${a.nummer.wert}'),
      padding: const EdgeInsets.only(top: PlanerAbstand.klein),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Artikelbild(a, groesse: 40),
          const SizedBox(width: PlanerAbstand.klein),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.titel),
                if (widget.menge != widget.berechnet)
                  Text(
                    context.texte.zubehoerBerechnet(widget.berechnet),
                    key: ValueKey('zubehoerberechnet-${a.nummer.wert}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: PlanerAbstand.klein),
          SizedBox(
            width: ZubehoerZeile.feldbreite,
            child: TextField(
              key: ValueKey('zubehoermenge-${a.nummer.wert}'),
              controller: _feld,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: '${widget.menge}',
                errorText: _fehler,
                errorMaxLines: 3,
              ),
              onSubmitted: _uebernimm,
            ),
          ),
        ],
      ),
    );
  }
}
