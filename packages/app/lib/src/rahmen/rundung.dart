import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'grundriss_eingabe.dart';
import 'steuerung.dart';

/// Was im Rundungsmodus ausgewählt ist: eine Ecke (Radius) oder eine Seite
/// (Stich oder Radius mit Haken „innen“, Planungskern v12, Regel 14.1.2).
typedef RundungsAuswahl = ({bool ecke, int nummer});

/// Bearbeitungsmodus „Ecken und Seiten abrunden“ (Fachkonzept 1.3, M4-11):
/// merkt den Stand beim Öffnen, damit „Zurücksetzen“ genau dorthin zurück
/// kann; jede Rundung ist ein Schritt im Verlauf.
class RundungsBedienung extends ChangeNotifier {
  RundungsBedienung({required this.planung, required this.onGeaendert});

  final PlanungsSteuerung planung;

  /// Meldet eine übernommene Eingabe (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  Planungsstand? _beimOeffnen;
  RundungsAuswahl? _auswahl;
  Rundungen? _vorZiehen;
  var _innen = false;

  /// Haken „innen“ für den Radius einer Seite (Planungskern v12, Regel
  /// 14.1.2); folgt der gewählten Seite.
  bool get innen => _innen;

  /// Ist die gewählte Seite ein Halbkreis, weil ihr Radius kleiner ist als
  /// die halbe Seite (Regel 14.1.1)?
  bool get halbkreis => switch (_auswahl) {
    (ecke: false, :final nummer) =>
      planung.aktuell.rundungen
          .zuKleineRadien(planung.aktuell.grundriss)
          .contains(nummer),
    _ => false,
  };

  bool get aktiv => _beimOeffnen != null;
  RundungsAuswahl? get auswahl => _auswahl;

  /// Nur Formen mit Ecken lassen sich runden; eine offene Freiform nicht.
  bool get moeglich => switch (planung.aktuell.grundriss) {
    FreiformGrundriss(geschlossen: false) => false,
    final g => g.ecken.isNotEmpty,
  };

  void oeffne() {
    _beimOeffnen = planung.aktuell;
    notifyListeners();
  }

  /// „Rundungen übernehmen“ (auch ESC): die Rundungen bleiben.
  void uebernimm() => _schliesse();

  /// „Rundungen zurücksetzen“: zurück zum Stand beim Öffnen.
  void setzeZurueck() {
    planung.setze(_beimOeffnen!);
    _schliesse();
  }

  void _schliesse() {
    _beimOeffnen = null;
    _auswahl = null;
    notifyListeners();
  }

  void waehle(RundungsAuswahl auswahl) {
    _auswahl = auswahl;
    _innen =
        planung.aktuell.rundungen
            .stichAn(planung.aktuell.grundriss, auswahl.nummer)
            .mm <
        0;
    notifyListeners();
  }

  /// Bogen mit Radius [radius] an der Seite [seite] (Regel 14.1.2), nach
  /// innen nach dem Haken [innen]; `false`, wenn er unzulässig ist.
  bool setzeRadius(int seite, Millimeter radius) {
    final r = planung.aktuell.rundungen.mitRadius(seite, radius, innen: _innen);
    if (!_zulaessig(r)) return false;
    planung.setze(planung.aktuell.mitRundungen(r));
    onGeaendert();
    return true;
  }

  /// Haken „innen“: ein Radius oder Stich der Seite [seite] wölbt sich
  /// sofort zur anderen Seite, sofern das zulässig ist.
  void setzeInnen(int seite, {required bool innen}) {
    _innen = innen;
    final alt = planung.aktuell.rundungen;
    final r = switch ((alt.radien[seite], alt.seiten[seite])) {
      (final radius?, _) => alt.mitRadius(seite, radius, innen: innen),
      (_, final stich?) => alt.mitSeite(
        seite,
        Millimeter(innen ? -stich.mm.abs() : stich.mm.abs()),
      ),
      _ => alt,
    };
    if (r != alt && _zulaessig(r)) {
      planung.setze(planung.aktuell.mitRundungen(r));
      onGeaendert();
    }
    notifyListeners();
  }

  /// Setzt Radius bzw. Stich der Auswahl [ziel]; `false`, wenn die Rundung
  /// unzulässig ist (dann bleibt alles, wie es war).
  bool setze(RundungsAuswahl ziel, Millimeter wert) {
    final r = _mit(planung.aktuell.rundungen, ziel, wert);
    if (!_zulaessig(r)) return false;
    planung.setze(planung.aktuell.mitRundungen(r));
    onGeaendert();
    return true;
  }

