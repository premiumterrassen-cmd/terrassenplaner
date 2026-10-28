import 'dart:typed_data';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../router/planer_router.dart';

/// Planungsdienst (M4-02): berechnet aus der Planung der App Umriss und
/// Kennzahlen der bearbeiteten Fläche und die Gesamtfläche (M4-14) – die App rechnet nichts selbst (Frontend bleibt „doof“).
/// Hin- und Rückweg als typisierte FlatBuffers (Packed PPT, #110).
class PlanungsDienst {
  PlanungsDienst._(this._sitzung);

  static Future<PlanungsDienst> starte(PlanerRouter router) async {
    final sitzung = await router.dienstSitzung(sitzungId);
    (await sitzung.register(WampNamen.planungBerechnen))
        .onLazyInvokePayload(_berechne);
    return PlanungsDienst._(sitzung);
  }

  /// authid der internen Dienst-Sitzung.
  static const sitzungId = 'planungs-dienst';

  /// Kennung typisierter Nutzlasten des Planers.
  static final ppt = YieldOptions(
    pptScheme: WampNamen.pptSchema,
    pptSerializer: WampNamen.pptSerializer,
  );

  /// Umriss, Ausschnitte und Fläche des Grundrisses; wie im alten Planer
  /// ist die Fläche die Außenfläche (Fachkonzept 1.4).
  static Berechnung berechne(Planungsstand stand) {
    // offene Freiform (M4-08): nur der gezeichnete Linienzug
    if (stand.grundriss case FreiformGrundriss(
      :final punkte,
      geschlossen: false,
    )) {
      return Berechnung(umriss: punkte, flaeche: 0, geschlossen: false);
    }
    final kontur = stand.kontur;
    return Berechnung(
      // Bögen (Kreis) als Sehnenzug für die Zeichnung, Ecken für die Namen
      umriss: kontur.vieleck(),
      ecken: stand.grundriss.ecken,
      flaeche: kontur.flaeche,
      ausschnitte: [for (final a in stand.ausschnitte) a.kontur.punkte],
    );
  }

  /// Berechnung der bearbeiteten Fläche mit der Gesamtfläche aller Flächen,
  /// jede mal ihrer Häufigkeit (M4-14).
  static Berechnung berechnePlanung(Planung planung) {
    var gesamt = 0.0;
    for (final f in planung.flaechen) {
      gesamt += berechne(f.stand).flaeche * f.haeufigkeit;
    }
    final b = berechne(planung.aktuell);
    return Berechnung(
      umriss: b.umriss,
      ecken: b.ecken,
      geschlossen: b.geschlossen,
      flaeche: b.flaeche,
      ausschnitte: b.ausschnitte,
      gesamtflaeche: gesamt,
    );
  }

  static void _berechne(LazyInvocationPayload aufruf) {
    try {
      final planung = Planung.ausBytes(_bytes(aufruf));
      aufruf.respondWith(
        lazyPayload: verpacke(berechnePlanung(planung).zuBytes()),
        options: ppt,
      );
    } on Object catch (fehler) {
      aufruf.respondWith(
        isError: true,
        errorUri: WampNamen.planungUngueltig,
        arguments: ['$fehler'],
      );
    }
  }

  static Uint8List _bytes(LazyInvocationPayload aufruf) {
    if (aufruf.pptScheme != WampNamen.pptSchema) {
      throw const FormatException('keine typisierte Planung');
    }
    return aufruf.payload.packedPayloadBytes!;
  }

  /// FlatBuffer als Packed-PPT-Nutzlast.
  static LazyMessagePayload verpacke(Uint8List bytes) =>
      LazyMessagePayload.packed(
        encoding: LazyPayloadEncoding.flatbuffers,
        packedPayloadBytes: bytes,
        packedPayloadDecoder: (b) => (arguments: [b], argumentsKeywords: null),
      );

  final RouterSession _sitzung;

  Future<void> stoppe() => _sitzung.close();
}
