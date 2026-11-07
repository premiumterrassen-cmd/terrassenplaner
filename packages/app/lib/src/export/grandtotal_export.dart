import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../datei/datei_angebot.dart';
import '../rahmen/steuerung.dart';
import '../sprache/sprache.dart';

/// Fordert die Importdatei für GrandTotal zur [planung] beim Server an
/// (M9-08); [adresse] ist die Adresse der Web-App für die Bild-Links.
typedef GrandTotalAnfordern = Future<String> Function(
  Planung planung,
  Uri adresse,
);

/// Was die Mitarbeiter-Ansicht für den Export für GrandTotal braucht: Die
/// Datei entsteht auf dem Server, die App bietet sie nur zum Speichern an.
final class GrandTotalExport {
  const GrandTotalExport({
    required this.anfordern,
    required this.adresse,
    this.anbieten = bieteDateiAn,
    this.stand,
  });

  final GrandTotalAnfordern anfordern;

  /// Adresse der Web-App; neben ihr liegen die Artikelbilder (M2-07).
  final Uri adresse;
  final DateiAnbieten anbieten;

  /// Gespeicherter Stand der Konfiguration für den Dateinamen; `null` oder
  /// ohne Ergebnis: noch nicht gespeichert.
  final KonfigurationsStand? Function()? stand;
}

/// Knopf „Export für GrandTotal“ (M9-08): fordert die Importdatei an und
/// bietet sie als `GrandTotal_Import_<Nummer>_v<Version>.csv` an; Erfolg
/// oder Fehler als Hinweis. Während der Anfrage ist er gesperrt.
class GrandTotalExportKnopf extends StatefulWidget {
  const GrandTotalExportKnopf({
    required this.export,
    required this.planung,
    super.key,
  });

  final GrandTotalExport export;
  final PlanungsSteuerung planung;

  @override
  State<GrandTotalExportKnopf> createState() => _GrandTotalExportKnopfState();
}

class _GrandTotalExportKnopfState extends State<GrandTotalExportKnopf> {
  var _laeuft = false;

  Future<void> _exportiere() async {
    final messenger = ScaffoldMessenger.of(context);
    final t = context.texte;
    final export = widget.export;
    setState(() => _laeuft = true);
    String meldung;
    try {
      final inhalt = await export.anfordern(
        widget.planung.planung,
        export.adresse,
      );
      final name = grandTotalDateiname(export.stand?.call());
      export.anbieten(name, utf8.encode(inhalt), 'text/csv;charset=utf-8');
      meldung = t.exportGrandTotalFertig(name);
    } on Object {
      meldung = t.exportGrandTotalFehler;
    }
    if (mounted) setState(() => _laeuft = false);
    messenger.showSnackBar(SnackBar(content: Text(meldung)));
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('export-grandtotal'),
    onPressed: _laeuft ? null : _exportiere,
    icon: const Icon(Icons.download),
    label: Text(context.texte.exportGrandTotal),
  );
}
