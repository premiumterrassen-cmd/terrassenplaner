import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../sprache/sprache.dart';

/// Erstes Bild eines Artikels (M2-07) – oder der Platzhalter, wenn der
/// Artikel kein Bild hat oder es nicht geladen werden kann.
class Artikelbild extends StatelessWidget {
  const Artikelbild(this.artikel, {super.key, this.groesse = 96});

  final Artikel artikel;
  final double groesse;

  @override
  Widget build(BuildContext context) {
    final platzhalter = ArtikelbildPlatzhalter(groesse: groesse);
    final bild = artikel.bilder.firstOrNull;
    if (bild == null) return platzhalter;
    Widget beiFehler(BuildContext _, Object _, StackTrace? _) => platzhalter;
    return Image.network(
      artikelbildAdresse(bild),
      width: groesse,
      height: groesse,
      fit: BoxFit.contain,
      semanticLabel: artikel.titel,
      errorBuilder: beiFehler,
    );
  }
}

/// Definierter Platzhalter für Artikel ohne Bild.
class ArtikelbildPlatzhalter extends StatelessWidget {
  const ArtikelbildPlatzhalter({super.key, this.groesse = 96});

  final double groesse;

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    return Semantics(
      label: context.texte.keinBild,
      child: Container(
        width: groesse,
        height: groesse,
        color: farben.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: groesse / 2,
          color: farben.onSurfaceVariant,
        ),
      ),
    );
  }
}
