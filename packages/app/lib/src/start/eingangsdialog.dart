import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../rahmen/planer_rahmen.dart';

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

  static const titel = 'Willkommen beim RobinienWelt Terrassenkonfigurator!';
  static const text =
      'Planen Sie Ihre Wunschterrasse aus Robinie mit wenigen Klicks: '
      'Dielen, Verlegung und Unterkonstruktion wählen Sie selbst. Danach '
      'bestellen Sie direkt oder fordern ein Angebot an. Persönliche Hilfe '
      'bekommen Sie in der Video-Beratung.';
  static const ladenKnopf = 'KONFIGURATION LADEN';
  static const neuKnopf = 'WUNSCHTERRASSE KONFIGURIEREN';
  static const gefundenText =
      'Wir haben eine Konfiguration gefunden. Möchten Sie mit dieser '
      'weiterplanen?';
  static const weiterKnopf = 'WEITERPLANEN';

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('eingangsdialog'),
    icon: Image.asset(Kopfzeile.logo, height: 72),
    title: const Text(titel, textAlign: TextAlign.center),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(text, textAlign: TextAlign.center),
          if (gefunden case final stand?) ...[
            const SizedBox(height: PlanerAbstand.gross),
            Text(
              '$gefundenText (${stand.nummer.wert}, Version ${stand.version})',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PlanerAbstand.klein),
            FilledButton(
              key: const ValueKey('weiterplanen'),
              style: FilledButton.styleFrom(
                backgroundColor: PlanerFarben.gruen,
              ),
              onPressed: () => Navigator.of(context).pop(Startweg.weiterplanen),
              child: const Text(weiterKnopf),
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
        child: const Text(ladenKnopf),
      ),
      FilledButton(
        key: const ValueKey('neu'),
        onPressed: () => Navigator.of(context).pop(Startweg.neu),
        child: const Text(neuKnopf),
      ),
    ],
  );
}

/// „Konfiguration laden“: Konfigurationsnummer und Version (−/+).
class LadenDialog extends StatefulWidget {
  const LadenDialog({required this.laden, super.key});

  final KonfigurationLaden laden;

  static const titel = 'Konfiguration laden';
  static const nummerFeld = 'Konfigurationsnummer';
  static const nummerHinweis = 'z. B. 2026-10-08-1511';
  static const nummerFehler = 'Bitte im Format JJJJ-MM-TT-NNNN eingeben';
  static const versionText = 'Version';
  static const ladenKnopf = 'Konfiguration laden';
  static const zurueckKnopf = 'Zurück';
  static const ladeFehler = 'Die Konfiguration konnte nicht geladen werden.';

  @override
  State<LadenDialog> createState() => _LadenDialogState();
}

class _LadenDialogState extends State<LadenDialog> {
  final _nummer = TextEditingController();
  var _version = 1;
  String? _nummerFehler;
  String? _ladeFehler;
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
      setState(() => _nummerFehler = LadenDialog.nummerFehler);
      return;
    }
    setState(() {
      _nummerFehler = null;
      _ladeFehler = null;
      _laedt = true;
    });
    final navigator = Navigator.of(context);
    try {
      await widget.laden(KonfigurationsStand(nummer, _version));
      navigator.pop(true);
    } on Object {
      setState(() {
        _ladeFehler = LadenDialog.ladeFehler;
        _laedt = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('laden-dialog'),
    title: const Text(LadenDialog.titel),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('nummer'),
          controller: _nummer,
          decoration: InputDecoration(
            labelText: LadenDialog.nummerFeld,
            hintText: LadenDialog.nummerHinweis,
            errorText: _nummerFehler,
          ),
          onSubmitted: (_) => _lade(),
        ),
        const SizedBox(height: PlanerAbstand.mittel),
        Row(
          children: [
            const Text(LadenDialog.versionText),
            const Spacer(),
            IconButton(
              key: const ValueKey('version-minus'),
              icon: const Icon(Icons.remove),
              onPressed: _version > 1 ? () => setState(() => _version--) : null,
            ),
            Text('$_version', key: const ValueKey('version')),
            IconButton(
              key: const ValueKey('version-plus'),
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => _version++),
            ),
          ],
        ),
        if (_ladeFehler case final fehler?)
          Text(
            fehler,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text(LadenDialog.zurueckKnopf),
      ),
      FilledButton(
        key: const ValueKey('laden-bestaetigen'),
        onPressed: _laedt ? null : _lade,
        child: const Text(LadenDialog.ladenKnopf),
      ),
    ],
  );
}
