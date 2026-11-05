import 'package:flutter/material.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'mitarbeiter_anmeldung.dart';

/// Dialog „Login“ (Fachkonzept 08, M9-10): E-Mail-Adresse und Passwort,
/// nur für Mitarbeiter. Schließt sich mit `true` nach erfolgreicher
/// Anmeldung; das Passwortfeld wird nach jedem Versuch geleert.
class AnmeldeDialog extends StatefulWidget {
  const AnmeldeDialog({required this.anmeldung, super.key});

  final MitarbeiterAnmeldung anmeldung;

  @override
  State<AnmeldeDialog> createState() => _AnmeldeDialogState();
}

enum _Meldung { keine, abgelehnt, fehler }

class _AnmeldeDialogState extends State<AnmeldeDialog> {
  final _email = TextEditingController();
  final _passwort = TextEditingController();
  var _meldung = _Meldung.keine;
  var _beschaeftigt = false;

  @override
  void dispose() {
    _email.dispose();
    _passwort.dispose();
    super.dispose();
  }

  Future<void> _anmelden() async {
    if (_beschaeftigt) return;
    final passwort = _passwort.text;
    setState(() {
      _meldung = _Meldung.keine;
      _beschaeftigt = true;
    });
    _passwort.clear();
    final navigator = Navigator.of(context);
    try {
      await widget.anmeldung.anmelden(_email.text, passwort);
      navigator.pop(true);
      return;
    } on AnmeldungAbgelehnt {
      _beende(_Meldung.abgelehnt);
    } on Object {
      _beende(_Meldung.fehler);
    }
  }

  void _beende(_Meldung meldung) {
    if (!mounted) return;
    setState(() {
      _meldung = meldung;
      _beschaeftigt = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final meldung = switch (_meldung) {
      _Meldung.keine => null,
      _Meldung.abgelehnt => t.anmeldungAbgelehnt,
      _Meldung.fehler => t.anmeldungFehler,
    };
    return AlertDialog(
      key: const ValueKey('anmelde-dialog'),
      title: Text(t.anmeldenTitel),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.anmeldenHinweis),
            const SizedBox(height: PlanerAbstand.mittel),
            TextField(
              key: const ValueKey('anmelden-email'),
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              decoration: InputDecoration(labelText: t.emailFeld),
            ),
            TextField(
              key: const ValueKey('anmelden-passwort'),
              controller: _passwort,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: t.passwortFeld),
              onSubmitted: (_) => _anmelden(),
            ),
            if (meldung != null) ...[
              const SizedBox(height: PlanerAbstand.mittel),
              Text(
                meldung,
                key: const ValueKey('anmelden-meldung'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.abbrechen),
        ),
        FilledButton(
          key: const ValueKey('anmelden-bestaetigen'),
          onPressed: _beschaeftigt ? null : _anmelden,
          child: Text(t.anmeldenKnopf),
        ),
      ],
    );
  }
}
