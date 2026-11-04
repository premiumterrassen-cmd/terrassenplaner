import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Berechnung der Dielenverlegung (M5-08): große Freiform (12 × 8 m mit
/// schräger Ecke und Einbuchtung) mit drei Ausschnitten – zwei leer, einer
/// mit anderem Belag –, verlegt, nummeriert und zugeschnitten, waagrecht und
/// unter 45° im Halbverband mit 6-cm-Dielen in 4/5/6 m.
class BelagverlegungBenchmark extends BenchmarkBase {
  BelagverlegungBenchmark() : super('domain.Belagverlegung.verlegeBelag');

  static Ausschnitt _ausschnitt(
    String name,
    int x,
    int y,
    int l,
    int b, {
    Ausschnittform form = Ausschnittform.rechteck,
    Ausschnittfunktion funktion = Ausschnittfunktion.leer,
  }) => Ausschnitt(
    bezeichnung: name,
    x: Millimeter(x),
    y: Millimeter(y),
    laenge: Millimeter(l),
    breite: Millimeter(b),
    form: form,
    funktion: funktion,
  );

  static final _stand = () {
    var stand = Planungsstand(
      grundriss: FreiformGrundriss(const [
        Punkt(0, 0),
        Punkt(9000, 0),
        Punkt(12000, 2500),
        Punkt(12000, 8000),
        Punkt(7000, 8000),
        Punkt(7000, 6000),
        Punkt(4000, 6000),
        Punkt(4000, 8000),
        Punkt(0, 8000),
      ], geschlossen: true),
    ).mitVerlegeart(Verlegeart.halbverband);
    for (final a in [
      _ausschnitt('A1', 1500, 1500, 2000, 1200),
      _ausschnitt('A2', 6000, 2000, 1500, 1500, form: Ausschnittform.kreis),
      _ausschnitt(
        'A3',
        9000,
        5000,
        1800,
        1200,
        funktion: Ausschnittfunktion.andererBelag,
      ),
    ]) {
      stand = stand.mitNeuemAusschnitt().mitAusschnitt(
        stand.ausschnitte.length,
        a,
      );
    }
    return stand;
  }();

  static final _belag = Artikel(
    nummer: const Artikelnummer('10-10-001'),
    titel: 'Terrassendiele',
    art: Artikelart.diele,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    abmessungen: Abmessungen(
      breite: const Millimeter(60),
      laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
    ),
    holzart: robinie,
    serie: basic,
  );

  var _summe = 0;

  @override
  void run() {
    for (final richtung in const [
      Verlegerichtung.waagrecht,
      Verlegerichtung.diagonal45,
    ]) {
      final v = verlegeBelag(_stand.mitVerlegerichtung(richtung), _belag)!;
      _summe += v.dielenliste.anzahl.length + v.teile.length;
    }
  }

  @override
  void teardown() {
    if (_summe == 0) throw StateError('Benchmark hat nichts berechnet');
  }
}

void main() => BelagverlegungBenchmark().report();
