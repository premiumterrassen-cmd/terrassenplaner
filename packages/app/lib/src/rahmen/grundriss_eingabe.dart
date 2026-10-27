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
              planung.setze(planung.aktuell.mitGrundriss(form.vorgabe));
              onGeaendert();
            },
          ),
      ],
    );
  }
}

/// Terrassenmaße der gewählten Form (Fachkonzept 1.2, M4-02/M4-03): ein Feld
/// je Eingabekante in cm. Wie im alten Planer zeigen die Felder nur
/// Platzhalter, die aktuellen Maße stehen in der Zeichnung; Enter übernimmt
/// den Wert in den Planungsstand.
class GrundrissMasse extends StatefulWidget {
  const GrundrissMasse({
    required this.planung,
    required this.onGeaendert,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Meldet eine übernommene Eingabe (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  State<GrundrissMasse> createState() => _GrundrissMasseState();
}

class _GrundrissMasseState extends State<GrundrissMasse> {
  late final List<String> _kanten =
      widget.planung.aktuell.grundriss.form.eingabekanten;
  late final _felder = [for (final _ in _kanten) TextEditingController()];
  late final _fehler = <String?>[for (final _ in _kanten) null];

  @override
  void dispose() {
    for (final feld in _felder) {
      feld.dispose();
    }
    super.dispose();
  }

  void _uebernimm(int index, String text) {
    final stand = widget.planung.aktuell;
    final cm = num.tryParse(text.trim().replaceAll(',', '.'));
    final Grundriss neu;
    try {
      neu = stand.grundriss.mitMass(index, Millimeter.ausCm(cm!));
    } on Object {
      // keine Zahl, oder eine Seite (auch abgeleitet) außerhalb der Grenzen
      setState(
        () => _fehler[index] = context.texte.massUngueltig(
          Grundriss.kleinsteSeite.mm ~/ 10,
          Grundriss.groessteSeite.mm ~/ 10,
        ),
      );
      return;
    }
    widget.planung.setze(stand.mitGrundriss(neu));
    widget.onGeaendert();
    _felder[index].clear();
    setState(() => _fehler[index] = null);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < _kanten.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: PlanerAbstand.klein),
          child: TextField(
            key: ValueKey('mass-$i'),
            controller: _felder[i],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              hintText: context.texte.massPlatzhalter(_kanten[i]),
              errorText: _fehler[i],
            ),
            onSubmitted: (text) => _uebernimm(i, text),
          ),
        ),
    ],
  );
}
