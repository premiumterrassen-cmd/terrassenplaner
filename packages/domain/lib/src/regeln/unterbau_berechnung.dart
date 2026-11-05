/// Unterkonstruktion der bearbeiteten Fläche für die App (M6-08 bis M6-11,
/// `Unterbau`): fasst die Regeln der UK zusammen, die der Server rechnet.
library;

import '../artikel/artikel.dart';
import '../konfiguration/planungsstand.dart';
import '../konfiguration/terrassenart.dart';
import '../konfiguration/unterbau.dart';
import 'auflager.dart';
import 'hoehenpunkte.dart';
import 'regelwerk.dart';

/// Unterbau für [stand] mit der UK [uk] und den geprüften [hoehen]
/// (M6-08): Abstand der Auflager aus dem Regelwerk (bzw. der Spannweite),
/// bei der normalen Terrasse die Höhenbereiche der Stelzfüße und Pads
/// samt Höhengrenzen und Meldungen. Hochterrasse und vorhandene UK stehen
/// auf Stützen bzw. der vorhandenen UK (M6-11). Ohne UK nichts; kennt das
/// Regelwerk die UK nicht, nur der Abstand ohne Artikelangabe.
Unterbau unterbauFuer(
  Planungsstand stand, {
  required Hoehenpunkte hoehen,
  Regelwerk? regelwerk,
  Artikel? uk,
}) {
  if (uk == null) return Unterbau.leer;
  final daten = regelwerk?.datei[uk.nummer] == null ? null : regelwerk;
  final abstand = auflagerabstand(
    stand,
    daten?.abstaende(uk.nummer).stelzfuesse,
  );
  if (daten == null || stand.terrassenart != Terrassenart.normal) {
    return Unterbau(auflagerabstand: abstand);
  }
  final bereiche = auflagerbereiche(
    daten,
    uk,
    gewerblich: stand.gewerblich,
    auflagen: stand.auflagen,
  );
  final aufbau = hoehen.aufbauhoehe;
  final grenzen = aufbau == null ? null : auflagergrenzen(bereiche, aufbau);
  return Unterbau(
    auflagerabstand: abstand,
    auflager: [for (final b in bereiche) b.angabe],
    hoeheVon: grenzen?.von,
    hoeheBis: grenzen?.bis,
    meldungen: aufbau == null
        ? const []
        : auflagermeldungen(hoehen.hoehen, aufbau, bereiche),
  );
}
