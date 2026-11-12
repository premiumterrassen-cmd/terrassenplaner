import 'dart:math' as math;

import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import 'grundriss.dart';

/// Rundungen im Grundriss (Fachkonzept 1.3, M4-11): Radius je Ecke und je
/// Seite entweder ein Stich (Pfeilhöhe, wie im alten Planer) oder ein
/// Radius (Planungsregeln Alexander (Planungskern v12, 12.11.2026), Regel
/// 14.1.2) – positiv nach außen, negativ nach innen gewölbt. Ecken und
/// Seiten zählen wie [Grundriss.ecken] (Seite `i` von Ecke `i` zur
/// nächsten).
final class Rundungen {
  const Rundungen({
    this.ecken = const {},
    this.seiten = const {},
    this.radien = const {},
  });

  /// Liest das Transportformat ([masse]).
  factory Rundungen.aus(List<int> werte) {
    if (werte.length % 3 != 0) {
      throw FormatException(
        'Rundungen brauchen Dreiergruppen: ${werte.length}',
      );
    }
    final arten = [
      <int, Millimeter>{},
      <int, Millimeter>{},
      <int, Millimeter>{},
    ];
    for (var i = 0; i < werte.length ~/ 3; i++) {
      final art = werte[3 * i];
      if (art < 0 || art > 2) {
        throw FormatException('unbekannte Rundungsart $art');
      }
      arten[art][werte[3 * i + 1]] = Millimeter(werte[3 * i + 2]);
    }
    return Rundungen(ecken: arten[0], seiten: arten[1], radien: arten[2]);
  }

  static const keine = Rundungen();

  /// Radius je Ecke.
  final Map<int, Millimeter> ecken;

  /// Stich je Seite.
  final Map<int, Millimeter> seiten;

  /// Radius je Seite (Regel 14.1.2), negativ = nach innen gewölbt.
  final Map<int, Millimeter> radien;

  bool get leer => ecken.isEmpty && seiten.isEmpty && radien.isEmpty;

  /// Transportformat: je Rundung Art (0 Ecke, 1 Stich einer Seite,
  /// 2 Radius einer Seite), Nummer, Wert in mm.
  List<int> get masse => [
    for (final MapEntry(:key, :value) in ecken.entries) ...[0, key, value.mm],
    for (final MapEntry(:key, :value) in seiten.entries) ...[1, key, value.mm],
    for (final MapEntry(:key, :value) in radien.entries) ...[2, key, value.mm],
  ];

  /// Mit Radius [radius] an Ecke [ecke]; 0 entfernt die Rundung.
  Rundungen mitEcke(int ecke, Millimeter radius) => Rundungen(
    ecken: _gesetzt(ecken, ecke, radius),
    seiten: seiten,
    radien: radien,
  );

  /// Mit Stich [stich] an Seite [seite] (ersetzt einen Radius dort); 0
  /// entfernt die Rundung.
  Rundungen mitSeite(int seite, Millimeter stich) => Rundungen(
    ecken: ecken,
    seiten: _gesetzt(seiten, seite, stich),
    radien: {...radien}..remove(seite),
  );

  /// Mit Bogen vom Radius [radius] an Seite [seite], [innen] nach innen
  /// gewölbt (Regel 14.1.2, ersetzt einen Stich dort); 0 entfernt ihn.
  Rundungen mitRadius(int seite, Millimeter radius, {bool innen = false}) =>
      Rundungen(
        ecken: ecken,
        seiten: {...seiten}..remove(seite),
        radien: _gesetzt(
          radien,
          seite,
          Millimeter(innen ? -radius.mm.abs() : radius.mm.abs()),
        ),
      );

  static Map<int, Millimeter> _gesetzt(
    Map<int, Millimeter> alt,
    int nummer,
    Millimeter wert,
  ) => {...alt, nummer: wert}..removeWhere((_, w) => w.mm == 0);

