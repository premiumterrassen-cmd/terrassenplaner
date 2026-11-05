import 'dart:async';

import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_client/connectanum.dart' as wamp show Error;
import 'package:flutter/foundation.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../anmeldung/mitarbeiter_anmeldung.dart';
import '../konfiguration/konfigurations_steuerung.dart';

/// Verbindung der Web-App zum Planer-Router: anonym (Rolle Kunde) mit einer
/// kurzen Sitzung je Aufruf; nach ANMELDEN (M9-10) über die eine Sitzung
/// des Mitarbeiters (Rolle `mitarbeiter`, SCRAM über den Auth-Server).
class PlanerVerbindung implements KonfigurationsAblage, MitarbeiterAnmeldung {
  PlanerVerbindung(this.adresse);

  final Uri adresse;

  final _angemeldetAls = ValueNotifier<String?>(null);

  /// Sitzung des angemeldeten Mitarbeiters; der Browser hält nur sie, nie
  /// das Passwort.
  Session? _mitarbeiter;

  @override
  ValueListenable<String?> get angemeldetAls => _angemeldetAls;

  /// SCRAM-Anmeldung (`wamp-scram`, Argon2id im Web Worker von
  /// connectanum). Das Passwort wird nach dem Handschlag verworfen; reißt
  /// die Verbindung ab, ist der Mitarbeiter abgemeldet.
  @override
  Future<void> anmelden(String email, String passwort) async {
    await abmelden();
    final authId = anmeldename(email);
    final scram = ScramAuthentication(passwort);
    final Session sitzung;
    try {
      sitzung = await _verbinde(authId: authId, anmeldung: scram);
    } on Abort catch (abbruch) {
      if (abbruch.reason == wamp.Error.couldNotConnect) rethrow;
      throw const AnmeldungAbgelehnt();
    } finally {
      await scram.dispose();
    }
    _mitarbeiter = sitzung;
    _angemeldetAls.value = authId;
    unawaited(
      sitzung.onDisconnect.then((_) {
        if (identical(_mitarbeiter, sitzung)) _vergiss();
      }),
    );
  }

  @override
  Future<void> abmelden() async {
    final sitzung = _mitarbeiter;
    _vergiss();
    await sitzung?.close();
  }

  void _vergiss() {
    _mitarbeiter = null;
    _angemeldetAls.value = null;
  }

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

  /// Zubehör der acht Gruppen vom Artikeldienst (M8-01).
  Future<Zubehoerauswahl> zubehoer() => _mitSitzung((sitzung) async {
    final antwort = await sitzung.callSingle(WampNamen.zubehoerAuswahl);
    return Zubehoerauswahl.ausJson(alsJsonObjekt(antwort.arguments!.single), {
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
  Future<Planung> lade(KonfigurationsStand stand) async =>
      (await _lade(stand.kennung.wert, stand.version)).planung;

  /// LADEN mit der Nummer allein – der Server erlaubt es nur der Sitzung
  /// eines angemeldeten Mitarbeiters (M9-10) und liefert die vollständige
  /// Kennung mit.
  @override
  Future<GeladeneKonfiguration> ladeOhnePruefcode(
    Konfigurationsnummer nummer,
    int version,
  ) => _lade(nummer.wert, version);

  Future<GeladeneKonfiguration> _lade(String eingabe, int version) =>
      _mitSitzung((sitzung) async {
        try {
          final antwort = await sitzung.callSingle(
            WampNamen.konfigurationLaden,
            arguments: [eingabe, version],
          );
          final [inhalt as Uint8List, kennung as String] = antwort.arguments!;
          return (
            planung: Planung.ausBytes(inhalt),
            stand: KonfigurationsStand(
              Konfigurationskennung.lies(kennung),
              version,
            ),
          );
        } on wamp.Error catch (fehler) {
          if (fehler.error == WampNamen.konfigurationUnbekannt) {
            throw KonfigurationNichtGefunden(eingabe, version);
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

  /// Importdatei für GrandTotal zur [planung] vom Exportdienst (M9-08);
  /// [adresse] ist die Adresse der Web-App für die Bild-Links. Nur für
  /// angemeldete Mitarbeiter – sonst lehnt der Router den Aufruf ab.
  Future<String> exportGrandTotal(Planung planung, Uri adresse) =>
      _mitSitzung((sitzung) async {
        final antwort = await sitzung.callSingle(
          WampNamen.exportGrandTotal,
          arguments: [planung.zuBytes(), '$adresse'],
        );
        return antwort.arguments!.single! as String;
      });

  /// Zum Belag passende Unterkonstruktionen vom Artikeldienst (M6-03);
  /// ohne [belag] die zum Vorgabe-Belag.
  Future<Ukauswahl> unterkonstruktionen(Artikelnummer? belag) =>
      _mitSitzung((sitzung) async {
        final antwort = await sitzung.callSingle(
          WampNamen.ukAuswahl,
          arguments: [?belag?.wert],
        );
        return Ukauswahl.ausJson(alsJsonObjekt(antwort.arguments!.single), {
          robinie.id: robinie,
        });
      });

  /// FlatBuffer als Packed-PPT-Nutzlast; materialisiert ist es ein
  /// Binärargument.
  static LazyMessagePayload verpacke(Uint8List bytes) =>
      LazyMessagePayload.packed(
        encoding: LazyPayloadEncoding.flatbuffers,
        packedPayloadBytes: bytes,
        packedPayloadDecoder: (b) => (arguments: [b], argumentsKeywords: null),
      );

  /// Angemeldet: über die Sitzung des Mitarbeiters; sonst eine kurze
  /// anonyme Sitzung nur für diesen Aufruf.
  Future<T> _mitSitzung<T>(Future<T> Function(Session sitzung) aufgabe) async {
    if (_mitarbeiter case final mitarbeiter?) return aufgabe(mitarbeiter);
    final sitzung = await _verbinde();
    try {
      return await aufgabe(sitzung);
    } finally {
      await sitzung.close();
    }
  }

  Future<Session> _verbinde({
    String? authId,
    AbstractAuthentication? anmeldung,
  }) {
    // FlatBuffers (wamp.2.flatbuffers, #110): schnellster Weg für kleine
    // Nachrichten; typisierte Nutzlasten folgen mit dem gemeinsamen Schema.
    final transport = WebSocketTransport.withFlatBuffersSerializer('$adresse');
    final client = Client(
      realm: WampNamen.realm,
      transport: transport,
      authId: authId,
      authenticationMethods: anmeldung == null ? null : [anmeldung],
    );
    return client
        .connect(options: ClientConnectOptions(reconnectCount: 0))
        .first
        .timeout(const Duration(seconds: 15));
  }
}
