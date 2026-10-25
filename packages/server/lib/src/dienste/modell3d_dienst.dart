import 'dart:typed_data';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../modell3d/glb.dart';
import '../router/planer_router.dart';

/// 3D-Dienst (M3-10, Prototyp): erzeugt auf dem Server das GLB einer
/// Rechteck-Terrasse; die App zeigt es nur an (Frontend bleibt „doof“).
class Modell3dDienst {
  Modell3dDienst._(this._sitzung);

  static Future<Modell3dDienst> starte(PlanerRouter router) async {
    final sitzung = await router.dienstSitzung(sitzungId);
    (await sitzung.register(WampNamen.modell3dRechteck)).onInvoke(_rechteck);
    return Modell3dDienst._(sitzung);
  }

  /// authid der internen Dienst-Sitzung.
  static const sitzungId = 'modell3d-dienst';

  /// Kleinste und größte Seitenlänge im Prototyp.
  static const kleinsteSeite = Millimeter(500);
  static const groessteSeite = Millimeter(20000);

  /// GLB einer Rechteck-Terrasse (Maße in mm) mit Beispielaufbau: Diele
  /// 120 x 23 mm, UK 70 x 45 mm im empfohlenen Achsabstand der Robinie.
  static Uint8List rechteck(Millimeter laenge, Millimeter breite) => glbAus(
    rechteckTerrasse(
      laenge: laenge,
      breite: breite,
      dielenbreite: const Millimeter(120),
      dielenstaerke: const Millimeter(23),
      ukBreite: const Millimeter(70),
      ukHoehe: const Millimeter(45),
      ukAchsabstand: robinie.ukAchsabstandEmpfohlen,
    ),
  );

  static void _rechteck(Invocation aufruf) {
    final argumente = aufruf.arguments ?? const <Object?>[];
    if (argumente case [final int laenge, final int breite]
        when _gueltig(laenge) && _gueltig(breite)) {
      aufruf.respondWith(
        arguments: [rechteck(Millimeter(laenge), Millimeter(breite))],
      );
      return;
    }
    aufruf.respondWith(
      isError: true,
      errorUri: WampNamen.masseUngueltig,
      arguments: argumente,
    );
  }

  static bool _gueltig(int mm) =>
      mm >= kleinsteSeite.mm && mm <= groessteSeite.mm;

  final RouterSession _sitzung;

  Future<void> stoppe() => _sitzung.close();
}
