import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'steuerung.dart';

/// Formwahl (Fachkonzept 1.1, M4-03): eine andere Form beginnt mit ihren
/// Vorgabemaßen.
class FormWahl extends StatelessWidget {
  const FormWahl({required this.planung, required this.onGeaendert, super.key});

  final PlanungsSteuerung planung;

  /// Meldet eine übernommene Eingabe (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  static String name(PlanerTexte t, Terrassenform form) => switch (form) {
    Terrassenform.rechteck => t.formRechteck,
    Terrassenform.lForm => t.formLForm,
    Terrassenform.tForm => t.formTForm,
    Terrassenform.uForm => t.formUForm,
    Terrassenform.oForm => t.formOForm,
    Terrassenform.kreis => t.formKreis,
    Terrassenform.freiform => t.formFreiform,
  };

  @override
  Widget build(BuildContext context) {
    final aktuell = planung.aktuell.grundriss.form;
    return Wrap(
      spacing: PlanerAbstand.klein,
      children: [
        for (final form in Terrassenform.values)
          ChoiceChip(
            key: ValueKey('form-${form.name}'),
            label: Text(name(context.texte, form)),
            selected: form == aktuell,
            onSelected: (_) {
              if (form == aktuell) return;
              planung.setze(planung.aktuell.mitForm(form));
              onGeaendert();
            },
          ),
      ],
    );
  }
}

/// Terrassenmaße der gewählten Form (Fachkonzept 1.2, M4-02/M4-03): ein Feld
/// je Eingabekante in cm.
class GrundrissMasse extends StatelessWidget {
  const GrundrissMasse({
    required this.planung,
    required this.onGeaendert,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Meldet eine übernommene Eingabe (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  Widget build(BuildContext context) => MassFelder(
    namen: planung.aktuell.grundriss.form.eingabekanten,
    kleinstes: Grundriss.kleinsteSeite,
    uebernimm: (index, wert) {
      final stand = planung.aktuell;
      planung.setze(stand.mitGrundriss(stand.grundriss.mitMass(index, wert)));
      onGeaendert();
    },
  );
}

/// Maßfelder in cm (M4-02): wie im alten Planer zeigen sie nur Platzhalter,
/// die aktuellen Maße stehen in der Zeichnung; Enter übernimmt den Wert.
/// Wirft [uebernimm] (keine Zahl, Grenze verletzt), erscheint ein Hinweis
/// mit den Grenzen [kleinstes] bis [Grundriss.groessteSeite].
class MassFelder extends StatefulWidget {
  const MassFelder({
    required this.namen,
    required this.kleinstes,
    required this.uebernimm,
    super.key,
    this.schluessel = 'mass',
    this.platzhalter,
  });

  /// Eigene Platzhalter je Feld; `null` (oder ein `null`-Eintrag) ergibt
  /// „Name: cm“.
  final List<String?>? platzhalter;

  /// Präfix der Feldschlüssel (`mass-0` …), eindeutig je Block.
  final String schluessel;

  /// Feldnamen für die Platzhalter („A — B: cm“).
  final List<String> namen;

  final Millimeter kleinstes;

  final void Function(int index, Millimeter wert) uebernimm;

  @override
  State<MassFelder> createState() => _MassFelderState();
}

class _MassFelderState extends State<MassFelder> {
  late final _felder = [for (final _ in widget.namen) TextEditingController()];
  late final _fehler = <String?>[for (final _ in widget.namen) null];

  @override
  void dispose() {
    for (final feld in _felder) {
      feld.dispose();
    }
    super.dispose();
  }

  void _uebernimm(int index, String text) {
    final cm = num.tryParse(text.trim().replaceAll(',', '.'));
    try {
      widget.uebernimm(index, Millimeter.ausCm(cm!));
    } on Object catch (fehler) {
      // keine Zahl, oder ein Maß (auch abgeleitet) außerhalb der Grenzen;
      // eine Rückmeldung mit eigenem Text (Freiform) wird übernommen
      setState(
        () => _fehler[index] = fehler is ArgumentError && fehler.name == null
            ? '${fehler.message}'
            : context.texte.massUngueltig(
                widget.kleinstes.mm ~/ 10,
                Grundriss.groessteSeite.mm ~/ 10,
              ),
      );
      return;
    }
    _felder[index].clear();
    setState(() => _fehler[index] = null);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < widget.namen.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: PlanerAbstand.klein),
          child: TextField(
            key: ValueKey('${widget.schluessel}-$i'),
            controller: _felder[i],
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              hintText:
                  widget.platzhalter?[i] ??
                  context.texte.massPlatzhalter(widget.namen[i]),
              errorText: _fehler[i],
            ),
            onSubmitted: (text) => _uebernimm(i, text),
          ),
        ),
    ],
  );
}
