import 'dart:math' as math;

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Planungsregeln Alexander (Planungskern v15, 13.11.2026), Abschnitt 17:
/// Ecke abrunden.
final _r540 = RechteckGrundriss(const Millimeter(5400), const Millimeter(3600));

/// Ecke B bei (4000|0) mit 135° zwischen den Kanten.
final _stumpf = FreiformGrundriss(const [
  Punkt(0, 0),
  Punkt(4000, 0),
  Punkt(6000, 2000),
  Punkt(0, 2000),
], geschlossen: true);

void main() {
  group('Kürzung t = r / tan(θ/2), tangentialer Bogen (Regel 17.1.1–3)', () {
    test('90°: Kanten je um r gekürzt, Fläche r²(1 − π/4) kleiner', () {
      final k = Rundungen.keine
          .mitEcke(2, const Millimeter(1200))
          .kontur(_r540);
      expect(k.punkte, [
        const Punkt(0, 0),
        const Punkt(5400, 0),
        _nahe(5400, 2400),
        _nahe(4200, 3600),
        const Punkt(0, 3600),
      ]);
      expect(
        k.flaeche,
        closeTo(5400 * 3600 - 1200 * 1200 * (1 - math.pi / 4), 1e-3),
      );
      // tangential: kein Knick am Bogenanfang und -ende
      expect(k.innenwinkel[2], closeTo(180, 1e-9));
      expect(k.innenwinkel[3], closeTo(180, 1e-9));
    });

    test('135°: t = 0,41 · r', () {
      final k = Rundungen.keine
          .mitEcke(1, const Millimeter(1000))
          .kontur(_stumpf);
      final t = 1000 / math.tan(135 / 2 * math.pi / 180);
      expect(t, closeTo(414.2, 0.1));
      expect(k.punkte[1], _nahe(4000 - t, 0));
      expect(k.punkte[2], _nahe(4000 + t / math.sqrt2, t / math.sqrt2));
      expect(k.innenwinkel[1], closeTo(180, 1e-9));
    });

    test('Hohlkehle „innen“: Bogen um die alte Ecke, Kanten je um r gekürzt '
        '(17.1.4)', () {
      final konvex = Rundungen.keine
          .mitEcke(2, const Millimeter(1200), innen: true)
          .kontur(_r540);
      expect(konvex.punkte[2], _nahe(5400, 2400));
      expect(konvex.punkte[3], _nahe(4200, 3600));
      final bogen = konvex.kanten[2];
      expect(bogen.mittelpunkt, _nahe(5400, 3600));
      expect(bogen.radius, closeTo(1200, 1e-6));
      // der Viertelkreis um die Ecke fehlt
      expect(
        konvex.flaeche,
        closeTo(5400 * 3600 - math.pi * 1200 * 1200 / 4, 1e-3),
      );
      // einspringende Ecke der L-Form: der Viertelkreis kommt dazu
      final l = LGrundriss.vorgabe;
      final innen = Rundungen.keine
          .mitEcke(2, const Millimeter(300), innen: true)
          .kontur(l);
      expect(innen.kanten[2].mittelpunkt, _nahe(2700, 1800));
      expect(
        innen.flaeche,
        closeTo(Kontur(l.ecken).flaeche + math.pi * 300 * 300 / 4, 1e-3),
      );
      // 135°: die Hohlkehle kürzt um r, der Bogen läuft um die Ecke
      final stumpf = Rundungen.keine
          .mitEcke(1, const Millimeter(1000), innen: true)
          .kontur(_stumpf);
      expect(stumpf.punkte[1], _nahe(3000, 0));
      expect(stumpf.kanten[1].mittelpunkt, _nahe(4000, 0));
      expect(stumpf.kanten[1].winkel.abs(), closeTo(math.pi * 3 / 4, 1e-9));
    });

    test('Haken „innen“ als negativer Radius im Transport', () {
      final r = Rundungen.keine.mitEcke(2, const Millimeter(-500), innen: true);
      expect(r.ecken, {2: const Millimeter(-500)});
      expect(r.masse, [0, 2, -500]);
      expect(Rundungen.aus(r.masse), r);
      expect(r.mitEcke(2, const Millimeter(-500)).ecken, {
        2: const Millimeter(500),
      });
    });
  });

  group('Radius zu groß (Regel 17.1.5)', () {
    test('t = Kantenlänge: der Nachbarpunkt ist Bogenanfang und -ende – zwei '
        'Ecken einer 4,00-m-Kante mit R 2,00 m sind ein Halbkreis', () {
      final g = RechteckGrundriss(
        const Millimeter(4000),
        const Millimeter(3000),
      );
      final k = Rundungen.keine
          .mitEcke(0, const Millimeter(2000))
          .mitEcke(1, const Millimeter(2000))
          .kontur(g);
      expect(k.punkte, [
        _nahe(0, 2000),
        _nahe(2000, 0),
        _nahe(4000, 2000),
        const Punkt(4000, 3000),
        const Punkt(0, 3000),
      ]);
      expect(k.kanten[0].mittelpunkt, _nahe(2000, 2000));
      expect(k.kanten[1].mittelpunkt, _nahe(2000, 2000));
      expect(
        k.flaeche,
        closeTo(4000 * 3000 - 2 * 2000 * 2000 * (1 - math.pi / 4), 1e-3),
      );
      // eine Ecke allein: die Kante endet am Bogen, kein Stück Kante bleibt
      final eine = Rundungen.keine.mitEcke(1, const Millimeter(3000)).kontur(g);
      expect(eine.punkte, [
        const Punkt(0, 0),
        _nahe(1000, 0),
        const Punkt(4000, 3000),
        const Punkt(0, 3000),
      ]);
    });

    test('größter Radius je Ecke in ganzen cm', () {
      expect(Rundungen.keine.groessterRadius(_r540, 2), const Millimeter(3600));
      expect(
        Rundungen.keine.groessterRadius(_r540, 2, innen: true),
        const Millimeter(3600),
      );
      // die Rundung der Nachbarecke kürzt die Kante schon
      final b = Rundungen.keine.mitEcke(1, const Millimeter(1000));
      expect(b.groessterRadius(_r540, 2), const Millimeter(2600));
      expect(b.groessterRadius(_r540, 0), const Millimeter(3600));
      final d = Rundungen.keine.mitEcke(3, const Millimeter(1000));
      expect(d.groessterRadius(_r540, 2), const Millimeter(3600));
      expect(d.groessterRadius(_r540, 0), const Millimeter(2600));
      // 135°: t = 2,83 m → r = t · tan(67,5°) = 6,83 m
      expect(
        Rundungen.keine.groessterRadius(_stumpf, 1),
        const Millimeter(6820),
      );
      expect(
        Rundungen.keine.groessterRadius(_stumpf, 1, innen: true),
        const Millimeter(2820),
      );
      // ohne Platz 0, an einer Ecke mit Bogen daneben 0
      expect(
        Rundungen.keine
            .mitEcke(1, const Millimeter(5400))
            .mitEcke(3, const Millimeter(5400))
            .groessterRadius(_r540, 2),
        const Millimeter(0),
      );
      expect(
        Rundungen.keine
            .mitSeite(1, const Millimeter(100))
            .groessterRadius(_r540, 2),
        const Millimeter(0),
      );
    });
  });

  test('Bögen der Ecken; Ecken an der Hauswand ohne Rundung', () {
    final r = Rundungen.keine
        .mitEcke(2, const Millimeter(1200))
        .mitEcke(0, const Millimeter(500), innen: true);
    final boegen = r.eckboegen(_r540);
    expect(boegen.keys, [0, 2]);
    expect(boegen[2]!.start, _nahe(5400, 2400));
    expect(boegen[2]!.ende, _nahe(4200, 3600));
    expect(boegen[0]!.start, _nahe(0, 500));
    expect(boegen[0]!.ende, _nahe(500, 0));
    expect(Rundungen.keine.eckboegen(_r540), isEmpty);
    expect(r.eckboegen(KreisGrundriss.vorgabe), isEmpty);
    expect(r.ohneEcken([2, 3]).ecken, {0: const Millimeter(-500)});
    expect(r.ohneEcken(const []), r);
  });

  _formaenderung();
  _buchstaben();
  _plaene();
}

