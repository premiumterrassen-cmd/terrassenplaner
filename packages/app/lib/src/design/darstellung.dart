import 'package:flutter/material.dart';

import '../sprache/sprache.dart';

/// Gewählte Darstellung (M3-09): hell, dunkel oder wie das System
/// (Standard) – eine reine Bedienungseinstellung.
class DarstellungSteuerung extends ValueNotifier<ThemeMode> {
  DarstellungSteuerung([super.darstellung = standard]);

  static const standard = ThemeMode.system;
}

/// Darstellungsauswahl in der Kopfzeile: Symbol der aktuellen Darstellung.
class Darstellungsauswahl extends StatelessWidget {
  const Darstellungsauswahl({required this.darstellung, super.key});

  final DarstellungSteuerung darstellung;

  static IconData symbol(ThemeMode modus) => switch (modus) {
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_outlined,
  };

  static String name(PlanerTexte t, ThemeMode modus) => switch (modus) {
    ThemeMode.light => t.darstellungHell,
    ThemeMode.dark => t.darstellungDunkel,
    ThemeMode.system => t.darstellungSystem,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return PopupMenuButton<ThemeMode>(
      key: const ValueKey('darstellungsauswahl'),
      tooltip: t.darstellung,
      initialValue: darstellung.value,
      onSelected: (gewaehlt) => darstellung.value = gewaehlt,
      itemBuilder: (_) => [
        for (final modus in ThemeMode.values)
          PopupMenuItem(
            key: ValueKey('darstellung-${modus.name}'),
            value: modus,
            child: ListTile(
              leading: Icon(symbol(modus)),
              title: Text(name(t, modus)),
            ),
          ),
      ],
      icon: Icon(
        symbol(darstellung.value),
        semanticLabel: '${t.darstellung}: ${name(t, darstellung.value)}',
      ),
    );
  }
}
