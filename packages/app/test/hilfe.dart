import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:terrassenplaner_app/src/anmeldung/mitarbeiter_anmeldung.dart';
import 'package:terrassenplaner_app/src/einstellungen/einstellungs_speicher.dart';
import 'package:terrassenplaner_app/src/einstellungen/lokale_einstellungen.dart';
import 'package:terrassenplaner_app/src/konfiguration/konfigurations_steuerung.dart';
import 'package:terrassenplaner_app/src/sprache/sprache.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

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

/// Gedächtnis im flüchtigen Speicher mit festem Zufall.
LokaleEinstellungen testGedaechtnis([EinstellungsSpeicher? speicher]) =>
    LokaleEinstellungen(speicher ?? FluechtigerSpeicher(), zufall: Random(1));

/// Prüfcode der [TestAblage] (M9-05b).
const testCode = Pruefcode('K7QXM');

/// Kennung `JJJJ-MM-TT-NNNN-XXXXX` für Tests.
Konfigurationskennung kennung(String text) => Konfigurationskennung.lies(text);

/// Stand aus Kennungstext und Version für Tests.
KonfigurationsStand stand(String kennungText, int version) =>
    KonfigurationsStand(kennung(kennungText), version);

/// Anmeldung wie der Server (M9-10): nur [email] mit [passwort] wird
/// angenommen; mit [erreichbar] = false scheitert jeder Versuch wie ohne
/// Server.
class TestAnmeldung implements MitarbeiterAnmeldung {
  TestAnmeldung({this.email = 'anna@example.test', this.passwort = 'richtig'});

  final String email;
  final String passwort;
  var erreichbar = true;

  /// Hält jeden Versuch an, bis der Test ihn freigibt.
  Completer<void>? sperre;
  final versuche = <(String, String)>[];

  final _angemeldetAls = ValueNotifier<String?>(null);

  @override
  ValueNotifier<String?> get angemeldetAls => _angemeldetAls;

  @override
  Future<void> anmelden(String email, String passwort) async {
    versuche.add((email, passwort));
    await sperre?.future;
    if (!erreichbar) throw StateError('Server nicht erreichbar');
    if (anmeldename(email) != this.email || passwort != this.passwort) {
      throw const AnmeldungAbgelehnt();
    }
    angemeldetAls.value = this.email;
  }

  @override
  Future<void> abmelden() async => angemeldetAls.value = null;
}

/// Ablage im Arbeitsspeicher wie der Konfigurationsdienst (M9-05); mit
/// [erreichbar] = false scheitert jeder Aufruf wie ohne Server.
class TestAblage implements KonfigurationsAblage {
  final versionen = <KonfigurationsStand, Planung>{};
  final entwuerfe = <String, PlanungsEntwurf>{};

  /// Aufrufe von [merkeEntwurf].
  var entwurfAufrufe = 0;
  var erreichbar = true;
  var _laufend = 0;

  void _pruefe() {
    if (!erreichbar) throw StateError('Server nicht erreichbar');
  }

  /// Jede neue Nummer bekommt den Prüfcode [testCode].
  @override
  Future<KonfigurationsStand> speichere(
    Planung planung, {
    Konfigurationskennung? kennung,
  }) async {
    _pruefe();
    final k =
        kennung ??
        Konfigurationskennung(
          Konfigurationsnummer.vergib(DateTime(2026, 11, 4), ++_laufend),
          testCode,
        );
    final version =
        versionen.keys
            .where((s) => s.kennung == k)
            .map((s) => s.version)
            .fold(0, max) +
        1;
    final stand = KonfigurationsStand(k, version);
    versionen[stand] = planung;
    return stand;
  }

  @override
  Future<Planung> lade(KonfigurationsStand stand) async {
    _pruefe();
    return versionen[stand] ?? (throw KonfigurationNichtGefunden.zu(stand));
  }

  /// Wie der Dienst für Mitarbeiter (M9-10): die Nummer genügt, die
  /// Antwort bringt die vollständige Kennung.
  @override
  Future<GeladeneKonfiguration> ladeOhnePruefcode(
    Konfigurationsnummer nummer,
    int version,
  ) async {
    _pruefe();
    for (final MapEntry(key: stand, value: planung) in versionen.entries) {
      if (stand.nummer == nummer && stand.version == version) {
        return (planung: planung, stand: stand);
      }
    }
    throw KonfigurationNichtGefunden(nummer.wert, version);
  }

  @override
  Future<void> merkeEntwurf(
    String schluessel,
    Planung planung, {
    KonfigurationsStand? bezug,
  }) async {
    entwurfAufrufe++;
    _pruefe();
    entwuerfe[schluessel] = (planung: planung, bezug: bezug);
  }

  @override
  Future<PlanungsEntwurf?> entwurf(String schluessel) async {
    _pruefe();
    return entwuerfe[schluessel];
  }
}
