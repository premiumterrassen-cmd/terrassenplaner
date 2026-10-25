import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'modell3d_ansicht.dart';

/// Lädt das GLB vom Server; in Tests austauschbar.
typedef Modell3dAbfrage = Future<Uint8List> Function();

/// Prototyp-Seite (M3-10): lädt das 3D-Modell einer Rechteck-Terrasse vom
/// Server und zeigt es an.
class Modell3dSeite extends StatefulWidget {
  const Modell3dSeite({required this.lade, super.key});

  final Modell3dAbfrage lade;

  static const titel = '3D-Vorschau (Prototyp): Terrasse 4 x 3 m';
  static const laedt = 'Lade 3D-Modell …';
  static const fehler = '3D-Modell konnte nicht geladen werden';

  @override
  State<Modell3dSeite> createState() => _Modell3dSeiteState();
}

class _Modell3dSeiteState extends State<Modell3dSeite> {
  late final Future<Uint8List> _glb = widget.lade();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(Modell3dSeite.titel)),
    body: FutureBuilder<Uint8List>(
      future: _glb,
      builder: (context, stand) => switch (stand) {
        AsyncSnapshot(hasData: true, :final data) => modell3dAnsicht(
          data!,
          titel: Modell3dSeite.titel,
        ),
        AsyncSnapshot(hasError: true) => const Center(
          child: Text(Modell3dSeite.fehler),
        ),
        _ => const Center(child: Text(Modell3dSeite.laedt)),
      },
    ),
  );
}
