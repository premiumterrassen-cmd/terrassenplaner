import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'freiform.dart';
import 'grundriss_eingabe.dart';
import 'steuerung.dart';

/// Abgewiesene Änderung: die erste Meldung und die geprüften Ausschnitte
/// (darin auch ein neuer, den es im Planungsstand noch nicht gibt).
typedef AusschnittAblehnung = ({
  AusschnittMeldung meldung,
  List<Ausschnitt> ausschnitte,
});

/// Ändert Ausschnitte nur, wenn die Prüfungen (Fachkonzept 1.4, M4-12)
/// bestehen: nicht außerhalb, keine Kollision, keine Teilung. Sonst bleibt
/// der Stand, und die erste Meldung kommt zurück.
class AusschnittBedienung {
  AusschnittBedienung({
    required this.planung,
    required this.modus,
    required this.onGeaendert,
  });

  final PlanungsSteuerung planung;

  /// Einrastfunktion beim Verschieben (M4-08).
  final ZeichenModus modus;

  /// Meldet eine übernommene Eingabe (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  Planungsstand? _vorZiehen;

  /// Übernimmt [neu], wenn alle Ausschnitte stimmen.
  AusschnittAblehnung? aendere(Planungsstand neu) {
    final meldungen = pruefeAusschnitte(neu);
    if (meldungen.isNotEmpty) {
      return (meldung: meldungen.first, ausschnitte: neu.ausschnitte);
    }
    planung.setze(neu);
    onGeaendert();
    return null;
  }

  /// „Weitere Flächen hinzufügen“.
  AusschnittAblehnung? fuegeHinzu() =>
      aendere(planung.aktuell.mitNeuemAusschnitt());

  void entferne(int index) {
    planung.setze(planung.aktuell.ohneAusschnitt(index));
    onGeaendert();
  }

  /// Ersetzt Ausschnitt [index] durch das Ergebnis von [neu].
  AusschnittAblehnung? aendereAusschnitt(
    int index,
    Ausschnitt Function(Ausschnitt) neu,
  ) {
    final stand = planung.aktuell;
    return aendere(stand.mitAusschnitt(index, neu(stand.ausschnitte[index])));
  }

  /// Verschiebt Ausschnitt [index] um [versatz] mm seit Beginn (Ziehen in der
  /// Zeichnung, mit Einrasten); ungültige Lagen bleiben aus.
  void ziehe(int index, Punkt versatz, {required bool beginn}) {
    if (beginn) _vorZiehen = planung.aktuell;
    final alt = _vorZiehen!.ausschnitte[index];
    var ziel = Punkt(alt.x.mm + versatz.x, alt.y.mm + versatz.y);
    if (modus.einrasten) ziel = Zeichenhilfe.einrasten(ziel);
    final neu = _vorZiehen!.mitAusschnitt(
      index,
      alt.verschoben(
        Millimeter(ziel.x.round() - alt.x.mm),
        Millimeter(ziel.y.round() - alt.y.mm),
      ),
    );
    if (pruefeAusschnitte(neu).isNotEmpty) return;
    if (beginn) {
      planung.setze(neu);
      onGeaendert();
    } else {
      planung.ersetze(neu);
    }
  }

  /// Text der Meldung wie im alten Planer.
  static String text(PlanerTexte t, AusschnittAblehnung ablehnung) {
    final (:meldung, :ausschnitte) = ablehnung;
    final a = ausschnitte[meldung.ausschnitt].bezeichnung;
    return switch (meldung.problem) {
      AusschnittProblem.ausserhalb => t.meldungAusserhalb,
      AusschnittProblem.kollision => t.meldungKollision(
        a,
        ausschnitte[meldung.anderer!].bezeichnung,
      ),
      AusschnittProblem.teilung => t.meldungTeilung(a),
    };
  }

  /// Zeigt die Meldung als Dialog mit „SCHLIESSEN“ (wie im alten Planer).
  static Future<void> melde(
    BuildContext context,
    AusschnittAblehnung? ablehnung,
  ) async {
    if (ablehnung == null) return;
    final t = context.texte;
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        key: const ValueKey('ausschnitt-meldung'),
        content: Text(text(t, ablehnung)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(t.schliessen),
          ),
        ],
      ),
    );
  }
}

/// Ausschnitte und Teilflächen unter 1.4 (Fachkonzept 1.4, M4-06/M4-12): je
/// Fläche ein Block „Ausschnitt A1“ mit Form, X/Y, Länge/Breite, Funktion,
/// Inhalt und Bezeichnung; darunter „Weitere Flächen hinzufügen“.
class AusschnittMasse extends StatelessWidget {
  const AusschnittMasse({required this.bedienung, super.key});

