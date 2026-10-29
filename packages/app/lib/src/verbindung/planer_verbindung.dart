import 'dart:typed_data';

import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Verbindung der Web-App zum Planer-Router (anonym, Rolle Kunde).
class PlanerVerbindung {
  PlanerVerbindung(this.adresse);

  final Uri adresse;

  /// Ruft die Hallo-Prozedur auf und liefert die Antwort des Servers.
  Future<String> hallo() => _mitSitzung((sitzung) async {
    final antwort = await sitzung.callSingle(WampNamen.hallo);
    return antwort.arguments!.single as String;
  });

  /// GLB einer Rechteck-Terrasse vom 3D-Dienst (M3-10, Prototyp).
  Future<Uint8List> modell3dRechteck(Millimeter laenge, Millimeter breite) =>
      _mitSitzung((sitzung) async {
        final antwort = await sitzung.callSingle(
          WampNamen.modell3dRechteck,
          arguments: [laenge.mm, breite.mm],
        );
        return antwort.arguments!.single as Uint8List;
      });

  /// Lässt den Server Umriss und Kennzahlen der [planung] berechnen (M4-02,
  /// mehrere Flächen M4-14); beide Richtungen als typisierte FlatBuffers
  /// (Packed PPT, #110).
  Future<Berechnung> berechne(Planung planung) => _mitSitzung((sitzung) async {
    final antwort = await sitzung.callSingleLazyPayloadView(
      WampNamen.planungBerechnen,
      payload: verpacke(planung.zuBytes()),
      options: CallOptions(
        pptScheme: WampNamen.pptSchema,
        pptSerializer: WampNamen.pptSerializer,
      ),
    );
    return Berechnung.ausBytes(antwort.payload.packedPayloadBytes!);
  });

  /// FlatBuffer als Packed-PPT-Nutzlast; materialisiert ist es ein
  /// Binärargument.
  static LazyMessagePayload verpacke(Uint8List bytes) =>
      LazyMessagePayload.packed(
        encoding: LazyPayloadEncoding.flatbuffers,
        packedPayloadBytes: bytes,
        packedPayloadDecoder: (b) => (arguments: [b], argumentsKeywords: null),
      );

  Future<T> _mitSitzung<T>(Future<T> Function(Session sitzung) aufgabe) async {
    // FlatBuffers (wamp.2.flatbuffers, #110): schnellster Weg für kleine
    // Nachrichten; typisierte Nutzlasten folgen mit dem gemeinsamen Schema.
    final transport = WebSocketTransport.withFlatBuffersSerializer('$adresse');
    final client = Client(realm: WampNamen.realm, transport: transport);
    final sitzung = await client
        .connect(options: ClientConnectOptions(reconnectCount: 0))
        .first
        .timeout(const Duration(seconds: 15));
    try {
      return await aufgabe(sitzung);
    } finally {
      await sitzung.close();
    }
  }
}
