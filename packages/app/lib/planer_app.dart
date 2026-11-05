import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'src/design/darstellung.dart';
import 'src/design/planer_design.dart';
import 'src/export/grandtotal_export.dart';
import 'src/konfiguration/konfigurations_steuerung.dart';
import 'src/rahmen/belag.dart';
import 'src/rahmen/berechnung_steuerung.dart';
import 'src/rahmen/planer_rahmen.dart';
import 'src/rahmen/uk_auswahl.dart';
import 'src/sprache/sprache.dart';
import 'src/start/eingangsdialog.dart';

/// Liefert die Begrüßung des Servers (M0-12); in Tests austauschbar.
typedef HalloAbfrage = Future<String> Function();

/// Wurzel-Widget der Planer-Oberfläche.
class PlanerApp extends StatefulWidget {
  const PlanerApp({
    required this.hallo,
    required this.ablage,
    required this.gedaechtnis,
    super.key,
    this.info = terrassenplaner,
    this.berechne,
    this.belaege,
    this.unterkonstruktionen,
    this.exportGrandTotal,
    this.sprache,
    this.darstellung,
  });

  final ProjektInfo info;
  final HalloAbfrage hallo;

  /// Speichern und Laden auf dem Server (M9-05).
  final KonfigurationsAblage ablage;

  /// Gemerkte Konfiguration und Sitzungsschlüssel im Browser (M3-09, M9-05).
  final KonfigurationsGedaechtnis gedaechtnis;

  /// Berechnung auf dem Server (M4-02).
  final PlanungBerechnen? berechne;

  /// Beläge vom Server (M5-01).
  final BelaegeLaden? belaege;

  /// Unterkonstruktionen zum Belag vom Server (M6-03).
  final UnterkonstruktionenLaden? unterkonstruktionen;

  /// Export für GrandTotal vom Server (M9-08, Mitarbeiter-Ansicht).
  final GrandTotalAnfordern? exportGrandTotal;

  /// Sprache aus den lokalen Einstellungen (M3-09); ohne Vorgabe Deutsch
  /// (M3-07).
  final SprachSteuerung? sprache;

  /// Darstellung aus den lokalen Einstellungen (M3-09); ohne Vorgabe wie
  /// das System.
  final DarstellungSteuerung? darstellung;

  @override
  State<PlanerApp> createState() => _PlanerAppState();
}

class _PlanerAppState extends State<PlanerApp> {
  late final SprachSteuerung _sprache = widget.sprache ?? SprachSteuerung();
  late final DarstellungSteuerung _darstellung =
      widget.darstellung ?? DarstellungSteuerung();
  late final _konfiguration = KonfigurationsSteuerung(
    ablage: widget.ablage,
    gedaechtnis: widget.gedaechtnis,
  );

  @override
  void dispose() {
    _konfiguration.dispose();
    if (widget.sprache == null) _sprache.dispose();
    if (widget.darstellung == null) _darstellung.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_sprache, _darstellung]),
    builder: (context, _) => MaterialApp(
      title: widget.info.titel,
      theme: planerThema(),
      darkTheme: planerThema(Brightness.dark),
      themeMode: _darstellung.value,
      debugShowCheckedModeBanner: false,
      locale: _sprache.value,
      localizationsDelegates: PlanerTexte.localizationsDelegates,
      supportedLocales: SprachSteuerung.sprachen,
      home: PlanerStart(
        konfiguration: _konfiguration,
        child: PlanerRahmen(
          konfiguration: _konfiguration,
          status: ServerStatus(hallo: widget.hallo),
          berechne: widget.berechne,
          belaege: widget.belaege,
          unterkonstruktionen: widget.unterkonstruktionen,
          exportGrandTotal: widget.exportGrandTotal,
          sprache: _sprache,
          darstellung: _darstellung,
        ),
      ),
    ),
  );
}

/// Zeigt beim Start den Eingangsdialog über dem Rahmen (M3-02).
class PlanerStart extends StatefulWidget {
  const PlanerStart({
    required this.konfiguration,
    required this.child,
    super.key,
  });

  final KonfigurationsSteuerung konfiguration;
  final Widget child;

  @override
  State<PlanerStart> createState() => _PlanerStartState();
}

class _PlanerStartState extends State<PlanerStart> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _zeigeDialog());
  }

  Future<void> _zeigeDialog() async {
    final konfiguration = widget.konfiguration;
    final gefunden = await konfiguration.suche();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final fehler = context.texte.ladeFehler;
    final weg = await showDialog<Startweg>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          Eingangsdialog(laden: konfiguration.lade, gefunden: gefunden),
    );
    if (weg != Startweg.weiterplanen) return;
    try {
      await konfiguration.weiterplanen();
    } on Object {
      // Server nicht erreichbar: weiter mit der leeren Planung.
      messenger.showSnackBar(SnackBar(content: Text(fehler)));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Zeigt, ob die Verbindung zum Server steht.
class ServerStatus extends StatefulWidget {
  const ServerStatus({required this.hallo, super.key});

  final HalloAbfrage hallo;

  @override
  State<ServerStatus> createState() => _ServerStatusState();
}

class _ServerStatusState extends State<ServerStatus> {
  late final Future<String> _antwort = widget.hallo();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _antwort,
      builder: (context, stand) => Text(switch (stand) {
        AsyncSnapshot(hasData: true, :final data) => data!,
        AsyncSnapshot(hasError: true) => context.texte.keineVerbindung,
        _ => context.texte.verbinde,
      }),
    );
  }
}
