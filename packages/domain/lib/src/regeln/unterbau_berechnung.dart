/// Unterkonstruktion der bearbeiteten Fläche für die App (M6-08 bis M6-11,
/// `Unterbau`): fasst die Regeln der UK zusammen, die der Server rechnet.
library;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../konfiguration/planungsstand.dart';
import '../konfiguration/terrassenart.dart';
import '../konfiguration/unterbau.dart';
import 'auflager.dart';
import 'feldbreite.dart';
import 'hoehenpunkte.dart';
import 'regelwerk.dart';

/// Unterbau für [stand] mit dem [belag], der UK [uk] und den geprüften
/// [hoehen]:
///
/// - **Feldbreite** (M6-09): die wählbaren bis zur höchsten erlaubten des
///   Belags (R-C01, `hoechsteFeldbreite`) und die wirksame; ohne Belag aus
///   Holz keine.
/// - **Auflager** (M6-08): Abstand aus dem Regelwerk (bzw. der
///   Spannweite), bei der normalen Terrasse die Höhenbereiche der
///   Stelzfüße und Pads samt Höhengrenzen und Meldungen. Hochterrasse und
///   vorhandene UK stehen auf Stützen bzw. der vorhandenen UK (M6-11). Ohne
///   UK keine; kennt das Regelwerk die UK nicht, nur der Abstand.
Unterbau unterbauFuer(
  Planungsstand stand, {
  required Hoehenpunkte hoehen,
  Regelwerk? regelwerk,
  Artikel? belag,
  Artikel? uk,
}) {
  final hoechste = belagFeldbreite(belag, regelwerk);
  final gewaehlt = stand.feldbreite;
  final auswahl = hoechste == null
      ? const <Millimeter>[]
      : feldbreiten(hoechste);
  final wirksam = hoechste == null
      ? null
      : wirksameFeldbreite(gewaehlt, hoechste);
  final begrenzt = hoechste != null && gewaehlt != null && gewaehlt > hoechste;
  if (uk == null) {
    return Unterbau(
      feldbreiten: auswahl,
      feldbreite: wirksam,
      feldbreiteBegrenzt: begrenzt,
    );
  }
  final daten = regelwerk?.datei[uk.nummer] == null ? null : regelwerk;
  final bereiche = daten == null || stand.terrassenart != Terrassenart.normal
      ? const <Auflagerbereich>[]
      : auflagerbereiche(
          daten,
          uk,
          gewerblich: stand.gewerblich,
          auflagen: stand.auflagen,
        );
  final aufbau = hoehen.aufbauhoehe;
  final grenzen = aufbau == null ? null : auflagergrenzen(bereiche, aufbau);
  return Unterbau(
    auflagerabstand: auflagerabstand(
      stand,
      daten?.abstaende(uk.nummer).stelzfuesse,
    ),
    auflager: [for (final b in bereiche) b.angabe],
    hoeheVon: grenzen?.von,
    hoeheBis: grenzen?.bis,
    meldungen: aufbau == null
        ? const []
        : auflagermeldungen(hoehen.hoehen, aufbau, bereiche),
    feldbreiten: auswahl,
    feldbreite: wirksam,
    feldbreiteBegrenzt: begrenzt,
  );
}

/// Höchste Feldbreite für den [belag] (M6-09): sein UK-Abstand laut
/// [regelwerk] (wenn es ihn kennt), höchstens der der Holzart (R-C01);
/// `null` ohne Belag aus Holz.
Millimeter? belagFeldbreite(Artikel? belag, Regelwerk? regelwerk) {
  final holzart = belag?.holzart;
  if (holzart == null) return null;
  final nummer = belag!.nummer;
  return hoechsteFeldbreite(
    holzart,
    regelwerk?.datei[nummer] == null ? null : regelwerk!.abstaende(nummer).uk,
  );
}
