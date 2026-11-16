import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Freie lokale Adresse `127.0.0.1:<port>` (für Listener mit festem Port).
///
/// Der Port liegt unterhalb der flüchtigen Ports (Linux ab 32768, macOS ab
/// 49152). Einen Port aus `bind(0)` vergibt das System auch an ausgehende
/// Verbindungen paralleler Tests, die ihn zwischen Prüfen und Binden belegen
/// können (Mutation-Vollauf 15.11.2026, #139).
Future<String> freieAdresse() async {
  final zufall = Random();
  for (var versuch = 0; versuch < 100; versuch++) {
    final port = 20000 + zufall.nextInt(12000);
    try {
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await socket.close();
      return '127.0.0.1:$port';
    } on SocketException {
      continue;
    }
  }
  throw StateError('kein freier Port zwischen 20000 und 32000');
}

const testToken = 'test-auth-token';
const testTicket = 'test-dienst-ticket';

/// Planer-Router-Einstellungen für Tests: freie Ports, Auth-Server unter
/// [authAdresse] (Standard: freie Adresse ohne laufenden Auth-Server).
Future<RouterEinstellungen> testEinstellungen({String? authAdresse}) async =>
    RouterEinstellungen(
      authToken: testToken,
      dienstTicket: testTicket,
      port: 0,
      healthListen: await freieAdresse(),
      authAdresse: authAdresse ?? await freieAdresse(),
    );

/// Auth-Server-Einstellungen für Tests mit freien Ports.
Future<AuthServerEinstellungen> testAuthEinstellungen() async =>
    AuthServerEinstellungen(
      authToken: testToken,
      dienstTicket: testTicket,
      listen: await freieAdresse(),
      healthListen: await freieAdresse(),
    );

/// Startet bin/auth_server.dart als eigenen Prozess (gleiches TMPDIR wie der
/// Testprozess – ab connectanum beta.7 erlaubt), wartet auf „bereit“ und
/// legt die [mitarbeiter] über die Verwaltung an (M9-10).
Future<Process> starteAuthServerProzess({
  required String listen,
  required List<MitarbeiterZugang> mitarbeiter,
}) async {
  final ordner = Directory.systemTemp.createTempSync('auth-server-');
  final prozess = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'bin/auth_server.dart'],
    environment: {
      'PLANER_AUTH_TOKEN': testToken,
      'PLANER_AUTH_DIENST_TICKET': testTicket,
      'PLANER_AUTH_LISTEN': listen,
      'PLANER_AUTH_HEALTH_LISTEN': await freieAdresse(),
      // Mitarbeiter-Konten liegen in ObjectBox (M0-15, M9-10).
      'PLANER_DATENVERZEICHNIS': '${ordner.path}/daten',
      'PLANER_KNOTEN': 'test',
      // Freier Port: ein liegengebliebener Prozess darf spätere Starts nicht blockieren.
      'PLANER_DATENBANK_METRIKEN': await freieAdresse(),
    },
  );
  final bereit = Completer<void>();
  prozess.stdout.transform(utf8.decoder).listen((zeile) {
    if (zeile.contains('Auth-Server bereit') && !bereit.isCompleted) {
      bereit.complete();
    }
  });
  unawaited(prozess.stderr.drain<void>());
  // Endet der Prozess vor „bereit“ (z. B. bei einer Mutation), sofort scheitern
  // statt die volle Wartezeit abzusitzen.
  unawaited(
    prozess.exitCode.then((code) {
      if (!bereit.isCompleted) {
        bereit.completeError(StateError('Auth-Server beendet mit Code $code'));
      }
    }),
  );
  try {
    await bereit.future.timeout(const Duration(seconds: 30));
  } on Object {
    prozess.kill();
    rethrow;
  }
  final verwaltung = await MitarbeiterWerkzeug.verbinde({
    'PLANER_AUTH_ADRESSE': listen,
    'PLANER_AUTH_DIENST_TICKET': testTicket,
  });
  for (final m in mitarbeiter) {
    await verwaltung.rufe(MitarbeiterVerwaltung.anlegen, [m.alsJson()]);
  }
  await verwaltung.schliesse();
  return prozess;
}

/// Zufall zum Nachrechnen: zählt 0, 1, 2, … und merkt sich die Grenzen –
/// der erste Prüfcode ist `ABCDE`, der zweite `FGHJK` (M9-05b).
final class ZaehlZufall implements Random {
  var _n = 0;
  final grenzen = <int>{};

  @override
  int nextInt(int max) {
    grenzen.add(max);
    return _n++ % max;
  }

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}
