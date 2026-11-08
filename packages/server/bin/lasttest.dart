import 'dart:convert';
import 'dart:io';

import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Last- und Leistungstest (M10-02) gegen einen laufenden Planer-Router –
/// Ablauf siehe tool/lasttest.sh und docs/abnahme/lasttest.md.
Future<void> main(List<String> argumente) async {
  final LasttestOptionen optionen;
  try {
    optionen = LasttestOptionen.lies(argumente);
  } on FormatException catch (fehler) {
    stderr.writeln(fehler.message);
    exitCode = 64;
    return;
  }
  switch (optionen) {
    case ArtikeldateiSchreiben(:final pfad):
      File(pfad)
          .writeAsStringSync(jsonEncode(Lastdaten.artikeldatei.alsJson()));
    case final Lauf lauf:
      final bericht = await Lasttest.fuehreAus(
        lauf,
        () => Client(
          realm: WampNamen.realm,
          transport: WebSocketTransport.withFlatBuffersSerializer(lauf.url),
        ).connect().first,
        messe: switch (lauf.pid) {
          null => null,
          final pid => () => Prozessmessung.lies(pid),
        },
        messeLast: () => Prozessmessung.lies(pid),
        melde: stdout.writeln,
      );
      if (lauf.ausgabe case final pfad?) {
        File(pfad).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(bericht.alsJson()),
        );
      }
      if (!bericht.zielwerteErreicht) exitCode = 1;
  }
}
