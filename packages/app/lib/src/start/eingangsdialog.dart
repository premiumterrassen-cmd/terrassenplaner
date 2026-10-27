import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../rahmen/planer_rahmen.dart';
import '../sprache/sprache.dart';

/// Lädt eine gespeicherte Konfiguration (ab M9-05 über den Server).
typedef KonfigurationLaden = Future<void> Function(KonfigurationsStand stand);

/// Sucht eine im Browser zwischengespeicherte Konfiguration (ab M3-09).
typedef GespeicherteKonfiguration = Future<KonfigurationsStand?> Function();

/// Wie der Eingangsdialog verlassen wurde.
enum Startweg { neu, geladen, weiterplanen }

/// Eingangsdialog (M3-02, Fachkonzept 00): neu konfigurieren, gespeicherte
/// Konfiguration laden oder – wenn eine gefunden wurde – weiterplanen.
class Eingangsdialog extends StatelessWidget {
  const Eingangsdialog({required this.laden, super.key, this.gefunden});

  final KonfigurationLaden laden;

  /// Zwischengespeicherte Konfiguration, falls vorhanden.
  final KonfigurationsStand? gefunden;

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return AlertDialog(
      key: const ValueKey('eingangsdialog'),
      icon: Image.asset(Kopfzeile.logo, height: 72),
      title: Text(t.willkommenTitel, textAlign: TextAlign.center),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.willkommenText, textAlign: TextAlign.center),
            if (gefunden case final stand?) ...[
              const SizedBox(height: PlanerAbstand.gross),
              Text(
                t.gefunden(stand.nummer.wert, stand.version),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PlanerAbstand.klein),
              FilledButton(
                key: const ValueKey('weiterplanen'),
                style: FilledButton.styleFrom(
                  backgroundColor: PlanerFarben.gruen,
                ),
                onPressed: () =>
                    Navigator.of(context).pop(Startweg.weiterplanen),
                child: Text(t.weiterplanen),
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(
          key: const ValueKey('laden'),
          onPressed: () async {
            final navigator = Navigator.of(context);
            final geladen = await showDialog<bool>(
              context: context,
              builder: (_) => LadenDialog(laden: laden),
            );
            if (geladen ?? false) navigator.pop(Startweg.geladen);
          },
          child: Text(t.konfigurationLadenKnopf),
        ),
        FilledButton(
          key: const ValueKey('neu'),
          onPressed: () => Navigator.of(context).pop(Startweg.neu),
          child: Text(t.neuKnopf),
        ),
      ],
    );
  }
}

/// „Konfiguration laden“: Konfigurationsnummer und Version (−/+).
class LadenDialog extends StatefulWidget {
  const LadenDialog({required this.laden, super.key});

  final KonfigurationLaden laden;

  @override
  State<LadenDialog> createState() => _LadenDialogState();
}

class _LadenDialogState extends State<LadenDialog> {
  final _nummer = TextEditingController();
  var _version = 1;
  // Fehler als Schalter, der Text folgt der aktuellen Sprache.
  var _nummerFalsch = false;
  var _ladeFehler = false;
  var _laedt = false;

  @override
  void dispose() {
    _nummer.dispose();
    super.dispose();
  }

  Future<void> _lade() async {
    final Konfigurationsnummer nummer;
    try {
      nummer = Konfigurationsnummer.pruefe(_nummer.text);
    } on ArgumentError {
      setState(() => _nummerFalsch = true);
      return;
    }
    setState(() {
      _nummerFalsch = false;
      _ladeFehler = false;
      _laedt = true;
    });
    final navigator = Navigator.of(context);
    try {
      await widget.laden(KonfigurationsStand(nummer, _version));
      navigator.pop(true);
    } on Object {
      setState(() {
        _ladeFehler = true;
        _laedt = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return AlertDialog(
      key: const ValueKey('laden-dialog'),
      title: Text(t.ladenTitel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('nummer'),
            controller: _nummer,
            decoration: InputDecoration(
              labelText: t.nummerFeld,
              hintText: t.nummerHinweis,
              errorText: _nummerFalsch ? t.nummerFehler : null,
            ),
            onSubmitted: (_) => _lade(),
          ),
          const SizedBox(height: PlanerAbstand.mittel),
          Row(
            children: [
              Text(t.version),
              const Spacer(),
              IconButton(
                key: const ValueKey('version-minus'),
                icon: const Icon(Icons.remove),
                onPressed: _version > 1
                    ? () => setState(() => _version--)
                    : null,
              ),
              Text('$_version', key: const ValueKey('version')),
              IconButton(
                key: const ValueKey('version-plus'),
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _version++),
              ),
            ],
          ),
          if (_ladeFehler)
            Text(
              t.ladeFehler,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.zurueck),
        ),
        FilledButton(
          key: const ValueKey('laden-bestaetigen'),
          onPressed: _laedt ? null : _lade,
          child: Text(t.ladenTitel),
        ),
      ],
    );
  }
}
