import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/planer_texte.dart';

export '../../l10n/planer_texte.dart';

/// Gewählte Sprache der Oberfläche (M3-07) – eine reine
/// Bedienungseinstellung; Deutsch ist Standard. Gespeichert wird sie ab
/// M3-09.
class SprachSteuerung extends ValueNotifier<Locale> {
  SprachSteuerung([super.sprache = standard]);

  static const standard = Locale('de');

  /// Alle Sprachen mit Übersetzungsdatei (`lib/l10n/planer_*.arb`).
  static const sprachen = PlanerTexte.supportedLocales;
}

/// Kurzer Zugriff auf die Texte der aktuellen Sprache.
extension TexteImKontext on BuildContext {
  PlanerTexte get texte => PlanerTexte.of(this);
}

/// Zahl nach [muster] (z. B. `0.00`) im Format der Sprache [texte]:
/// „12,50“ auf Deutsch, „12.50“ auf Englisch.
String zahlText(PlanerTexte texte, double wert, String muster) =>
    NumberFormat(muster, texte.localeName).format(wert);

/// Sprachauswahl in der Kopfzeile: zeigt das Kürzel der aktuellen Sprache.
class Sprachauswahl extends StatelessWidget {
  const Sprachauswahl({required this.sprache, super.key});

  final SprachSteuerung sprache;

  @override
  Widget build(BuildContext context) => PopupMenuButton<Locale>(
    key: const ValueKey('sprachauswahl'),
    tooltip: context.texte.sprache,
    initialValue: sprache.value,
    onSelected: (gewaehlt) => sprache.value = gewaehlt,
    itemBuilder: (_) => [
      for (final s in SprachSteuerung.sprachen)
        PopupMenuItem(
          key: ValueKey('sprache-${s.languageCode}'),
          value: s,
          child: Text(lookupPlanerTexte(s).sprachname),
        ),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language),
          const SizedBox(width: 4),
          Text(sprache.value.languageCode.toUpperCase()),
        ],
      ),
    ),
  );
}
