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
///
/// „Ecke abrunden“ (Planungsregeln Alexander (Planungskern v15,
/// 13.11.2026), Regel 17.1): die beiden Nachbarkanten werden um
/// t = r / tan(θ/2) gekürzt (θ = Winkel zwischen den Kanten, bei 90° genau
/// um r), dazwischen ein Kreisbogen tangential an beide Kanten – an einer
/// konvexen Ecke wird die Fläche kleiner, an einer einspringenden größer.
/// Ein negativer Radius ist die Hohlkehle „innen“ (17.1.4): ein Bogen um
/// die alte Ecke als Mittelpunkt, die Kanten je um r gekürzt. Nur an Ecken
/// mit zwei geraden Nachbarkanten (17.1.6); reicht eine Kante genau bis zum
/// Bogen (t = Kantenlänge), wird ihr anderer Endpunkt Bogenanfang bzw.
/// -ende (17.1.5, zwei Ecken einer 4-m-Kante mit R 2 m = Halbkreis).
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

  /// Radius je Ecke, negativ = Hohlkehle „innen“ (Regel 17.1.4). Die
  /// Reihenfolge ist die der Eingabe – nach ihr bekommen die Bogenenden
  /// ihre Buchstaben (Regel 17.2, `umrisspunkte`).
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

  /// Mit Radius [radius] an Ecke [ecke], [innen] als Hohlkehle (Regel
  /// 17.1.4); 0 entfernt die Rundung.
  Rundungen mitEcke(int ecke, Millimeter radius, {bool innen = false}) =>
      Rundungen(
        ecken: _gesetzt(
          ecken,
          ecke,
          Millimeter(innen ? -radius.mm.abs() : radius.mm.abs()),
        ),
        seiten: seiten,
        radien: radien,
      );

  /// Ohne die Rundungen der Ecken [ohne] (Ecken an der Hauswand, Regel
  /// 17.4).
  Rundungen ohneEcken(Iterable<int> ohne) => Rundungen(
    ecken: {...ecken}..removeWhere((i, _) => ohne.contains(i)),
    seiten: seiten,
    radien: radien,
  );

  /// Ob die Ecke [ecke] des [grundriss] abgerundet werden kann (Regel
  /// 17.1.6): beide Nachbarkanten gerade, die Ecke kein gestreckter Punkt.
  bool rundbar(Grundriss grundriss, int ecke) {
    final n = grundriss.ecken.length;
    final vor = (ecke + n - 1) % n;
    return !_gewoelbt(vor) &&
        !_gewoelbt(ecke) &&
        _drehung(grundriss.ecken, ecke).abs() > _gestreckt;
  }

  bool _gewoelbt(int seite) =>
      seiten.containsKey(seite) || radien.containsKey(seite);

  /// Größter Radius der Ecke [ecke] des [grundriss] in ganzen cm (Regel
  /// 17.1.5) – so, dass t höchstens so lang ist wie jede Nachbarkante,
  /// abzüglich der Kürzung durch eine Rundung an ihrem anderen Ende; mit
  /// [innen] für die Hohlkehle (t = r). 0, wenn die Ecke nicht [rundbar]
  /// ist.
  Millimeter groessterRadius(
    Grundriss grundriss,
    int ecke, {
    bool innen = false,
  }) {
    if (!rundbar(grundriss, ecke)) return const Millimeter(0);
    final e = grundriss.ecken;
    final n = e.length;
    final vor = (ecke + n - 1) % n;
    final nach = (ecke + 1) % n;
    final frei = math.min(
      e[ecke].abstand(e[vor]) - _tangente(e, vor),
      e[ecke].abstand(e[nach]) - _tangente(e, nach),
    );
    final drehung = _drehung(e, ecke).abs();
    final r = innen ? frei : frei / math.tan(drehung / 2);
    return Millimeter(math.max(0, r ~/ 10) * 10);
  }

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
      if (s.leer) continue;
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

  /// Der Bogen je abgerundeter Ecke des [grundriss] (Regel 17.1) – vom
  /// Bogenanfang auf der Seite davor zum Bogenende auf der Seite danach.
  Map<int, Kante> eckboegen(Grundriss grundriss) {
    if (ecken.isEmpty || grundriss.ecken.isEmpty) return const {};
    return {for (final (i, s) in _seiten(grundriss).indexed) i: ?s.ecke};
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
  /// den Rundungen, gerade oder als Bogen; [leer], wenn von der Kante
  /// nichts bleibt (t = Kantenlänge, Regel 17.1.5).
  List<({Kante? ecke, Kante kante, bool leer})> _seiten(Grundriss grundriss) {
    final e = grundriss.ecken;
    final n = e.length;
    for (final MapEntry(key: i, value: r) in ecken.entries) {
      if (_gewoelbt((i + n - 1) % n) || _gewoelbt(i)) {
        throw ArgumentError.value(
          r.mm,
          'ecke',
          'an der Ecke ${_name(i)} liegt schon ein Bogen',
        );
      }
    }
    final aussen = Kontur(e).gegenUhrzeigersinn;
    return [
      for (var i = 0; i < n; i++)
        if ((i + 1) % n case final j)
          if (e[j] - e[i] case final seite)
            if ((_tangente(e, i), _tangente(e, j)) case (final ti, final tj))
              if (_pruefeRest(seite.laenge - ti - tj, i, j) case final rest)
                (
                  ecke: ti > 0
                      ? Kante(
                          e[i] - (e[i] - e[(i + n - 1) % n]).einheit * ti,
                          e[i] + seite.einheit * ti,
                          _eckwoelbung(e, i),
                        )
                      : null,
                  kante: Kante(
                    e[i] + seite.einheit * ti,
                    e[j] - seite.einheit * tj,
                    rest < 1 ? 0 : _woelbung(i, rest, aussen),
                  ),
                  leer: rest < 1,
                ),
    ];
  }

  /// Drehung des Umrisses an der Ecke [i] der [e] (Bogenmaß, links positiv).
  static double _drehung(List<Punkt> e, int i) {
    final n = e.length;
    final a = (e[i] - e[(i + n - 1) % n]).einheit;
    final b = (e[(i + 1) % n] - e[i]).einheit;
    return math.atan2(a.kreuz(b), a.punktprodukt(b));
  }

  /// Kürzung t der Nachbarkanten an der Ecke [i] (Regel 17.1.1):
  /// r / tan(θ/2) = r · tan(Drehung/2), bei der Hohlkehle r; ohne Rundung 0.
  double _tangente(List<Punkt> e, int i) {
    final r = ecken[i]?.mm ?? 0;
    return r < 0 ? -r.toDouble() : r * math.tan(_drehung(e, i).abs() / 2);
  }

  /// Wölbung des Bogens an der Ecke [i]: tangential tan(Drehung/4); die
  /// Hohlkehle läuft um die Ecke herum, also mit dem Winkel zwischen den
  /// Kanten (π − |Drehung|) zur anderen Seite.
  double _eckwoelbung(List<Punkt> e, int i) {
    final d = _drehung(e, i);
    return ecken[i]!.mm < 0
        ? -d.sign * math.tan((math.pi - d.abs()) / 4)
        : math.tan(d / 4);
  }

  /// Wirft, wenn die Rundungen der Ecken [i] und [j] zusammen um mehr als
  /// [eckToleranz] länger sind als die Kante; sonst [rest].
  double _pruefeRest(double rest, int i, int j) {
    if (rest < -eckToleranz) {
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
      // unter der halben Sehne der Halbkreis (Stich = halbe Sehne)
      final h =
          math.max(halb, betrag) -
          math.sqrt(math.max(0, betrag * betrag - halb * halb));
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

  /// Toleranz (mm), um die die Rundungen einer Kante zusammen länger sein
  /// dürfen als die Kante – dann treffen sich die Bögen (Regel 17.1.5, im
  /// Planungskern 0,5 cm).
  static const eckToleranz = 5.0;

  /// Drehung (Bogenmaß), unter der eine Ecke als gestreckt gilt und nicht
  /// abgerundet werden kann (im Planungskern 0,05).
  static const _gestreckt = 0.05;

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
