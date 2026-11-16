import 'dart:io';
import 'dart:math';

/// Freie lokale Adresse `127.0.0.1:<port>` für Listener mit festem Port.
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
