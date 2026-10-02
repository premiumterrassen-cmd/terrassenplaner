import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Freie lokale Adresse `127.0.0.1:<port>` (für Listener mit festem Port).
Future<String> freieAdresse() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return '127.0.0.1:$port';
}

/// Router-Einstellungen für Tests: alle Ports frei gewählt.
Future<RouterEinstellungen> testEinstellungen() async => RouterEinstellungen(
  port: 0,
  healthListen: await freieAdresse(),
  authListen: await freieAdresse(),
);
