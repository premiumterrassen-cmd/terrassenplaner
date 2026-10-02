import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Wurzel-Widget der Planer-Oberfläche.
class PlanerApp extends StatelessWidget {
  const PlanerApp({super.key, this.info = terrassenplaner});

  final ProjektInfo info;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: info.titel,
      home: Scaffold(body: Center(child: Text(info.titel))),
    );
  }
}