void _formaenderung() {
  group('Formänderung behält Bögen (Regel 17.6)', () {
    final mitBogen = Planungsstand(
      grundriss: _r540,
      rundungen: Rundungen.keine
          .mitRadius(1, const Millimeter(4000))
          .mitEcke(3, const Millimeter(500), innen: true),
    );

    test('Anbau: gleiche Seite behält den Radius, die Ecke am selben Ort '
        'ihre Rundung', () {
      final anbau = FreiformGrundriss(const [
        Punkt(0, 0),
        Punkt(5400, 0),
        Punkt(5400, 3600),
        Punkt(0, 3600),
        Punkt(-1000, 1800),
      ], geschlossen: true);
      final r = mitBogen.mitGrundriss(anbau).rundungen;
      expect(r.radien, {1: const Millimeter(4000)});
      expect(r.ecken, {3: const Millimeter(-500)});
      // nach innen gewölbt bleibt nach innen
      final innen = mitBogen
          .mitRundungen(
            Rundungen.keine.mitRadius(1, const Millimeter(4000), innen: true),
          )
          .mitGrundriss(anbau);
      expect(innen.rundungen.radien, {1: const Millimeter(-4000)});
    });

    test('Stich: dieselbe Seite behält ihn, ein Teil des Bogens bekommt '
        'dessen Radius', () {
      final stich = Planungsstand(
        grundriss: _r540,
        rundungen: Rundungen.keine.mitSeite(1, const Millimeter(600)),
      );
      final bogen = stich.rundungen.seitenboegen(_r540)[1]!;
      final scheitel = bogen.start.gedreht(bogen.winkel / 2, bogen.mittelpunkt);
      final geteilt = FreiformGrundriss([
        const Punkt(0, 0),
        const Punkt(5400, 0),
        scheitel,
        const Punkt(5400, 3600),
        const Punkt(0, 3600),
      ], geschlossen: true);
      final r = stich.mitGrundriss(geteilt).rundungen;
      expect(r.seiten, isEmpty);
      expect(r.radien.keys, [1, 2]);
      expect(r.radien[1]!.mm, closeTo(bogen.radius, 0.5));
      expect(r.radien[2], r.radien[1]);
      final gleich = FreiformGrundriss([
        ..._r540.ecken,
        const Punkt(-1000, 1800),
      ], geschlossen: true);
      expect(stich.mitGrundriss(gleich).rundungen.seiten, {
        1: const Millimeter(600),
      });
    });

    test('ohne passenden Ort oder unzulässig: keine Rundungen', () {
      final verschoben = FreiformGrundriss(const [
        Punkt(0, 0),
        Punkt(6000, 0),
        Punkt(6000, 3600),
        Punkt(1000, 3600),
        Punkt(0, 1800),
      ], geschlossen: true);
      expect(mitBogen.mitGrundriss(verschoben).rundungen, Rundungen.keine);
      // die Ecke D bleibt, ihre Rundung passt aber nicht mehr
      final eng = FreiformGrundriss(const [
        Punkt(0, 3300),
        Punkt(5400, 3300),
        Punkt(5400, 3600),
        Punkt(0, 3600),
        Punkt(-100, 3450),
      ], geschlossen: true);
      expect(mitBogen.mitGrundriss(eng).rundungen, Rundungen.keine);
      expect(
        mitBogen.mitGrundriss(KreisGrundriss.vorgabe).rundungen,
        Rundungen.keine,
      );
    });
  });

  test('Ecken an der Hauswand werden nicht abgerundet (Regel 17.4)', () {
    final stand = Planungsstand(
      grundriss: _r540,
      rundungen: Rundungen.keine
          .mitEcke(0, const Millimeter(500))
          .mitEcke(2, const Millimeter(500)),
    );
    expect(
      [for (var i = 0; i < 4; i++) stand.eckeRundbar(i)],
      [true, true, true, true],
    );
    final wand = stand.mitAngrenzend(1, an: true);
    expect(wand.rundungen.ecken, {0: const Millimeter(500)});
    expect(
      [for (var i = 0; i < 4; i++) wand.eckeRundbar(i)],
      [true, false, false, true],
    );
    // Seite D—A: Ecken D und A
    expect(stand.mitAngrenzend(3, an: true).rundungen.ecken, {
      2: const Millimeter(500),
    });
    expect(wand.mitAngrenzend(1, an: false).rundungen, wand.rundungen);
    expect(
      Planungsstand.start.mitGrundriss(KreisGrundriss.vorgabe).eckeRundbar(0),
      isFalse,
    );
    expect(
      stand
          .mitRundungen(Rundungen.keine.mitSeite(0, const Millimeter(100)))
          .eckeRundbar(1),
      isFalse,
    );
  });
}

