import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../konfiguration/konfigurations_steuerung.dart';
import '../rahmen/planer_rahmen.dart';
import '../sprache/sprache.dart';

/// Lädt eine gespeicherte Konfiguration über den Server (M9-05).
typedef KonfigurationLaden = Future<void> Function(KonfigurationsStand stand);

/// Speichert die aktuelle Planung und liefert Nummer und Version (M9-05).
typedef KonfigurationSpeichern = Future<KonfigurationsStand> Function();

/// Wie der Eingangsdialog verlassen wurde.
enum Startweg { neu, geladen, weiterplanen }

/// Eingangsdialog (M3-02, Fachkonzept 00): neu konfigurieren, gespeicherte
/// Konfiguration laden oder – wenn eine gefunden wurde – weiterplanen.
class Eingangsdialog extends StatelessWidget {
  const Eingangsdialog({required this.laden, super.key, this.gefunden});

  final KonfigurationLaden laden;

  /// Gespeicherte Konfiguration oder Entwurf, falls vorhanden (M9-05).
  final Fund? gefunden;

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
            if (gefunden case final fund?) ...[
              const SizedBox(height: PlanerAbstand.gross),
              Text(switch (fund.stand) {
                final stand? => t.gefunden(stand.nummer.wert, stand.version),
                null => t.gefundenEntwurf,
              }, textAlign: TextAlign.center),
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

/// „Konfiguration laden“ (Fachkonzept 08): Konfigurationsnummer, Version
/// (−/+), „Konfiguration Speichern“ (nur mit [speichern], aus der Kopfzeile)
/// und „Konfiguration laden“.
class LadenDialog extends StatefulWidget {
  const LadenDialog({
    required this.laden,
    super.key,
    this.speichern,
    this.vorgabe,
  });

  final KonfigurationLaden laden;
  final KonfigurationSpeichern? speichern;

  /// Vorbelegung von Nummer und Version (die geöffnete Konfiguration).
  final KonfigurationsStand? vorgabe;

  @override
  State<LadenDialog> createState() => _LadenDialogState();
}

/// Meldung unter den Feldern; der Text folgt der aktuellen Sprache.
enum _Meldung { keine, unbekannt, ladeFehler, speichernFehler, gespeichert }

class _LadenDialogState extends State<LadenDialog> {
  late final _nummer = TextEditingController(text: widget.vorgabe?.nummer.wert);
  late var _version = widget.vorgabe?.version ?? 1;
  var _nummerFalsch = false;
  var _meldung = _Meldung.keine;
  var _beschaeftigt = false;

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
    _beginne();
    final navigator = Navigator.of(context);
    try {
      await widget.laden(KonfigurationsStand(nummer, _version));
      navigator.pop(true);
    } on KonfigurationNichtGefunden {
      _beende(_Meldung.unbekannt);
    } on Object {
      _beende(_Meldung.ladeFehler);
    }
  }

  Future<void> _speichere(KonfigurationSpeichern speichern) async {
    _beginne();
    try {
      final stand = await speichern();
      _nummer.text = stand.nummer.wert;
      _version = stand.version;
      _beende(_Meldung.gespeichert);
    } on Object {
      _beende(_Meldung.speichernFehler);
    }
  }

  void _beginne() => setState(() {
    _nummerFalsch = false;
    _meldung = _Meldung.keine;
    _beschaeftigt = true;
  });

  void _beende(_Meldung meldung) {
    if (!mounted) return;
    setState(() {
      _meldung = meldung;
      _beschaeftigt = false;
    });
  }

  String? _text(PlanerTexte t) => switch (_meldung) {
    _Meldung.keine => null,
    _Meldung.unbekannt => t.konfigurationUnbekannt,
    _Meldung.ladeFehler => t.ladeFehler,
    _Meldung.speichernFehler => t.speichernFehler,
    _Meldung.gespeichert => t.gespeichertMeldung(_nummer.text, _version),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final speichern = widget.speichern;
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
          if (_text(t) case final text?)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                text,
                key: const ValueKey('laden-meldung'),
                style: _meldung == _Meldung.gespeichert
                    ? null
                    : TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.zurueck),
        ),
        if (speichern != null)
          OutlinedButton(
            key: const ValueKey('laden-speichern'),
            onPressed: _beschaeftigt ? null : () => _speichere(speichern),
            child: Text(t.konfigurationSpeichernKnopf),
          ),
        FilledButton(
          key: const ValueKey('laden-bestaetigen'),
          onPressed: _beschaeftigt ? null : _lade,
          child: Text(t.ladenTitel),
        ),
      ],
    );
  }
}
