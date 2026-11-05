import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../artikel/artikelbild_widget.dart';
import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'belag.dart';
import 'steuerung.dart';

/// Lädt die zum Belag passenden Unterkonstruktionen vom Server (M6-03);
/// `null` = der Vorgabe-Belag. In Tests austauschbar.
typedef UnterkonstruktionenLaden = Future<Ukauswahl> Function(
  Artikelnummer? belag,
);

/// Hält die Unterkonstruktionen des Servers zum gewählten Belag (M6-03):
/// wechselt der Belag, lädt sie neu; eine Antwort zu einem älteren Belag
/// wird verworfen. Die App rechnet nichts selbst.
class UkQuelle extends ChangeNotifier {
  UkQuelle({required this.lade, required this.planung}) {
    planung.addListener(_pruefe);
    ladeNeu();
  }

  final UnterkonstruktionenLaden lade;
  final PlanungsSteuerung planung;

  Ukauswahl? _auswahl;
  Object? _fehler;
  Artikelnummer? _belag;
  var _anfrage = 0;

  /// Geladene Auswahl; `null`, solange nichts geladen ist.
  Ukauswahl? get auswahl => _auswahl;

  /// Fehler des letzten Ladens; `null`, wenn es gelang.
  Object? get fehler => _fehler;

  void _pruefe() {
    if (planung.aktuell.belag != _belag) ladeNeu();
  }

  Future<void> ladeNeu() async {
    final belag = _belag = planung.aktuell.belag;
    final nummer = ++_anfrage;
    _fehler = null;
    notifyListeners();
    try {
      final auswahl = await lade(belag);
      if (nummer != _anfrage) return;
      _auswahl = auswahl;
    } on Object catch (fehler) {
      if (nummer != _anfrage) return;
      _fehler = fehler;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    // Antworten, die danach noch eintreffen, gelten als veraltet.
    _anfrage++;
    planung.removeListener(_pruefe);
    super.dispose();
  }
}

/// Unterpunkt „Unterkonstruktion auswählen“ (Fachkonzept 3.3, M6-03):
/// gewählte UK mit Bild, Name und Maßen und der Knopf „Produktauswahl“ wie
/// beim Belag (M5-01). Zur Auswahl stehen nur die zum Belag passenden UK.
class UkAnzeige extends StatelessWidget {
  const UkAnzeige({
    required this.quelle,
    required this.planung,
    required this.onGeaendert,
    super.key,
  });

  final UkQuelle quelle;
  final PlanungsSteuerung planung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  Future<void> _waehle(BuildContext context, Ukauswahl auswahl) async {
    final gewaehlt = await showDialog<Belagangebot>(
      context: context,
      builder: (_) => UkDialog(
        auswahl: auswahl,
        gewaehlt: auswahl.gewaehlt(planung.aktuell.unterkonstruktion),
      ),
    );
    if (gewaehlt == null) return;
    planung.setze(
      planung.aktuell.mitUnterkonstruktion(gewaehlt.artikel.nummer),
    );
    onGeaendert();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([quelle, planung]),
    builder: (context, _) {
      final t = context.texte;
      if (quelle.fehler != null) {
        return Row(
          children: [
            Expanded(child: Text(t.ukFehler)),
            TextButton(
              key: const ValueKey('uk-neu-laden'),
              onPressed: quelle.ladeNeu,
              child: Text(t.erneutVersuchen),
            ),
          ],
        );
      }
      final auswahl = quelle.auswahl;
      if (auswahl == null) return Text(t.ukLaedt);
      final uk = auswahl.gewaehlt(planung.aktuell.unterkonstruktion);
      if (uk == null) return Text(t.ukKeine);
      final a = uk.artikel;
      return Padding(
        key: const ValueKey('uk-anzeige'),
        padding: const EdgeInsets.symmetric(vertical: PlanerAbstand.klein),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artikelbild(a, groesse: 64),
            const SizedBox(width: PlanerAbstand.mittel),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.titel,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(t.belagMasse(belagMasse(a))),
                  const SizedBox(height: PlanerAbstand.klein),
                  OutlinedButton(
                    key: const ValueKey('uk-produktauswahl'),
                    onPressed: () => _waehle(context, auswahl),
                    child: Text(t.produktauswahl),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Dialog „Unterkonstruktion auswählen“ (Fachkonzept 3.3): Produktkarten
/// der passenden UK ohne Filter wie im alten Planer. Ein Klick auf eine
/// Karte wählt die UK.
class UkDialog extends StatelessWidget {
  const UkDialog({required this.auswahl, this.gewaehlt, super.key});

  final Ukauswahl auswahl;
  final Belagangebot? gewaehlt;

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return Dialog(
      key: const ValueKey('uk-dialog'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(PlanerAbstand.gross),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.ukDialogTitel,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: PlanerAbstand.mittel),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final a in auswahl.angebote)
                        Belagkarte(
                          angebot: a,
                          gewaehlt: a.artikel == gewaehlt?.artikel,
                          onTap: () => Navigator.of(context).pop(a),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: PlanerAbstand.mittel),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const ValueKey('uk-zurueck'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.zurueckZurKonfiguration),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unterpunkt „Länge der Unterkonstruktion“ (Fachkonzept 3.4, M6-03):
/// automatisch (Vorgabe, wie bei den Dielen R-B10) oder eine feste
/// Lieferlänge der gewählten UK (`ukLieferlaengen`).
class UkLaengeWahl extends StatelessWidget {
  const UkLaengeWahl({
    required this.quelle,
    required this.planung,
    required this.onGeaendert,
    super.key,
  });

  final UkQuelle quelle;
  final PlanungsSteuerung planung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  void _setze(Millimeter? laenge) {
    planung.setze(planung.aktuell.mitUkLaenge(laenge));
    onGeaendert();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([quelle, planung]),
    builder: (context, _) {
      final t = context.texte;
      final stand = planung.aktuell;
      final uk = quelle.auswahl?.gewaehlt(stand.unterkonstruktion)?.artikel;
      if (uk == null) return Text(t.ukLaengeOhneUk);
      final laengen = ukLieferlaengen(uk);
      final fest = laengen.contains(stand.ukLaenge) ? stand.ukLaenge : null;
      return Wrap(
        key: const ValueKey('uk-laenge'),
        spacing: PlanerAbstand.klein,
        children: [
          ChoiceChip(
            key: const ValueKey('uk-laenge-automatisch'),
            label: Text(t.automatisch),
            selected: fest == null,
            onSelected: (an) {
              if (an) _setze(null);
            },
          ),
          for (final l in laengen)
            ChoiceChip(
              key: ValueKey('uk-laenge-${l.mm}'),
              label: Text(t.dielenlaengeCm(l.mm ~/ 10)),
              selected: l == fest,
              onSelected: (an) {
                if (an) _setze(l);
              },
            ),
        ],
      );
    },
  );
}
