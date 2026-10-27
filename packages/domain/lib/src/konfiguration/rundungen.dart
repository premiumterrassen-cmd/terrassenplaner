import 'dart:math' as math;

import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import 'grundriss.dart';

/// Rundungen im Grundriss (Fachkonzept 1.3, M4-11): Radius je Ecke und Stich
/// (Pfeilhöhe) je Seite – positiv nach außen, negativ nach innen gewölbt.
/// Ecken und Seiten zählen wie [Grundriss.ecken] (Seite `i` von Ecke `i`
/// zur nächsten).
final class Rundungen {
  const Rundungen({this.ecken = const {}, this.seiten = const {}});

  /// Liest das Transportformat ([masse]).
  factory Rundungen.aus(List<int> werte) {
    if (werte.length % 3 != 0) {
      throw FormatException(
        'Rundungen brauchen Dreiergruppen: ${werte.length}',
      );
    }
    final ecken = <int, Millimeter>{}, seiten = <int, Millimeter>{};
    for (var i = 0; i < werte.length ~/ 3; i++) {
      final ziel = werte[3 * i] == 0 ? ecken : seiten;
      ziel[werte[3 * i + 1]] = Millimeter(werte[3 * i + 2]);
    }
    return Rundungen(ecken: ecken, seiten: seiten);
  }

  static const keine = Rundungen();

  /// Radius je Ecke.
  final Map<int, Millimeter> ecken;

  /// Stich je Seite.
  final Map<int, Millimeter> seiten;

  bool get leer => ecken.isEmpty && seiten.isEmpty;

  /// Transportformat: je Rundung Art (0 Ecke, 1 Seite), Nummer, Wert in mm.
  List<int> get masse => [
    for (final MapEntry(:key, :value) in ecken.entries) ...[0, key, value.mm],
    for (final MapEntry(:key, :value) in seiten.entries) ...[1, key, value.mm],
  ];

  /// Mit Radius [radius] an Ecke [ecke]; 0 entfernt die Rundung.
  Rundungen mitEcke(int ecke, Millimeter radius) =>
      Rundungen(ecken: _gesetzt(ecken, ecke, radius), seiten: seiten);

  /// Mit Stich [stich] an Seite [seite]; 0 entfernt die Rundung.
  Rundungen mitSeite(int seite, Millimeter stich) =>
      Rundungen(ecken: ecken, seiten: _gesetzt(seiten, seite, stich));

  static Map<int, Millimeter> _gesetzt(
    Map<int, Millimeter> alt,
    int nummer,
    Millimeter wert,
  ) => {...alt, nummer: wert}..removeWhere((_, w) => w.mm == 0);

  /// Kontur des [grundriss] mit diesen Rundungen. Wirft [ArgumentError], wenn
  /// eine Rundung unzulässig ist: Radien, die zusammen länger sind als die
  /// Kante, ein Stich über dem Halbkreis oder sich überschneidende Bögen.
  Kontur kontur(Grundriss grundriss) {
    final e = grundriss.ecken;
    if (leer || e.isEmpty) return grundriss.kontur;
    final n = e.length;
    final tangente = List<double>.filled(n, 0);
    final drehung = List<double>.filled(n, 0);
    int vorher(int i) => i == 0 ? n - 1 : i - 1;
    for (final MapEntry(key: i, value: r) in ecken.entries) {
      final a = (e[i] - e[vorher(i)]).einheit;
      final b = (e[(i + 1) % n] - e[i]).einheit;
      drehung[i] = math.atan2(a.kreuz(b), a.punktprodukt(b));
      tangente[i] = r.mm * math.tan(drehung[i].abs() / 2);
    }
    final aussen = Kontur(e).gegenUhrzeigersinn;
    final punkte = <Punkt>[], woelbungen = <double>[];
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final seite = e[j] - e[i];
      final rest = seite.laenge - tangente[i] - tangente[j];
      if (rest < 1) {
        throw ArgumentError.value(
          ecken[i]?.mm ?? ecken[j]!.mm,
          'ecke',
          'Rundung zu groß für die Kante ${_name(i)}—${_name(j)}',
        );
      }
      final richtung = seite.einheit;
      final anfang = e[i] + richtung * tangente[i];
      if (tangente[i] > 0) {
        // Bogen der Ecke i vom Ende der vorigen Kante bis hierher
        punkte.add(e[i] - (e[i] - e[vorher(i)]).einheit * tangente[i]);
        woelbungen.add(math.tan(drehung[i] / 4));
      }
      punkte.add(anfang);
      woelbungen.add(_woelbung(i, rest, aussen));
    }
    final kontur = Kontur(punkte, woelbungen: woelbungen);
    if (!kontur.istEinfach) {
      throw ArgumentError.value(
        masse.length ~/ 3,
        'rundungen',
        'Rundungen überschneiden sich',
      );
    }
    return kontur;
  }

  /// Wölbung der Seite [i] mit Sehne [sehne]: tan(θ/4) = 2·Stich / Sehne.
  /// [aussen]: Umlauf gegen den Uhrzeigersinn – dort wölbt eine positive
  /// Wölbung nach außen.
  double _woelbung(int i, double sehne, bool aussen) {
    final stich = seiten[i]?.mm ?? 0;
    if (stich.abs() * 2 >= sehne) {
      throw ArgumentError.value(
        stich,
        'seite',
        'Stich höchstens bis zum Halbkreis der Seite ${_name(i)}',
      );
    }
    final w = 2 * stich / sehne;
    return aussen ? w : -w;
  }

  static String _name(int i) => String.fromCharCode(65 + i);

  @override
  bool operator ==(Object other) =>
      other is Rundungen &&
      _gleich(other.ecken, ecken) &&
      _gleich(other.seiten, seiten);

  static bool _gleich(Map<int, Millimeter> a, Map<int, Millimeter> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(masse);
}
