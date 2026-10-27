import 'package:flutter/material.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'planer_schritt.dart';
import 'rahmen_zustand.dart';

/// Hinweis vor Ergebnis und Angebot (M3-05): In diesen Schritten gelten
/// noch die Standardwerte. „Zurück“ (false) oder „Fortfahren“ (true).
class StandardwertHinweis extends StatelessWidget {
  const StandardwertHinweis({required this.schritte, super.key});

  final List<PlanerSchritt> schritte;

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return AlertDialog(
      key: const ValueKey('standardwert-hinweis'),
      title: Text(t.standardwertTitel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.standardwertText),
          const SizedBox(height: PlanerAbstand.klein),
          for (final s in schritte)
            Text(
              '• ${s.nummer}. ${s.titel(t)}',
              key: ValueKey('standardwert-${s.name}'),
            ),
          const SizedBox(height: PlanerAbstand.mittel),
          Text(t.standardwertFrage),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('standardwert-zurueck'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.zurueck),
        ),
        FilledButton(
          key: const ValueKey('standardwert-fortfahren'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.fortfahren),
        ),
      ],
    );
  }
}

/// Vor Ergebnis oder Angebot aufrufen (M3-06, M9): ohne unveränderte
/// Schritte geht es direkt weiter; sonst entscheidet der Kunde. Bei
/// „Zurück“ öffnet sich der erste unveränderte Schritt.
Future<bool> pruefeStandardwerte(
  BuildContext context,
  RahmenZustand zustand,
) async {
  final schritte = zustand.unveraendert;
  if (schritte.isEmpty) return true;
  final weiter = await showDialog<bool>(
    context: context,
    builder: (_) => StandardwertHinweis(schritte: schritte),
  );
  if (weiter ?? false) return true;
  zustand.waehle(schritte.first);
  return false;
}