  /// Ziehen an einem Griff: der Zugweg [versatz] (mm, seit Beginn) entlang
  /// [richtung] (Einheitsvektor nach innen bzw. außen) ändert Radius bzw.
  /// Stich; [beginn] legt einen Rückgängig-Schritt an.
  void ziehe(
    RundungsAuswahl ziel,
    Punkt versatz,
    Punkt richtung, {
    required bool beginn,
  }) {
    if (beginn) {
      _vorZiehen = planung.aktuell.rundungen;
      _auswahl = ziel;
    }
    final alt = ziel.ecke
        ? _vorZiehen!.ecken[ziel.nummer]?.mm ?? 0
        : _vorZiehen!.stichAn(planung.aktuell.grundriss, ziel.nummer).mm;
    var neu = alt + versatz.punktprodukt(richtung).round();
    // ein Radius ist nie negativ
    if (ziel.ecke && neu < 0) neu = 0;
    final r = _mit(_vorZiehen!, ziel, Millimeter(neu));
    if (!_zulaessig(r)) return;
    final stand = planung.aktuell.mitRundungen(r);
    if (beginn) {
      planung.setze(stand);
      onGeaendert();
    } else {
      planung.ersetze(stand);
    }
  }

  static Rundungen _mit(Rundungen r, RundungsAuswahl ziel, Millimeter wert) =>
      ziel.ecke ? r.mitEcke(ziel.nummer, wert) : r.mitSeite(ziel.nummer, wert);

  bool _zulaessig(Rundungen r) {
    try {
      planung.aktuell.mitRundungen(r).kontur;
      return true;
    } on ArgumentError {
      return false;
    }
  }
}

/// Unterpunkt 1.3 (M4-11): „Rundungen hinzufügen“ öffnet den Modus; darin
/// Maßeingabe für die Auswahl, „Rundungen übernehmen“ und „Rundungen
/// zurücksetzen“.
class RundungsEingabe extends StatelessWidget {
  const RundungsEingabe({required this.bedienung, super.key});

  final RundungsBedienung bedienung;

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return ListenableBuilder(
      listenable: bedienung,
      builder: (context, _) {
        if (!bedienung.aktiv) {
          return OutlinedButton(
            key: const ValueKey('rundungen-hinzufuegen'),
            onPressed: bedienung.moeglich ? bedienung.oeffne : null,
            child: Text(t.rundungenHinzufuegen),
          );
        }
        final auswahl = bedienung.auswahl;
        final name = bedienung.planung.aktuell.grundriss.eckname;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.rundungHinweis, key: const ValueKey('rundung-hinweis')),
            if (auswahl != null) ...[
              const SizedBox(height: PlanerAbstand.klein),
              Text(
                auswahl.ecke
                    ? t.rundungEcke(name(auswahl.nummer))
                    : t.rundungSeite(name(auswahl.nummer)),
                key: const ValueKey('rundung-auswahl'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              MassFelder(
                key: ValueKey(auswahl),
                schluessel: 'rundung',
                namen: [
                  if (auswahl.ecke)
                    t.feldRadius
                  else ...[
                    t.feldStich,
                    t.feldRadius,
                  ],
                ],
                kleinstes: const Millimeter(0),
                uebernimm: (index, wert) {
                  final ok = index == 1
                      ? bedienung.setzeRadius(auswahl.nummer, wert)
                      : bedienung.setze(auswahl, wert);
                  if (!ok) throw ArgumentError(t.rundungUnzulaessig);
                },
              ),
              if (!auswahl.ecke) ...[
                CheckboxListTile(
                  key: const ValueKey('rundung-innen'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(t.rundungInnen),
                  value: bedienung.innen,
                  onChanged: (wert) =>
                      bedienung.setzeInnen(auswahl.nummer, innen: wert!),
                ),
                if (bedienung.halbkreis)
                  Text(
                    t.rundungHalbkreis,
                    key: const ValueKey('rundung-halbkreis'),
                  ),
              ],
              TextButton(
                key: const ValueKey('rundung-entfernen'),
                onPressed: () => bedienung.setze(auswahl, const Millimeter(0)),
                child: Text(t.rundungEntfernen),
              ),
            ],
            const SizedBox(height: PlanerAbstand.klein),
            FilledButton(
              key: const ValueKey('rundungen-uebernehmen'),
              onPressed: bedienung.uebernimm,
              child: Text(t.rundungenUebernehmen),
            ),
            TextButton(
              key: const ValueKey('rundungen-zuruecksetzen'),
              onPressed: bedienung.setzeZurueck,
              child: Text(t.rundungenZuruecksetzen),
            ),
          ],
        );
      },
    );
  }
}

/// Rückfrage beim Verlassen des Rundungsmodus (Abnahme M4-11): `true` =
/// übernehmen, `false` = zurücksetzen.
class RundungVerlassenDialog extends StatelessWidget {
  const RundungVerlassenDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return AlertDialog(
      key: const ValueKey('rundung-verlassen'),
      title: Text(t.rundungVerlassenTitel),
      content: Text(t.rundungVerlassenText),
      actions: [
        TextButton(
          key: const ValueKey('rundung-verlassen-zuruecksetzen'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.rundungenZuruecksetzen),
        ),
        FilledButton(
          key: const ValueKey('rundung-verlassen-uebernehmen'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.rundungenUebernehmen),
        ),
      ],
    );
  }
}
