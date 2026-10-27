import 'package:flutter/material.dart';
import 'package:terrassenplaner_app/src/sprache/sprache.dart';

/// Texte der beiden Sprachen für Erwartungen in Tests (M3-07).
final de = lookupPlanerTexte(const Locale('de'));
final en = lookupPlanerTexte(const Locale('en'));

/// MaterialApp mit den Übersetzungen des Planers, standardmäßig Deutsch.
Widget testApp({
  required Widget home,
  ThemeData? theme,
  Locale sprache = SprachSteuerung.standard,
}) => MaterialApp(
  theme: theme,
  locale: sprache,
  localizationsDelegates: PlanerTexte.localizationsDelegates,
  supportedLocales: SprachSteuerung.sprachen,
  home: home,
);
