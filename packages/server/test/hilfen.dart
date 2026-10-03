import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Freie lokale Adresse `127.0.0.1:<port>` (für Listener mit festem Port).
Future<String> freieAdresse() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return '127.0.0.1:$port';
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

/// Startet bin/auth_server.dart als eigenen Prozess (eigenes TMPDIR wegen der
/// Sperrdatei der connectanum-Transportschicht) und wartet auf „bereit“.
Future<Process> starteAuthServerProzess({
  required String listen,
  required List<MitarbeiterZugang> mitarbeiter,
}) async {
  final ordner = Directory.systemTemp.createTempSync('auth-server-');
  final datei = File('${ordner.path}/mitarbeiter.json')
    ..writeAsStringSync(jsonEncode([for (final m in mitarbeiter) m.alsJson()]));
  final prozess = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'bin/auth_server.dart'],
    environment: {
      'TMPDIR': '${ordner.path}/',
      'PLANER_AUTH_TOKEN': testToken,
      'PLANER_AUTH_DIENST_TICKET': testTicket,
      'PLANER_AUTH_LISTEN': listen,
      'PLANER_AUTH_HEALTH_LISTEN': await freieAdresse(),
      'PLANER_MITARBEITER_DATEI': datei.path,
    },
  );
  final bereit = Completer<void>();
  prozess.stdout.transform(utf8.decoder).listen((zeile) {
    if (zeile.contains('Auth-Server bereit') && !bereit.isCompleted) {
      bereit.complete();
    }
  });
  unawaited(prozess.stderr.drain<void>());
  await bereit.future.timeout(const Duration(minutes: 2));
  return prozess;
}
