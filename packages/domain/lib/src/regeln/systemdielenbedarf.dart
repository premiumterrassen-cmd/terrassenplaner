/// Menge der MASSIV-Systemdielen (Planungsregeln Alexander, Planungskern
/// Regeln 1a.2 und 1a.6, B-036, B-232): Verkauf je m² in Paketen à 1,5 m²,
/// Menge = belegte Fläche plus Verschnitt nach Form, keine Freidiele.
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../ergebnisse/materialliste.dart';
import '../geometrie/kontur.dart';
import '../konfiguration/belagverlegung.dart';
import '../konfiguration/planungsstand.dart';

/// Inhalt eines Pakets MASSIV-Systemdielen in m² (B-036).
const systemdielenPaket = 1.5;

/// Verschnitt bei einer rechteckigen Fläche (Regel 1a.6).
const systemdielenZuschlagRechteck = 0.05;

/// Verschnitt mit Schrägen, Bögen, Aussparungen oder mehreren Flächen
/// (Regel 1a.6).
const systemdielenZuschlagForm = 0.10;

/// Belegte Fläche der [verlegung] in m²: die Stücke aller Teilflächen samt
/// ihrem Anteil an der Fuge – ohne Aussparungen und Rinnen.
double belegteFlaeche(Belagverlegung verlegung) => [
  for (final t in verlegung.teile)
    for (final s in t.stuecke) Kontur(s.umriss).flaeche / 1e6,
].fold(0.0, (a, b) => a + b);

/// Ob die Fläche [stand] für den Verschnitt als Rechteck zählt (Regel
/// 1a.6): vier Ecken ohne Bogen, rechte Winkel, Kanten längs oder quer zu
/// den Dielen und keine Ausschnitte.
bool systemdielenRechteck(Planungsstand stand) {
  final kontur = stand.kontur;
  if (kontur.punkte.length != 4 ||
      kontur.woelbungen.any((w) => w != 0) ||
      stand.ausschnitte.isNotEmpty) {
    return false;
  }
  final winkel = stand.dielenwinkel * math.pi / 180;
  final (c, s) = (math.cos(winkel), math.sin(winkel));
  for (final k in kontur.kanten) {
    final d = k.ende - k.start;
    final laengs = (d.x * s - d.y * c).abs();
    final quer = (d.x * c + d.y * s).abs();
    if (math.min(laengs, quer) > _schiefToleranz * math.max(laengs, quer)) {
      return false;
    }
  }
  return true;
}

/// So schief (Anteil) darf eine Kante sein und noch als gerade zählen.
const _schiefToleranz = 1e-3;

/// Verkaufseinheiten MASSIV für [flaeche] m² belegte Fläche (Regel 1a.6):
/// mit Verschnitt (Rechteck 5 %, sonst 10 %) auf ganze Pakete à
/// [systemdielenPaket] aufgerundet, dann in die Verkaufseinheit des
/// [artikel] umgerechnet – je Paket, je m² oder je lfm (Breite). 0 ohne
/// Fläche.
int systemdielenEinheiten(
  Artikel artikel,
  double flaeche, {
  required bool rechteck,
}) {
  final zuschlag = rechteck
      ? systemdielenZuschlagRechteck
      : systemdielenZuschlagForm;
  final pakete = (flaeche * (1 + zuschlag) / systemdielenPaket - 1e-9).ceil();
  return (pakete * systemdielenPaket / systemdielenQmJeEinheit(artikel) - 1e-9)
      .ceil();
}

/// m² je Verkaufseinheit des [artikel]: Paket bzw. m² mit ihrem Inhalt in
/// m², lfm mit der Breite, sonst ein Paket.
double systemdielenQmJeEinheit(Artikel artikel) {
  final e = artikel.einheit;
  return switch ((e.einheit, e.inhaltEinheit, artikel.abmessungen.breite)) {
    (Mengeneinheit.quadratmeter, _, _) ||
    (_, Mengeneinheit.quadratmeter, _) => e.inhalt.toDouble(),
    (Mengeneinheit.laufmeter, _, final b?) => e.inhalt * b.m,
    _ => systemdielenPaket,
  };
}

/// Seitenblende aus MASSIV glattkant (Regel 1a.7): [flaeche] m² Blende
/// plus 5 % in ganzen Paketen, mit Zusatz „Verblendung“.
Materialbedarf systemdielenBlende(Artikel blende, double flaeche) =>
    Materialbedarf(
      [blende],
      systemdielenEinheiten(blende, flaeche, rechteck: true),
      zusatz: Materialzusatz.verblendung,
      inEinheiten: true,
    );
