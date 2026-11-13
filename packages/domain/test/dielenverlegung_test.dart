import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'altplaner.dart';

const _breite = Millimeter(60);
const _m6 = Millimeter(6000);

Referenzkonfiguration _fall(String id) => Referenzkonfiguration.ausJson(
  jsonDecode(File('test/referenzkonfigurationen/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

List<Dielenstueck> _verlege(
  Kontur kontur, {
  double winkel = 0,
  Punkt ausgangspunkt = Punkt.ursprung,
  Verlegeart verlegeart = Verlegeart.fugenschnitt,
  Millimeter laengste = _m6,
  bool verbinden = false,
  Punkt? ecke,
}) => verlegeDielen(
  kontur,
  winkel: winkel,
  ausgangspunkt: ausgangspunkt,
  dielenbreite: _breite,
  verlegeart: verlegeart,
  laengste: laengste,
  verbinden: verbinden,
  fuge: altplanerFuge,
  ecke: ecke,
);

List<int> _laengen(List<Dielenstueck> stuecke) => [
  for (final s in stuecke) s.laenge.mm,
];

double _flaeche(List<Dielenstueck> stuecke) =>
    [for (final s in stuecke) Kontur(s.umriss).flaeche]
        .fold(0, (a, b) => a + b);

void main() {
  test('Abgleich mit den Zuschnittlisten des alten Planers (F01–F13; '
      'F06–F08 und F12 nach dem Planungskern v7, R-B18; F04 ohne Stoß '
      'durch A)', () {
    const richtungen = {
      'Waagrecht': Verlegerichtung.waagrecht,
      'Senkrecht': Verlegerichtung.senkrecht,
      'Diagonal 45': Verlegerichtung.diagonal45,
      'Diagonal 135': Verlegerichtung.diagonal135,
      'Individuell 30': Verlegerichtung.individuell,
    };
    const arten = {
      'Fugenschnitt': Verlegeart.fugenschnitt,
      'Halbverband': Verlegeart.halbverband,
      'Drittelverband': Verlegeart.drittelverband,
      'Wechselverband': Verlegeart.wechselverband,
    };
    for (var nr = 1; nr <= 13; nr++) {
      final id = 'F${'$nr'.padLeft(2, '0')}';
      final fall = _fall(id);
      final e = fall.eingaben;
      final kanten = e['kanten_cm']! as Map<String, Object?>;
      final fest = switch (e['dielenlaenge']) {
        final String t when t.startsWith('fest ') => Millimeter(
          int.parse(t.substring(5)) * 10,
        ),
        _ => null,
      };
      final stand = Planungsstand.start.mitVerlegerichtung(
        richtungen[e['verlegerichtung']]!,
      );
      final neu = _laengen(
        _verlege(
          Kontur.rechteck(
            (kanten['A-B']! as int) * 10.0,
            (kanten['B-C']! as int) * 10.0,
          ),
          winkel: stand.dielenwinkel.toDouble(),
          verlegeart: arten[e['verlegeart']]!,
          laengste: fest ?? _m6,
          ecke: Punkt.ursprung,
        ),
      )..sort();
      final alt = [
        for (final z in fall.zuschnitt)
          if (z.artikel.startsWith('Terrassendiele'))
            for (var i = 0; i < z.menge; i++)
              for (final s in z.schnitteCm) (s * 10).round(),
      ]..sort();
      // Planungskern v7 Regel 9.3: kein Verband, wenn die Fläche (480 cm)
      // nicht länger als eine Diele ist; Wechselverband unregelmäßig
      if (const {'F06', 'F07', 'F08'}.contains(id)) {
        expect(neu.toSet(), {4800}, reason: id);
        continue;
      }
      // Alexander 13.11.2026: Stöße am Rand statt durch A – bei 480 × 309
      // cm reicht dann jede Reihe in eine Diele, wie bei 45° (F03)
      if (id == 'F04') {
        expect(neu, hasLength(86), reason: id);
        expect(
          neu.reduce((a, b) => a + b),
          closeTo(alt.reduce((a, b) => a + b), 154),
          reason: id,
        );
        continue;
      }
      if (id == 'F12') {
        expect(neu, isNot(alt), reason: id);
        expect(neu.reduce((a, b) => a + b), 48 * 8000, reason: id);
        continue;
      }
      expect(neu, hasLength(alt.length), reason: id);
      // schräge Längen auf 1 mm gerundet
      for (var i = 0; i < alt.length; i++) {
        expect(neu[i], closeTo(alt[i], 1), reason: '$id Stück $i');
      }
    }
  });

  test('waagrecht: Reihen ab dem Ausgangspunkt, letzte auf Restbreite', () {
    final stuecke = _verlege(Kontur.rechteck(4800, 3090));
    expect([for (final s in stuecke) s.reihe], List.generate(48, (i) => i));
    expect(_laengen(stuecke).toSet(), {4800});
    expect(stuecke.first.umriss, hasLength(4));
    expect(Kontur(stuecke.first.umriss).flaeche, closeTo(4800 * 65, 1));
    expect(Kontur(stuecke.last.umriss).flaeche, closeTo(4800 * 35, 1));
    expect(_flaeche(stuecke), closeTo(4800 * 3090, 1));
  });

  test('senkrecht: Reihen auf der anderen Seite des Ausgangspunkts', () {
    final stuecke = _verlege(Kontur.rechteck(4800, 3090), winkel: 90);
    expect([
      for (final s in stuecke) s.reihe,
    ], List.generate(74, (i) => i - 74));
    expect(_laengen(stuecke).toSet(), {3090});
    expect(_flaeche(stuecke), closeTo(4800 * 3090, 1));
  });

  test('schräg: Umrisse decken die Fläche bis auf die schmale Ecke', () {
    final stuecke = _verlege(Kontur.rechteck(4800, 3090), winkel: 45);
    // weggelassen: Dreieck mit 14 mm Höhe am Rand
    expect(_flaeche(stuecke), closeTo(4800 * 3090, 200));
    expect(_flaeche(stuecke), lessThan(4800 * 3090 - 1));
    for (final s in stuecke) {
      for (final p in s.umriss) {
        expect(p.x, inInclusiveRange(-1e-2, 4800 + 1e-2));
        expect(p.y, inInclusiveRange(-1e-2, 3090 + 1e-2));
      }
    }
  });

  test('Stücke reichen bis an den Rand, Ecken auf dem Stoß bleiben', () {
    // Ende nicht auf ganzen mm: das letzte Stück reicht trotzdem bis dorthin
    final [erstes, letztes] = _verlege(Kontur.rechteck(8000.4, 65));
    expect([erstes.laenge.mm, letztes.laenge.mm], [6000, 2000]);
    expect(
      letztes.umriss.map((p) => p.x).reduce((a, b) => a > b ? a : b),
      closeTo(8000.4, 1e-6),
    );
    // Stufe genau am Stoß bei 6 m: ihre Ecken gehören zu beiden Stücken
    final stufe = Kontur(const [
      Punkt(0, 0),
      Punkt(8000, 0),
      Punkt(8000, 30),
      Punkt(6000, 30),
      Punkt(6000, 65),
      Punkt(0, 65),
    ]);
    final [links, rechts] = _verlege(stufe);
    expect(Kontur(links.umriss).flaeche, closeTo(6000 * 65, 1e-3));
    expect(Kontur(rechts.umriss).flaeche, closeTo(2000 * 30, 1e-3));
  });

  test('Stoßraster ab der Ecke, ohne Kante quer dazu ab dem Rand', () {
    final rechteck = Kontur.rechteck(9000, 3090);
    // 135°: A liegt mitten in der Ausdehnung (−6364 bis 2185 mm); ohne
    // Ecke läuft ein Stoß durch A, mit Ecke beginnt das Raster am näheren
    // Rand (Alexander 13.11.2026)
    // alle Stoßlinien als Abstand von A in Verlegerichtung
    Set<int> stoesse(Punkt? ecke, {Punkt ab = Punkt.ursprung}) {
      final stuecke = _verlege(
        rechteck,
        winkel: 135,
        ausgangspunkt: ab,
        ecke: ecke,
      );
      return {
        for (final (i, s) in stuecke.indexed)
          if (i > 0 && stuecke[i - 1].reihe == s.reihe)
            s.umriss
                .map((p) => (p.y - p.x) / math.sqrt2)
                .reduce(math.min)
                .round(),
      };
    }

    expect(stoesse(null), {0, -6000});
    expect(stoesse(Punkt.ursprung), {-3815});
    // Ausgangspunkt 100 mm verschoben: das Raster wandert mit
    expect(
      stoesse(
        Punkt.ursprung,
        ab: const Punkt(-100 / math.sqrt2, 100 / math.sqrt2),
      ),
      {-3715},
    );
    // waagrecht und senkrecht liegt an A eine Kante quer: Raster ab A
    for (final winkel in [0.0, 90.0]) {
      expect(
        _laengen(_verlege(rechteck, winkel: winkel, ecke: Punkt.ursprung)),
        _laengen(_verlege(rechteck, winkel: winkel)),
      );
    }
    // Ecke ohne gerade Kanten (Kreis): ab dem näheren Rand
    final kreis = Kontur.kreis(const Punkt(5000, 0), 5000);
    final rund = _verlege(
      kreis,
      ausgangspunkt: const Punkt(5000, 0),
      ecke: const Punkt(5000, 0),
    );
    expect(rund.where((s) => s.reihe == 0).map((s) => s.laenge.mm), [
      6000,
      4000,
    ]);
  });

  test('Restreihen unter 15 mm Breite entfallen', () {
    expect(mindestreihenbreite, const Millimeter(15));
    expect(_verlege(Kontur.rechteck(1000, 144)), hasLength(2));
    expect(_verlege(Kontur.rechteck(1000, 145)), hasLength(3));
  });

  test('Ausgangspunkt verschiebt die Fläche mit, Stöße laufen durch ihn', () {
    final hier = _verlege(Kontur.rechteck(4800, 3090), winkel: 135);
    final dort = _verlege(
      Kontur.rechteck(4800, 3090, const Punkt(1000, -500)),
      winkel: 135,
      ausgangspunkt: const Punkt(1000, -500),
    );
    expect(_laengen(dort), _laengen(hier));
    // ein 8 m langer Streifen mit Ausgangspunkt bei 7 m: Stöße bei 1 und 7 m
    final streifen = Kontur.rechteck(8000, 65);
    expect(_laengen(_verlege(streifen, ausgangspunkt: const Punkt(7000, 0))), [
      1000,
      6000,
      1000,
    ]);
    // Verband: Versatz ab dem Ausgangspunkt (Halbverband: 7 m + 3 m),
    // Stücke mindestens 40 cm (R-B18)
    final halb = _verlege(
      Kontur.rechteck(8000, 130),
      ausgangspunkt: const Punkt(7000, 0),
      verlegeart: Verlegeart.halbverband,
    );
    expect(_laengen(halb), [1000, 6000, 1000, 4000, 4000]);
    expect([for (final s in halb) s.reihe], [0, 0, 0, 1, 1]);
  });

  test('Breite je Stück und Zuschnitte unter 5 cm (M5-07)', () {
    expect(mindestzuschnitt, const Millimeter(50));
    // 3090 = 47 × 65 + 35: die letzte Reihe ist 35 mm breit
    final stuecke = _verlege(Kontur.rechteck(4800, 3090));
    expect(stuecke.first.breite, closeTo(65, 1e-9));
    expect(stuecke.first.kurzerZuschnitt, isFalse);
    expect(stuecke.last.breite, closeTo(35, 1e-9));
    expect(stuecke.last.kurzerZuschnitt, isTrue);
    // Grenzen: genau 50 mm ist kein kurzer Zuschnitt, 49 mm schon
    expect(_verlege(Kontur.rechteck(1000, 115)).last.kurzerZuschnitt, isFalse);
    expect(_verlege(Kontur.rechteck(1000, 114)).last.kurzerZuschnitt, isTrue);
    expect(_verlege(Kontur.rechteck(6050, 65)).last.kurzerZuschnitt, isFalse);
    expect(_verlege(Kontur.rechteck(6049, 65)).last.kurzerZuschnitt, isTrue);
    expect(_verlege(Kontur.rechteck(6049, 65)).last.laenge.mm, 49);
  });

  test('Verschiebungsgrenzen: Raster in Verlegerichtung, quer Breite plus '
      'Fuge (M5-07)', () {
    ({int x, int y}) grenzen(
      Kontur kontur,
      double winkel, [
      Millimeter laengste = _m6,
    ]) {
      final g = verschiebungsgrenzen(
        kontur,
        winkel: winkel,
        dielenbreite: _breite,
        laengste: laengste,
        fuge: altplanerFuge,
      );
      return (x: g.x.mm, y: g.y.mm);
    }

    final rechteck = Kontur.rechteck(8000, 3090);
    expect(grenzen(rechteck, 0), (x: 6000, y: 65));
    expect(grenzen(rechteck, 0, const Millimeter(4000)), (x: 4000, y: 65));
    // Fläche kürzer als die Diele: das Raster ist die Ausdehnung
    expect(grenzen(Kontur.rechteck(4800, 3090), 0), (x: 4800, y: 65));
    expect(grenzen(rechteck, 90), (x: 65, y: 3090));
    expect(grenzen(rechteck, 150), (x: 6000, y: 65));
    // gedreht wie die Verlegung: Dreieck bei 30° 866 mm, nicht 1366 mm
    final dreieck = Kontur(const [Punkt(0, 0), Punkt(1000, 0), Punkt(0, 1000)]);
    expect(grenzen(dreieck, 30).x, 866);
    // 45° gilt noch als waagrecht, 46° schon als senkrecht
    expect(grenzen(rechteck, 45).x, 6000);
    expect(grenzen(rechteck, 46).y, 6000);
    expect(grenzen(rechteck, 135).x, 6000);
    expect(grenzen(rechteck, 134).y, 6000);
    // unabhängig von der Lage der Fläche
    expect(grenzen(Kontur.rechteck(4800, 3090, const Punkt(-700, 900)), 0), (
      x: 4800,
      y: 65,
    ));
  });

  test('kurze Stücke verbinden und erzwungene Länge', () {
    final kurz = Kontur.rechteck(3000, 65);
    const mitte = Punkt(1000, 0);
    expect(_laengen(_verlege(kurz, ausgangspunkt: mitte)), [1000, 2000]);
    expect(_laengen(_verlege(kurz, ausgangspunkt: mitte, verbinden: true)), [
      3000,
    ]);
    expect(
      _laengen(
        _verlege(Kontur.rechteck(8000, 65), laengste: const Millimeter(4000)),
      ),
      [4000, 4000],
    );
  });

  test('geteilte Reihen und Bögen', () {
    // U-Form: in den Schenkeln zwei Stücke je Reihe
    final u = UGrundriss.vorgabe.kontur;
    final stuecke = _verlege(u);
    final jeReihe = <int, int>{};
    for (final s in stuecke) {
      jeReihe[s.reihe] = (jeReihe[s.reihe] ?? 0) + 1;
    }
    expect(jeReihe.values.toSet(), {1, 2});
    expect(_flaeche(stuecke), closeTo(u.flaeche, u.flaeche * 0.01));
    final kreis = Kontur.kreis(const Punkt(1800, 1800), 1800);
    final rund = _verlege(kreis, winkel: 30, ausgangspunkt: kreis.punkte.first);
    expect(_flaeche(rund), closeTo(kreis.flaeche, kreis.flaeche * 0.01));
  });

  test('alle Vorgabeformen in allen Richtungen und Verlegearten', () {
    for (final form in Terrassenform.values.where(
      (f) => f != Terrassenform.freiform,
    )) {
      final stand = Planungsstand.start.mitForm(form);
      final kontur = stand.kontur;
      for (final winkel in [0, 90, 45, 135, 30, 1, 179]) {
        for (final art in Verlegeart.values) {
          final stuecke = _verlege(
            kontur,
            winkel: winkel.toDouble(),
            ausgangspunkt: kontur.punkte.first,
            verlegeart: art,
          );
          expect(
            _flaeche(stuecke),
            closeTo(kontur.flaeche, kontur.flaeche * 0.01),
            reason: '${form.name} $winkel° ${art.name}',
          );
        }
      }
    }
  });
}
