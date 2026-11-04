import 'dart:typed_data';

import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_client/connectanum.dart' as wamp show Error;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../konfiguration/konfigurations_steuerung.dart';

/// Verbindung der Web-App zum Planer-Router (anonym, Rolle Kunde).
class PlanerVerbindung implements KonfigurationsAblage {
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

  /// Beläge mit Preisen vom Artikeldienst (M5-01).
  Future<Belagauswahl> belaege() => _mitSitzung((sitzung) async {
    final antwort = await sitzung.callSingle(WampNamen.belagAuswahl);
    return Belagauswahl.ausJson(alsJsonObjekt(antwort.arguments!.single), {
      robinie.id: robinie,
    });
  });

  /// SPEICHERN über den Konfigurationsdienst (M9-05); die Planung reist im
  /// Transportformat als Binärargument.
  @override
  Future<KonfigurationsStand> speichere(
    Planung planung, {
    Konfigurationskennung? kennung,
  }) => _mitSitzung((sitzung) async {
    final antwort = await sitzung.callSingle(
      WampNamen.konfigurationSpeichern,
      arguments: [planung.zuBytes(), ?kennung?.wert],
    );
    final [neu as String, version as int] = antwort.arguments!;
    return KonfigurationsStand(Konfigurationskennung.lies(neu), version);
  });

  /// LADEN einer Version mit Nummer und Prüfcode (M9-05, M9-05b);
  /// unbekannt oder Prüfcode falsch: [KonfigurationNichtGefunden].
  @override
  Future<Planung> lade(KonfigurationsStand stand) =>
      _mitSitzung((sitzung) async {
        try {
          final antwort = await sitzung.callSingle(
            WampNamen.konfigurationLaden,
            arguments: [stand.kennung.wert, stand.version],
          );
          return Planung.ausBytes(antwort.arguments!.single! as Uint8List);
        } on wamp.Error catch (fehler) {
          if (fehler.error == WampNamen.konfigurationUnbekannt) {
            throw KonfigurationNichtGefunden(stand);
          }
          rethrow;
        }
      });

  /// Entwurf der Sitzung [schluessel] merken (automatisches
  /// Zwischenspeichern, M9-05).
  @override
  Future<void> merkeEntwurf(
    String schluessel,
    Planung planung, {
    KonfigurationsStand? bezug,
  }) => _mitSitzung(
    (sitzung) => sitzung.callSingle(
      WampNamen.entwurfSpeichern,
      arguments: [
        schluessel,
        planung.zuBytes(),
        if (bezug != null) ...[bezug.kennung.wert, bezug.version],
      ],
    ),
  );

  /// Entwurf der Sitzung [schluessel]; `null`, wenn der Server keinen hat.
  @override
  Future<PlanungsEntwurf?> entwurf(String schluessel) =>
      _mitSitzung((sitzung) async {
        final List<Object?> argumente;
        try {
          argumente = (await sitzung.callSingle(
            WampNamen.entwurfLaden,
            arguments: [schluessel],
          )).arguments!;
        } on wamp.Error catch (fehler) {
          if (fehler.error == WampNamen.entwurfUnbekannt) return null;
          rethrow;
        }
        return (
          planung: Planung.ausBytes(argumente.first! as Uint8List),
          bezug: switch (argumente) {
            [_, final String kennung, final int version] => KonfigurationsStand(
              Konfigurationskennung.lies(kennung),
              version,
            ),
            _ => null,
          },
        );
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
