import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'src/design/darstellung.dart';
import 'src/design/planer_design.dart';
import 'src/rahmen/berechnung_steuerung.dart';
import 'src/rahmen/planer_rahmen.dart';
import 'src/sprache/sprache.dart';
import 'src/start/eingangsdialog.dart';

/// Liefert die Begrüßung des Servers (M0-12); in Tests austauschbar.
typedef HalloAbfrage = Future<String> Function();

/// Wurzel-Widget der Planer-Oberfläche.
class PlanerApp extends StatefulWidget {
  const PlanerApp({
    required this.hallo,
    required this.laden,
    required this.gespeichert,
    super.key,
    this.info = terrassenplaner,
    this.berechne,
    this.sprache,
    this.darstellung,
  });

  final ProjektInfo info;
  final HalloAbfrage hallo;
  final KonfigurationLaden laden;
  final GespeicherteKonfiguration gespeichert;

  /// Berechnung auf dem Server (M4-02).
  final PlanungBerechnen? berechne;

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

  @override
  void dispose() {
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
        laden: widget.laden,
        gespeichert: widget.gespeichert,
        child: PlanerRahmen(
          status: ServerStatus(hallo: widget.hallo),
          berechne: widget.berechne,
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
    required this.laden,
    required this.gespeichert,
    required this.child,
    super.key,
  });

  final KonfigurationLaden laden;
  final GespeicherteKonfiguration gespeichert;
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
    final gefunden = await widget.gespeichert();
    if (!mounted) return;
    await showDialog<Startweg>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Eingangsdialog(laden: widget.laden, gefunden: gefunden),
    );
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
