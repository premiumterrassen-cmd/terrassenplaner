import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_client/json.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Verbindung der Web-App zum Planer-Router (anonym, Rolle Kunde).
class PlanerVerbindung {
  PlanerVerbindung(this.adresse);

  final Uri adresse;

  /// Ruft die Hallo-Prozedur auf und liefert die Antwort des Servers.
  Future<String> hallo() async {
    final client = Client(
      realm: WampNamen.realm,
      transport: WebSocketTransport(
        adresse.toString(),
        Serializer(),
        WebSocketSerialization.serializationJson,
      ),
    );
    final sitzung = await client
        .connect(options: ClientConnectOptions(reconnectCount: 0))
        .first
        .timeout(const Duration(seconds: 15));
    try {
      final antwort = await sitzung.callSingle(WampNamen.hallo);
      return antwort.arguments!.single as String;
    } finally {
      await sitzung.close();
    }
  }
}
