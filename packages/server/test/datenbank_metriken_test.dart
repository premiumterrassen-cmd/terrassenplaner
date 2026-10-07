import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

void main() {
  const kennzahlen = Kennzahlen(
    dateigroesse: 12288,
    letzteSequenz: 7,
    anzahl: {'Benutzer': 2, 'Aenderung': 7},
  );

  test('Prometheus-Textformat mit Dienst und Entitäten', () {
    expect(
      datenbankMetriken(kennzahlen, dienst: 'planer-auth'),
      '# HELP planer_datenbank_groesse_bytes Größe der Datenbankdatei.\n'
      '# TYPE planer_datenbank_groesse_bytes gauge\n'
      'planer_datenbank_groesse_bytes{dienst="planer-auth"} 12288\n'
      '# HELP planer_datenbank_sequenz Letzte Sequenznummer im Änderungsprotokoll.\n'
      '# TYPE planer_datenbank_sequenz gauge\n'
      'planer_datenbank_sequenz{dienst="planer-auth"} 7\n'
      '# HELP planer_datenbank_datensaetze Anzahl Datensätze je Entität.\n'
      '# TYPE planer_datenbank_datensaetze gauge\n'
      'planer_datenbank_datensaetze{dienst="planer-auth",entitaet="Benutzer"} 2\n'
      'planer_datenbank_datensaetze{dienst="planer-auth",entitaet="Aenderung"} 7\n',
    );
  });

  test('MetrikServer liefert /metrics und 404 für andere Pfade', () async {
    var abrufe = 0;
    final server = await MetrikServer.starte('127.0.0.1:0', () {
      abrufe++;
      return 'wert $abrufe\n';
    });
    addTearDown(server.stoppe);
    final http = HttpClient();
    addTearDown(http.close);

    final antwort = await (await http.get(
      '127.0.0.1',
      server.port,
      '/metrics',
    )).close();
    expect(antwort.statusCode, 200);
    expect(antwort.headers.contentType!.mimeType, 'text/plain');
    expect(antwort.headers.contentType!.parameters['version'], '0.0.4');
    expect(antwort.headers.contentType!.charset, 'utf-8');
    expect(
      await antwort.transform(const SystemEncoding().decoder).join(),
      'wert 1\n',
    );

    final fehlt = await (await http.get(
      '127.0.0.1',
      server.port,
      '/anders',
    )).close();
    expect(fehlt.statusCode, 404);
    await fehlt.drain<void>();
    expect(abrufe, 1);
  });
}