/// Buchstaben im Plan: Regel 17.2 (abgerundete Ecken) und Regel 16.6
/// (Aussparungen).
void _buchstaben() {
  String namen(List<Planpunkt> punkte) =>
      [for (final p in punkte) eckbuchstabe(p.buchstabe)].join();

  group('Buchstaben bleiben fest (Regel 17.2)', () {
    test('Bogenanfang behält den Buchstaben, das Bogenende bekommt den '
        'nächsten freien', () {
      final stand = Planungsstand(
        grundriss: _r540,
        rundungen: Rundungen.keine.mitEcke(2, const Millimeter(1200)),
      );
      final p = umrisspunkte(stand);
      expect(namen(p), 'ABCED');
      expect(p[2].ort, _nahe(5400, 2400));
      expect(p[3].ort, _nahe(4200, 3600));
      expect([for (final q in p) q.ecke], [0, 1, 2, 2, 3]);
      expect(umrisspunkte(Planungsstand(grundriss: _r540)), isEmpty);
      // umgekehrter Umlauf: derselbe Punkt behält C
      final umgekehrt = FreiformGrundriss(
        _r540.ecken.reversed.toList(),
        geschlossen: true,
      );
      final q = umrisspunkte(
        Planungsstand(
          grundriss: umgekehrt,
          rundungen: Rundungen.keine.mitEcke(1, const Millimeter(1200)),
        ),
      );
      expect(namen(q), 'DECBA');
      expect(q[1].ort, _nahe(4200, 3600));
      expect(q[2].ort, _nahe(5400, 2400));
    });

    test('Reihenfolge der Rundungen; t = Kantenlänge ohne eigenen Punkt', () {
      final zwei = Planungsstand(
        grundriss: _r540,
        rundungen: Rundungen.keine
            .mitEcke(3, const Millimeter(500))
            .mitEcke(1, const Millimeter(500)),
      );
      expect(namen(umrisspunkte(zwei)), 'ABFCDE');
      final g = RechteckGrundriss(
        const Millimeter(4000),
        const Millimeter(3000),
      );
      Planungsstand mit(Rundungen r) =>
          Planungsstand(grundriss: g, rundungen: r);
      const r2 = Millimeter(2000);
      // Halbkreis aus A und B: B wandert ans Bogenende
      final ab = umrisspunkte(
        mit(Rundungen.keine.mitEcke(0, r2).mitEcke(1, r2)),
      );
      expect(namen(ab), 'AEBCD');
      expect(ab[2].ort, _nahe(4000, 2000));
      final ba = umrisspunkte(
        mit(Rundungen.keine.mitEcke(1, r2).mitEcke(0, r2)),
      );
      expect(namen(ba), 'ABECD');
      expect(ba[1].ort, _nahe(2000, 0));
      // Bogen bis an die Nachbarecke C
      final bc = umrisspunkte(
        mit(Rundungen.keine.mitEcke(1, const Millimeter(3000))),
      );
      expect(namen(bc), 'ABCD');
      expect(bc[1].ort, _nahe(1000, 0));
    });

    test('Bögen der Ecken im Bogenmaß', () {
      final stand = Planungsstand(
        grundriss: _r540,
        rundungen: Rundungen.keine
            .mitEcke(2, const Millimeter(1200))
            .mitRadius(0, const Millimeter(4000)),
      );
      final b = bogenmasse(stand);
      expect([for (final m in b) m.seite], [0, eckbogenSeite(2)]);
      expect(eckbogenSeite(2), -3);
      expect(b[1].laenge, closeTo(math.pi / 2 * 1200, 1e-6));
      expect(b[1].radius, closeTo(1200, 1e-6));
      // außen am Scheitel, von der Fläche weg
      expect(b[1].aussen.x, greaterThan(0));
      expect(b[1].aussen.y, greaterThan(0));
    });
  });

  group('Aussparungen mit eigenen Buchstaben (Regel 16.6)', () {
    test('fortlaufend nach den Außenecken, gemeinsame Ecke = derselbe '
        'Buchstabe, Kreis und andere Beläge ohne', () {
      final loch = Planungsstand(grundriss: _r540).mitNeuemAusschnitt();
      final e = aussparungsecken(loch, const []);
      expect(namen(e), 'EFGH');
      expect([for (final p in e) p.ecke], [0, 0, 0, 0]);
      expect(e.first.ort, loch.ausschnitte[0].kontur.punkte.first);
      expect(aussparungskante(e, 0, 1), 'F–G');
      expect(aussparungskante(e, 0, 3), 'H–E');
      expect(aussparungskante(e, 0, 4), isNull);
      expect(aussparungskante(e, 0, -1), isNull);
      expect(aussparungskante(e, 1, 0), isNull);
      // nach den Bogenenden
      final rund = loch.mitRundungen(
        Rundungen.keine.mitEcke(2, const Millimeter(1200)),
      );
      expect(namen(aussparungsecken(rund, umrisspunkte(rund))), 'FGHI');
      // in der Ecke A und eine zweite Aussparung mit gemeinsamer Ecke
      final ecke = Ausschnitt(
        bezeichnung: 'A2',
        x: const Millimeter(0),
        y: const Millimeter(0),
        laenge: const Millimeter(1000),
        breite: const Millimeter(1000),
      );
      final daneben = Ausschnitt(
        bezeichnung: 'A3',
        x: const Millimeter(1000),
        y: const Millimeter(0),
        laenge: const Millimeter(500),
        breite: const Millimeter(1000),
      );
      final zwei = Planungsstand(
        grundriss: _r540,
        ausschnitte: [ecke, daneben],
      );
      final z = aussparungsecken(zwei, const []);
      expect(namen(z), 'AEFGEHIF');
      expect([for (final p in z) p.ecke], [0, 0, 0, 0, 1, 1, 1, 1]);
      final andere = Planungsstand(
        grundriss: _r540,
        ausschnitte: [
          ecke.mitForm(Ausschnittform.kreis),
          ecke.mitFunktion(Ausschnittfunktion.andererBelag),
          daneben.mitForm(Ausschnittform.dreieck),
        ],
      );
      final d = aussparungsecken(andere, const []);
      expect(namen(d), 'EFG');
      expect([for (final p in d) p.ecke], [2, 2, 2]);
      expect(
        aussparungsecken(
          const Planungsstand(grundriss: KreisGrundriss.vorgabe)
              .mitNeuemAusschnitt(),
          const [],
        ).first.buchstabe,
        0,
      );
    });

    test('Planbild: Punkte hin und zurück; ältere Tabelle ohne', () {
      final stand = Planungsstand(
        grundriss: _r540,
        rundungen: Rundungen.keine.mitEcke(2, const Millimeter(1200)),
      ).mitNeuemAusschnitt();
      final umriss = umrisspunkte(stand);
      final p = Planbild(
        umrisspunkte: umriss,
        aussparungsecken: aussparungsecken(stand, umriss),
      );
      final fbb = fb.Builder();
      fbb.finish(p.schreibe(fbb));
      final zurueck = Planbild.lies(
        fb.BufferContext.fromBytes(fbb.buffer),
        fb.BufferContext.fromBytes(fbb.buffer).derefObject(0),
      );
      expect(zurueck.umrisspunkte, p.umrisspunkte);
      expect(zurueck.aussparungsecken, p.aussparungsecken);
      expect(p.umrisspunkte.clear, throwsUnsupportedError);
      expect(p.aussparungsecken.clear, throwsUnsupportedError);
      final leer = fb.Builder();
      leer.finish(Planbild.leer.schreibe(leer));
      final alt = Planbild.lies(
        fb.BufferContext.fromBytes(leer.buffer),
        fb.BufferContext.fromBytes(leer.buffer).derefObject(0),
      );
      expect(alt.umrisspunkte, isEmpty);
      expect(alt.aussparungsecken, isEmpty);
    });
  });

  test('Anschluss: Blenden an Ecken und Aussparungen hin und zurück', () {
    final a = Anschluss.keiner
        .mitEckblende(3, an: true)
        .mitEckblende(1, an: true)
        .mitAussparungsblende((ausschnitt: 1, kante: 0), an: true)
        .mitAussparungsblende((ausschnitt: 0, kante: 2), an: true)
        .mitAussparungsblende((ausschnitt: 0, kante: 1), an: true);
    expect(a.eckblenden, [1, 3]);
    expect(a.aussparungsblenden, [
      (ausschnitt: 0, kante: 1),
      (ausschnitt: 0, kante: 2),
      (ausschnitt: 1, kante: 0),
    ]);
    expect(a.leer, isFalse);
    expect(Anschluss.keiner.mitEckblende(1, an: true).leer, isFalse);
    expect(a.eckblendeAn(1), isTrue);
    expect(a.eckblendeAn(2), isFalse);
    final stand = Planungsstand(grundriss: _r540, anschluss: a);
    final zurueck = Planungsstand.ausBytes(stand.zuBytes());
    expect(zurueck.anschluss, a);
    expect(zurueck.anschluss.hashCode, a.hashCode);
    expect(a == a.mitEckblende(1, an: false), isFalse);
    expect(
      a == a.mitAussparungsblende((ausschnitt: 0, kante: 1), an: false),
      isFalse,
    );
    expect(a.ohneAussparungsblenden().aussparungsblenden, isEmpty);
    expect(a.ohneAussparungsblenden().eckblenden, [1, 3]);
    // bleiben bei anderen Änderungen des Anschlusses
    final weiter = a
        .mitVerblendet(0, an: true)
        .mitRinnenfarbe(Rinnenfarbe.anthrazit);
    expect(weiter.eckblenden, a.eckblenden);
    expect(weiter.aussparungsblenden, a.aussparungsblenden);
    expect(a.eckblenden.clear, throwsUnsupportedError);
    expect(a.aussparungsblenden.clear, throwsUnsupportedError);
    expect(eckennummern(_r540.ecken), [0, 1, 2, 3]);
    expect(eckennummern(_r540.ecken, geschlossen: false), [0, 1, 2, 3]);
  });
}

