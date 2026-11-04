import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'steuerung.dart';
import 'zeichnung.dart';

/// Ändert den Ausgangspunkt der Verlegung (M5-07, Fachkonzept 2.5): Ecke
/// wählen und die erste ganze Diele verschieben – über Eingabefeld,
/// Schieberegler oder den Griff in der Zeichnung. Die Grenzen der
/// Verschiebung liefert der Server mit der Berechnung.
class AusgangspunktBedienung {
  AusgangspunktBedienung({
    required this.planung,
    required this.onGeaendert,
    this.berechnung,
  });

  final PlanungsSteuerung planung;

  /// Berechnung des Servers mit den Grenzen; ohne sie keine Verschiebung.
  final BerechnungsSteuerung? berechnung;

  /// Meldet eine übernommene Eingabe (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  Planungsstand? _vorZiehen;

  /// Größte Verschiebung nach links oder rechts in mm; 0 ohne Dielen.
  Millimeter get grenzeLinksRechts =>
      berechnung?.ergebnis?.grenzeLinksRechts ?? const Millimeter(0);

  /// Größte Verschiebung nach oben oder unten in mm; 0 ohne Dielen.
  Millimeter get grenzeObenUnten =>
      berechnung?.ergebnis?.grenzeObenUnten ?? const Millimeter(0);

  /// Ob die Verlegung Zuschnitte unter 5 cm ergibt (Warnung unter 2.5).
  bool get kurzeZuschnitte => berechnung?.ergebnis?.kurzeZuschnitte ?? false;

  void waehleEcke(int ecke) {
    planung.setze(planung.aktuell.mitAusgangspunkt(ecke: ecke));
    onGeaendert();
  }

  /// Setzt die Verschiebung nach rechts ([x]) und unten ([y]) in mm, auf die
  /// Grenzen begrenzt. [beginn] = neuer Schritt im Verlauf; während eines
  /// Zugs wird der Stand nur ersetzt (wie Ziehen, M4-09).
  void verschiebe({Millimeter? x, Millimeter? y, bool beginn = true}) {
    final neu = planung.aktuell.mitAusgangspunkt(
      x: x == null ? null : _begrenzt(x, grenzeLinksRechts),
      y: y == null ? null : _begrenzt(y, grenzeObenUnten),
    );
    if (beginn) {
      planung.setze(neu);
      onGeaendert();
    } else {
      planung.ersetze(neu);
    }
  }

  /// Verschiebt die erste ganze Diele um [versatz] mm seit Beginn des Zugs
  /// am Griff in der Zeichnung.
  void ziehe(Punkt versatz, {required bool beginn}) {
    if (beginn) _vorZiehen = planung.aktuell;
    final alt = _vorZiehen!;
    verschiebe(
      x: Millimeter((alt.verschiebungX.mm + versatz.x).round()),
      y: Millimeter((alt.verschiebungY.mm + versatz.y).round()),
      beginn: beginn,
    );
  }

  static Millimeter _begrenzt(Millimeter wert, Millimeter grenze) =>
      Millimeter(wert.mm.clamp(-grenze.mm, grenze.mm));
}

/// Unterpunkt „Ausgangspunkt des Belags“ (Fachkonzept 2.5, M5-07): Ecke A,
/// B … (Vorgabe A), Verschiebung der ersten ganzen Diele nach links/rechts
/// und oben/unten in cm mit Eingabefeld und Schieberegler und die Warnung
/// bei Zuschnitten unter 5 cm.
class AusgangspunktWahl extends StatelessWidget {
  const AusgangspunktWahl({required this.bedienung, super.key});

