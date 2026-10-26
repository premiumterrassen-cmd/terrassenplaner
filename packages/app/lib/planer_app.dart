import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'src/design/planer_design.dart';
import 'src/rahmen/planer_rahmen.dart';

/// Liefert die Begrüßung des Servers (M0-12); in Tests austauschbar.
typedef HalloAbfrage = Future<String> Function();

/// Wurzel-Widget der Planer-Oberfläche.
class PlanerApp extends StatelessWidget {
  const PlanerApp({
    required this.hallo,
    super.key,
    this.info = terrassenplaner,
  });

  final ProjektInfo info;
  final HalloAbfrage hallo;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: info.titel,
    theme: planerThema(),
    debugShowCheckedModeBanner: false,
    home: PlanerRahmen(status: ServerStatus(hallo: hallo)),
  );
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