  /// Kontur des [grundriss] mit diesen Rundungen. Wirft [ArgumentError], wenn
  /// eine Rundung unzulässig ist: Radien, die zusammen länger sind als die
  /// Kante, ein Stich ab dem Halbkreis oder sich überschneidende Bögen. Ein
  /// Radius unter der halben Sehne gibt einen Halbkreis ([zuKleineRadien]).
  Kontur kontur(Grundriss grundriss) {
    if (leer || grundriss.ecken.isEmpty) return grundriss.kontur;
    final punkte = <Punkt>[], woelbungen = <double>[];
    for (final s in _seiten(grundriss)) {
      if (s.ecke case final ecke?) {
        punkte.add(ecke.start);
        woelbungen.add(ecke.woelbung);
      }
      punkte.add(s.kante.start);
      woelbungen.add(s.kante.woelbung);
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

  /// Der Bogen je gewölbter Seite des [grundriss] – so, wie er in der
  /// [kontur] liegt (zwischen den Rundungen der Ecken).
  Map<int, Kante> seitenboegen(Grundriss grundriss) {
    if (leer || grundriss.ecken.isEmpty) return const {};
    return {
      for (final (i, s) in _seiten(grundriss).indexed)
        if (s.kante.istBogen) i: s.kante,
    };
  }

  /// Stich der Seite [seite] in mm, nach außen positiv: der eingegebene
  /// oder der aus dem Radius (Griff im Rundungsmodus); ohne Bogen 0.
  Millimeter stichAn(Grundriss grundriss, int seite) {
    if (seiten[seite] case final stich?) return stich;
    if (!radien.containsKey(seite)) return const Millimeter(0);
    final kante = _seiten(grundriss)[seite].kante;
    final w = Kontur(grundriss.ecken).gegenUhrzeigersinn
        ? kante.woelbung
        : -kante.woelbung;
    return Millimeter((w * kante.sehne.laenge / 2).round());
  }

  /// Seiten, deren Radius kleiner ist als die halbe Sehne – sie sind als
  /// Halbkreis gerechnet (Regel 14.1.1, Hinweis).
  List<int> zuKleineRadien(Grundriss grundriss) {
    if (radien.isEmpty || grundriss.ecken.isEmpty) return const [];
    return [
      for (final (i, s) in _seiten(grundriss).indexed)
        if (radien[i] case final r? when r.mm.abs() * 2 < s.kante.sehne.laenge)
          i,
    ];
  }

  /// Je Seite die Rundung der Ecke davor (falls) und die Kante zwischen
  /// den Rundungen, gerade oder als Bogen.
  List<({Kante? ecke, Kante kante})> _seiten(Grundriss grundriss) {
    final e = grundriss.ecken;
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
    return [
      for (var i = 0; i < n; i++)
        if ((i + 1) % n case final j)
          if (e[j] - e[i] case final seite)
            if (seite.laenge - tangente[i] - tangente[j] case final rest)
              (
                ecke: tangente[i] > 0
                    ? Kante(
                        e[i] - (e[i] - e[vorher(i)]).einheit * tangente[i],
                        e[i] + seite.einheit * tangente[i],
                        math.tan(drehung[i] / 4),
                      )
                    : null,
                kante: Kante(
                  e[i] + seite.einheit * tangente[i],
                  e[j] - seite.einheit * tangente[j],
                  _woelbung(i, _pruefeRest(rest, i, j), aussen),
                ),
              ),
    ];
  }

  /// Wirft, wenn zwischen den Rundungen der Ecken [i] und [j] nichts von
  /// der Kante bleibt; sonst [rest].
  double _pruefeRest(double rest, int i, int j) {
    if (rest < 1) {
      throw ArgumentError.value(
        ecken[i]?.mm ?? ecken[j]!.mm,
        'ecke',
        'Rundung zu groß für die Kante ${_name(i)}—${_name(j)}',
      );
    }
    return rest;
  }

  /// Wölbung der Seite [i] mit Sehne [sehne]: tan(θ/4) = 2·Stich / Sehne.
  /// Aus dem Radius r: Stich = r − √(r² − (Sehne/2)²), höchstens der
  /// Halbkreis. [aussen]: Umlauf gegen den Uhrzeigersinn – dort wölbt eine
  /// positive Wölbung nach außen (Richtung aus dem Umlaufsinn, Regel
  /// 14.1.1).
  double _woelbung(int i, double sehne, bool aussen) {
    final double stich;
    if (radien[i] case final r?) {
      final halb = sehne / 2;
      final betrag = r.mm.abs().toDouble();
      final h = betrag <= halb
          ? halb
          : betrag - math.sqrt(betrag * betrag - halb * halb);
      stich = r.mm < 0 ? -h : h;
    } else {
      stich = (seiten[i]?.mm ?? 0).toDouble();
      if (stich.abs() * 2 >= sehne) {
        throw ArgumentError.value(
          stich.round(),
          'seite',
          'Stich höchstens bis zum Halbkreis der Seite ${_name(i)}',
        );
      }
    }
    final w = 2 * stich / sehne;
    return aussen ? w : -w;
  }

  static String _name(int i) => String.fromCharCode(65 + i);

  @override
  bool operator ==(Object other) =>
      other is Rundungen &&
      _gleich(other.ecken, ecken) &&
      _gleich(other.seiten, seiten) &&
      _gleich(other.radien, radien);

  static bool _gleich(Map<int, Millimeter> a, Map<int, Millimeter> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(masse);
}
