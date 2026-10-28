import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'grundriss_eingabe.dart';
import 'steuerung.dart';
import 'zeichnung.dart';

/// Was im Rundungsmodus ausgewählt ist: eine Ecke (Radius) oder eine Seite
/// (Stich).
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
    final alt =
        (ziel.ecke ? _vorZiehen!.ecken : _vorZiehen!.seiten)[ziel.nummer]?.mm ??
        0;
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.rundungHinweis, key: const ValueKey('rundung-hinweis')),
            if (auswahl != null) ...[
              const SizedBox(height: PlanerAbstand.klein),
              Text(
                auswahl.ecke
                    ? t.rundungEcke(ZeichnungsMaler.punktname(auswahl.nummer))
                    : t.rundungSeite(ZeichnungsMaler.punktname(auswahl.nummer)),
                key: const ValueKey('rundung-auswahl'),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              MassFelder(
                key: ValueKey(auswahl),
                schluessel: 'rundung',
                namen: [auswahl.ecke ? t.feldRadius : t.feldStich],
                kleinstes: const Millimeter(0),
                uebernimm: (_, wert) {
                  if (!bedienung.setze(auswahl, wert)) {
                    throw ArgumentError(t.rundungUnzulaessig);
                  }
                },
              ),
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
