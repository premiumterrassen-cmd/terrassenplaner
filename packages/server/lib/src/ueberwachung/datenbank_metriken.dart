import 'dart:io';

import '../datenhaltung/datenbank.dart';

/// Kennzahlen der ObjectBox-Datenbank im Prometheus-Textformat (M0-14).
String datenbankMetriken(Kennzahlen k, {required String dienst}) {
  final zeilen = <String>[
    '# HELP planer_datenbank_groesse_bytes Größe der Datenbankdatei.',
    '# TYPE planer_datenbank_groesse_bytes gauge',
    'planer_datenbank_groesse_bytes{dienst="$dienst"} ${k.dateigroesse}',
    '# HELP planer_datenbank_sequenz Letzte Sequenznummer im Änderungsprotokoll.',
    '# TYPE planer_datenbank_sequenz gauge',
    'planer_datenbank_sequenz{dienst="$dienst"} ${k.letzteSequenz}',
    '# HELP planer_datenbank_datensaetze Anzahl Datensätze je Entität.',
    '# TYPE planer_datenbank_datensaetze gauge',
    for (final e in k.anzahl.entries)
      'planer_datenbank_datensaetze{dienst="$dienst",entitaet="${e.key}"} ${e.value}',
  ];
  return '${zeilen.join('\n')}\n';
}

/// Kleiner HTTP-Endpunkt `/metrics` (nur lokal) für die Datenbank-Kennzahlen.
class MetrikServer {
  MetrikServer._(this._server);

  /// Lauscht auf [adresse] (host:port, Port 0 = frei gewählt) und liefert bei
  /// jedem Abruf den aktuellen Text aus [inhalt].
  static Future<MetrikServer> starte(
    String adresse,
    String Function() inhalt,
  ) async {
    final teile = Uri.parse('tcp://$adresse');
    final server = await HttpServer.bind(teile.host, teile.port);
    server.listen((anfrage) {
      final antwort = anfrage.response;
      if (anfrage.uri.path == '/metrics') {
        antwort.headers.contentType = ContentType(
          'text',
          'plain',
          parameters: {'version': '0.0.4', 'charset': 'utf-8'},
        );
        antwort.write(inhalt());
      } else {
        antwort.statusCode = HttpStatus.notFound;
      }
      antwort.close();
    });
    return MetrikServer._(server);
  }

  final HttpServer _server;

  int get port => _server.port;

  Future<void> stoppe() => _server.close(force: true);
}
