import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../sprache/sprache.dart';
import 'modell3d_ansicht.dart';

/// Lädt das GLB vom Server; in Tests austauschbar.
typedef Modell3dAbfrage = Future<Uint8List> Function();

/// Prototyp-Seite (M3-10): lädt das 3D-Modell einer Rechteck-Terrasse vom
/// Server und zeigt es an.
class Modell3dSeite extends StatefulWidget {
  const Modell3dSeite({required this.lade, super.key});

  final Modell3dAbfrage lade;

  @override
  State<Modell3dSeite> createState() => _Modell3dSeiteState();
}

class _Modell3dSeiteState extends State<Modell3dSeite> {
  late final Future<Uint8List> _glb = widget.lade();

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return Scaffold(
      appBar: AppBar(title: Text(t.modell3dTitel)),
      body: FutureBuilder<Uint8List>(
        future: _glb,
        builder: (context, stand) => switch (stand) {
          AsyncSnapshot(hasData: true, :final data) => modell3dAnsicht(
            data!,
            titel: t.modell3dTitel,
          ),
          AsyncSnapshot(hasError: true) => Center(
            child: Text(t.modell3dFehler),
          ),
          _ => Center(child: Text(t.modell3dLaedt)),
        },
      ),
    );
  }
}