  final AusschnittBedienung bedienung;

  static String formName(PlanerTexte t, Ausschnittform form) => switch (form) {
    Ausschnittform.rechteck => t.formRechteck,
    Ausschnittform.dreieck => t.formDreieck,
    Ausschnittform.sechseck => t.formSechseck,
    Ausschnittform.kreis => t.formKreis,
  };

  static String inhaltName(PlanerTexte t, Ausschnittinhalt inhalt) =>
      switch (inhalt) {
        Ausschnittinhalt.leer => t.inhaltLeer,
        Ausschnittinhalt.kiesHell => t.inhaltKies,
        Ausschnittinhalt.steinDunkel => t.inhaltStein,
        Ausschnittinhalt.pool => t.inhaltPool,
        Ausschnittinhalt.rasen => t.inhaltRasen,
        Ausschnittinhalt.erde => t.inhaltErde,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final ausschnitte = bedienung.planung.aktuell.ausschnitte;
    Future<void> melde(AusschnittAblehnung? m) =>
        AusschnittBedienung.melde(context, m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, a) in ausschnitte.indexed) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  t.ausschnittTitel(a.bezeichnung),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                key: ValueKey('ausschnitt-$i-entfernen'),
                tooltip: t.ausschnittEntfernen,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => bedienung.entferne(i),
              ),
            ],
          ),
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final form in Ausschnittform.values)
                ChoiceChip(
                  key: ValueKey('ausschnitt-$i-form-${form.name}'),
                  label: Text(formName(t, form)),
                  selected: a.form == form,
                  onSelected: (_) => melde(
                    bedienung.aendereAusschnitt(i, (x) => x.mitForm(form)),
                  ),
                ),
            ],
          ),
          MassFelder(
            key: ValueKey(('ausschnitt', i, a.form)),
            schluessel: 'ausschnitt-$i',
            namen: [
              'X',
              'Y',
              t.feldLaenge,
              if (a.form != Ausschnittform.kreis) t.feldBreite,
            ],
            kleinstes: Ausschnitt.kleinsteSeite,
            uebernimm: (feld, wert) {
              final m = bedienung.aendereAusschnitt(
                i,
                (x) => x.mitMass(feld, wert),
              );
              if (m != null) {
                throw ArgumentError(AusschnittBedienung.text(t, m));
              }
            },
          ),
          SegmentedButton<Ausschnittfunktion>(
            key: ValueKey('ausschnitt-$i-funktion'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: Ausschnittfunktion.leer,
                label: Text(t.funktionLeer),
              ),
              ButtonSegment(
                value: Ausschnittfunktion.andererBelag,
                label: Text(t.funktionBelag),
              ),
            ],
            selected: {a.funktion},
            onSelectionChanged: (auswahl) => melde(
              bedienung.aendereAusschnitt(
                i,
                (x) => x.mitFunktion(auswahl.single),
              ),
            ),
          ),
          if (a.funktion == Ausschnittfunktion.leer)
            DropdownButton<Ausschnittinhalt>(
              key: ValueKey('ausschnitt-$i-inhalt'),
              isExpanded: true,
              value: a.inhalt,
              items: [
                for (final inhalt in Ausschnittinhalt.values)
                  DropdownMenuItem(
                    value: inhalt,
                    child: Text(inhaltName(t, inhalt)),
                  ),
              ],
              onChanged: (inhalt) => melde(
                bedienung.aendereAusschnitt(i, (x) => x.mitInhalt(inhalt!)),
              ),
            ),
          TextField(
            key: ValueKey('ausschnitt-$i-bezeichnung'),
            maxLength: 10,
            decoration: InputDecoration(
              isDense: true,
              labelText: t.feldBezeichnung,
              hintText: a.bezeichnung,
            ),
            onSubmitted: (text) {
              if (text.trim().isEmpty) return;
              bedienung.aendereAusschnitt(
                i,
                (x) => x.mitBezeichnung(text.trim()),
              );
            },
          ),
          const Divider(),
        ],
        OutlinedButton.icon(
          key: const ValueKey('weitere-flaeche'),
          icon: const Icon(Icons.add),
          label: Text(t.weitereFlaeche),
          onPressed: () => melde(bedienung.fuegeHinzu()),
        ),
      ],
    );
  }
}