/// Beschriftung der Pläne (Unterlagen): Buchstaben an Bogenanfang und
/// -ende, Kantenmaße der geraden Stücke, Buchstaben der Aussparungen.
void _plaene() {
  const de = Unterlagentexte.deutsch;
  Berechnung berechnung(Planungsstand stand) {
    final umriss = umrisspunkte(stand);
    return Berechnung(
      umriss: stand.kontur.vieleck(),
      ecken: stand.grundriss.ecken,
      flaeche: stand.kontur.flaeche,
      planbild: Planbild(
        boegen: bogenmasse(stand),
        umrisspunkte: umriss,
        aussparungsecken: aussparungsecken(stand, umriss),
      ),
    );
  }

  test('Unterlagen: Buchstaben am Bogen, Maße der geraden Stücke, '
      'Aussparungen (Regel 17.2, 16.6)', () {
    final stand = Planungsstand(
      grundriss: _r540,
      rundungen: Rundungen.keine.mitEcke(2, const Millimeter(1200)),
    ).mitNeuemAusschnitt();
    final b = berechnung(stand);
    final texte = umrissbeschriftung(de, b);
    expect(
      [for (final t in texte) t.text],
      [
        'A',
        'B',
        'C',
        'E',
        'D',
        '5,40 m',
        '2,40 m',
        '4,20 m',
        '3,60 m',
        'F',
        'G',
        'H',
        'I',
      ],
    );
    final a = 5400 * beschriftungsanteil;
    // C vor der Kante B–C, E unter der Kante C–D
    expect(texte[2].ort, _nahe(5400 + a, 2400));
    expect(texte[3].ort, _nahe(4200, 3600 + a));
    // A an der Ecke auf der Winkelhalbierenden
    expect(texte[0].ort, _nahe(-a / math.sqrt2, -a / math.sqrt2));
    // Maß der geraden Stücke in ihrer Mitte
    expect(texte[6].ort, _nahe(5400 + a, 1200));
    expect(texte[7].ort, _nahe(2100, 3600 + a));
    // Aussparung: in sie hinein
    final loch = stand.ausschnitte[0].kontur.punkte;
    final mitte = (loch[0] + loch[2]) * 0.5;
    expect(
      texte[9].ort,
      _nahe(
        loch[0].x + (mitte - loch[0]).einheit.x * a,
        loch[0].y + (mitte - loch[0]).einheit.y * a,
      ),
    );
    // ohne abgerundete Ecke: Buchstaben an den Ecken, Aussparung danach
    final eckig = berechnung(
      Planungsstand(grundriss: _r540).mitNeuemAusschnitt(),
    );
    expect(
      [for (final t in umrissbeschriftung(de, eckig)) t.text],
      [
        'A',
        'B',
        'C',
        'D',
        '5,40 m',
        '3,60 m',
        '5,40 m',
        '3,60 m',
        'E',
        'F',
        'G',
        'H',
      ],
    );
    // gemeinsame Ecke mit dem Umriss nur einmal; Bogen bis zur Nachbarecke
    // ohne Maß
    final g = RechteckGrundriss(const Millimeter(4000), const Millimeter(3000));
    final bisC = berechnung(
      Planungsstand(
        grundriss: g,
        rundungen: Rundungen.keine.mitEcke(1, const Millimeter(3000)),
        ausschnitte: [
          Ausschnitt(
            bezeichnung: 'A1',
            x: const Millimeter(0),
            y: const Millimeter(0),
            laenge: const Millimeter(500),
            breite: const Millimeter(500),
          ),
        ],
      ),
    );
    final t2 = umrissbeschriftung(de, bisC);
    expect(
      [for (final t in t2) t.text],
      ['A', 'B', 'C', 'D', '1,00 m', '4,00 m', '3,00 m', 'E', 'F', 'G'],
    );
    // B vor der Kante A–B
    expect(t2[1].ort, _nahe(1000, -4000 * beschriftungsanteil));
  });
}

/// Punkt höchstens 1 µm neben ([x]|[y]).
Matcher _nahe(double x, double y) => predicate<Punkt>(
  (p) => (p.x - x).abs() < 1e-6 && (p.y - y).abs() < 1e-6,
  '($x|$y)',
);
