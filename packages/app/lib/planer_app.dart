import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'src/design/planer_design.dart';
import 'src/rahmen/planer_rahmen.dart';
import 'src/start/eingangsdialog.dart';

/// Liefert die Begrüßung des Servers (M0-12); in Tests austauschbar.
typedef HalloAbfrage = Future<String> Function();

/// Wurzel-Widget der Planer-Oberfläche.
class PlanerApp extends StatelessWidget {
  const PlanerApp({
    required this.hallo,
    required this.laden,
    required this.gespeichert,
    super.key,
    this.info = terrassenplaner,
  });

  final ProjektInfo info;
  final HalloAbfrage hallo;
  final KonfigurationLaden laden;
  final GespeicherteKonfiguration gespeichert;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: info.titel,
    theme: planerThema(),
    debugShowCheckedModeBanner: false,
    home: PlanerStart(
      laden: laden,
      gespeichert: gespeichert,
      child: PlanerRahmen(status: ServerStatus(hallo: hallo)),
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

  static const verbinde = 'Verbinde mit dem Server …';
  static const keineVerbindung = 'Keine Verbindung zum Server';

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
        AsyncSnapshot(hasError: true) => ServerStatus.keineVerbindung,
        _ => ServerStatus.verbinde,
      }),
    );
  }
}