  final AusgangspunktBedienung bedienung;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([bedienung.planung, bedienung.berechnung]),
    builder: (context, _) {
      final t = context.texte;
      final stand = bedienung.planung.aktuell;
      final x = bedienung.grenzeLinksRechts;
      final y = bedienung.grenzeObenUnten;
      return Column(
        key: const ValueKey('ausgangspunkt'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.ausgangspunktFrage),
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (var i = 0; i < stand.ausgangsecken; i++)
                ChoiceChip(
                  key: ValueKey('ausgangsecke-$i'),
                  label: Text(ZeichnungsMaler.punktname(i)),
                  selected: i == stand.ausgangsecke,
                  onSelected: (an) {
                    if (an) bedienung.waehleEcke(i);
                  },
                ),
            ],
          ),
          const SizedBox(height: PlanerAbstand.klein),
          if (x.mm > 0 && y.mm > 0) ...[
            Text(t.ausgangspunktVerschieben),
            Verschiebungsfeld(
              key: const ValueKey('verschiebung-x'),
              titel: t.verschiebungLinksRechts,
              hilfe: t.verschiebungHilfeLinksRechts,
              wert: stand.verschiebungX,
              grenze: x,
              onGeaendert: (mm, {required beginn}) =>
                  bedienung.verschiebe(x: mm, beginn: beginn),
            ),
            Verschiebungsfeld(
              key: const ValueKey('verschiebung-y'),
              titel: t.verschiebungObenUnten,
              hilfe: t.verschiebungHilfeObenUnten,
              wert: stand.verschiebungY,
              grenze: y,
              onGeaendert: (mm, {required beginn}) =>
                  bedienung.verschiebe(y: mm, beginn: beginn),
            ),
          ] else
            Text(t.verschiebungOhneDielen),
          if (bedienung.kurzeZuschnitte)
            Padding(
              key: const ValueKey('zuschnitt-warnung'),
              padding: const EdgeInsets.only(top: PlanerAbstand.klein),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: context.farben.error),
                  const SizedBox(width: PlanerAbstand.klein),
                  Expanded(
                    child: Text(
                      t.zuschnittWarnung,
                      style: TextStyle(color: context.farben.error),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

/// Eine Achse der Verschiebung: Eingabefeld in cm (Enter übernimmt, der
/// aktuelle Wert steht als Platzhalter darin) und Schieberegler von
/// −[grenze] bis [grenze] in ganzen cm.
class Verschiebungsfeld extends StatefulWidget {
  const Verschiebungsfeld({
    required this.titel,
    required this.hilfe,
    required this.wert,
    required this.grenze,
    required this.onGeaendert,
    super.key,
  });

  final String titel;
  final String hilfe;

  /// Aktuelle Verschiebung in mm.
  final Millimeter wert;

  /// Größte Verschiebung in mm (> 0).
  final Millimeter grenze;

  /// Neue Verschiebung; [beginn] = neuer Schritt im Verlauf.
  final void Function(Millimeter mm, {required bool beginn}) onGeaendert;

  @override
  State<Verschiebungsfeld> createState() => _VerschiebungsfeldState();
}

class _VerschiebungsfeldState extends State<Verschiebungsfeld> {
  final _feld = TextEditingController();
  String? _fehler;
  var _beginn = true;

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  String _cm(Millimeter mm) => zahlText(context.texte, mm.mm / 10, '0.#');

  void _uebernimm(String text) {
    final cm = num.tryParse(text.trim().replaceAll(',', '.'));
    final mm = cm == null ? null : (cm * 10).round();
    if (mm == null || mm.abs() > widget.grenze.mm) {
      setState(
        () => _fehler = context.texte.verschiebungUngueltig(_cm(widget.grenze)),
      );
      return;
    }
    widget.onGeaendert(Millimeter(mm), beginn: true);
    _feld.clear();
    setState(() => _fehler = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final grenze = widget.grenze.mm.toDouble();
    final wert = widget.wert.mm.clamp(-grenze, grenze).toDouble();
    return Padding(
      padding: const EdgeInsets.only(top: PlanerAbstand.klein),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('feld'),
            controller: _feld,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              labelText: widget.titel,
              hintText: t.verschiebungCm(_cm(widget.wert)),
              helperText: widget.hilfe,
              errorText: _fehler,
            ),
            onSubmitted: _uebernimm,
          ),
          Slider(
            key: const ValueKey('regler'),
            min: -grenze,
            max: grenze,
            // ganze cm; bei Grenzen wie 6,5 cm bleibt der Rand erreichbar
            divisions: (2 * grenze / 10).ceil(),
            value: wert,
            label: t.verschiebungCm(_cm(widget.wert)),
            onChangeStart: (_) => _beginn = true,
            onChanged: (neu) {
              widget.onGeaendert(Millimeter(neu.round()), beginn: _beginn);
              _beginn = false;
            },
          ),
        ],
      ),
    );
  }
}
