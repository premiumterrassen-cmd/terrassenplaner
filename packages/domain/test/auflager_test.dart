import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'auflagerdaten.dart';

/// Planungsstand im Transportformat vor M6-08 (bzw. nur mit Auflagen).
Uint8List _alt({int? auflagen}) {
  final fbb = fb.Builder();
  final masseOrt = fbb.writeListInt32([4800, 3090]);
  fbb
    ..startTable(2)
    ..addUint8(0, 0)
    ..addOffset(1, masseOrt);
  final ort = fbb.endTable();
  fbb
    ..startTable(101)
    ..addOffset(1, ort)
    ..addUint8(100, auflagen);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

List<String> _titel(List<Auflagerbereich> bereiche) => [
  for (final b in bereiche) '${b.titel} ${b.von.mm}-${b.bis.mm} ${b.pad}',
];

void main() {
  const f01 = Planungsstand.start;

  group('Auflagen (M6-08)', () {
    test('Nummern, Pads und Formatfehler', () {
      expect(Auflagen.stelzfuesse.nummer, 0);
      expect(Auflagen.stelzfuesseUndPads.nummer, 1);
      expect(Auflagen.stelzfuesse.mitPads, isFalse);
      expect(Auflagen.stelzfuesseUndPads.mitPads, isTrue);
      for (final a in Auflagen.values) {
        expect(Auflagen.ausNummer(a.nummer), a);
      }
      expect(() => Auflagen.ausNummer(2), throwsFormatException);
    });

    test('Planungsstand: Vorgabe Stelzfüße und Pads (F01), ändern, '
        'Gleichheit und Hash', () {
      expect(f01.auflagen, Auflagen.stelzfuesseUndPads);
      final nur = f01.mitAuflagen(Auflagen.stelzfuesse);
      expect(nur.auflagen, Auflagen.stelzfuesse);
      expect(nur == f01, isFalse);
      expect(nur.hashCode == f01.hashCode, isFalse);
      expect(nur.mitAuflagen(Auflagen.stelzfuesseUndPads), f01);
      expect(nur.mitGewerblich(true).auflagen, Auflagen.stelzfuesse);
    });

    test('Transportformat: hin und zurück, abwärtskompatibel', () {
      final nur = f01.mitAuflagen(Auflagen.stelzfuesse);
      expect(Planungsstand.ausBytes(nur.zuBytes()), nur);
      expect(Planungsstand.ausBytes(f01.zuBytes()), f01);
      expect(
        Planungsstand.ausBytes(_alt()).auflagen,
        Auflagen.stelzfuesseUndPads,
      );
      expect(
        Planungsstand.ausBytes(_alt(auflagen: 0)).auflagen,
        Auflagen.stelzfuesse,
      );
    });
  });

  group('Höhenbereiche aus dem Regelwerk (M6-08)', () {
    test('Pads, dann Stelzfüße in Datenreihenfolge; Packungen eines '
        'Bereichs zusammen; ohne Höhe nicht (B-122)', () {
      final bereiche = auflagerbereiche(
        auflagerRegelwerk,
        ukArtikel,
        gewerblich: false,
        auflagen: Auflagen.stelzfuesseUndPads,
      );
      expect(_titel(bereiche), [
        'Unterleger 2 mm 2-2 true',
        'Unterleger 5 mm 5-5 true',
        'Unterleger 8 mm 8-8 true',
        'Keil 14-22 14-22 false',
        'Keil 18-32 18-32 false',
        'Fuß 35-55 (10) 35-55 false',
        'Fuß 55-95 (20) 55-95 false',
        'Fuß 80-200 (5) 80-200 false',
      ]);
      expect(bereiche[5].einheiten, [fuss35, fuss35gross]);
      expect(bereiche[5].einheiten.clear, throwsUnsupportedError);
      expect(bereiche[5].angabe, (
        titel: 'Fuß 35-55 (10)',
        von: const Millimeter(35),
        bis: const Millimeter(55),
        pad: false,
      ));
    });

    test('nur Stelzfüße: ohne Pads; gewerblich: die Füße der Spalte '
        'gewerblich (M6-07)', () {
      expect(
        _titel(
          auflagerbereiche(
            auflagerRegelwerk,
            ukArtikel,
            gewerblich: true,
            auflagen: Auflagen.stelzfuesse,
          ),
        ),
        [
          'Fuß 35-55 (10) 35-55 false',
          'Fuß 55-95 (20) 55-95 false',
          'Fuß 80-200 (5) 80-200 false',
        ],
      );
      expect(
        auflagerbereiche(
          auflagerRegelwerk,
          ukArtikel,
          gewerblich: false,
          auflagen: Auflagen.stelzfuesse,
        ).first.titel,
        'Keil 14-22',
      );
    });
  });

  group('Auflager je Spalt (M6-08)', () {
    final alle = auflagerbereiche(
      auflagerRegelwerk,
      ukArtikel,
      gewerblich: false,
      auflagen: Auflagen.stelzfuesseUndPads,
    );
    final ohnePads = auflagerbereiche(
      auflagerRegelwerk,
      ukArtikel,
      gewerblich: false,
      auflagen: Auflagen.stelzfuesse,
    );
    String? wahl(int spalt, [List<Auflagerbereich>? bereiche]) => auflagerFuer(
      Millimeter(spalt),
      auflagerwahlen(bereiche ?? alle),
    )?.titel;

    test('Lagen aus einem oder zwei Pads: nach Höhe, bei gleicher Höhe '
        'erst eins, dann das ausgeglichene Paar; danach die Stelzfüße '
        '(Planungskern v6 Regel 3a.2.2)', () {
      final wahlen = auflagerwahlen(alle);
      expect(
        [for (final w in wahlen.take(9)) w.titel],
        [
          'Unterleger 2 mm',
          '2 × Unterleger 2 mm',
          'Unterleger 5 mm',
          'Unterleger 5 mm + Unterleger 2 mm',
          'Unterleger 8 mm',
          '2 × Unterleger 5 mm',
          'Unterleger 8 mm + Unterleger 2 mm',
          'Unterleger 8 mm + Unterleger 5 mm',
          '2 × Unterleger 8 mm',
        ],
      );
      expect(wahlen, hasLength(9 + 5));
      expect(wahlen[9].titel, 'Keil 14-22');
      expect(wahlen.last.titel, 'Fuß 80-200 (5)');
      expect(wahlen[3].teile, [alle[1], alle[0]]);
      expect(wahlen.first.teile.clear, throwsUnsupportedError);
      // ein Pad über einem gleich dicken: zwei gleiche Teile
      expect(wahlen[1].teile, [alle[0], alle[0]]);
      // ohne Pads nur die Stelzfüße
      expect(
        [for (final w in auflagerwahlen(ohnePads)) w.titel],
        [for (final b in ohnePads) b.titel],
      );
    });

    test('Pads bis 17 mm: die niedrigste Lage, die reicht (F30: 2 mm → '
        '2 mm, 4 mm → 2 + 2 mm), darüber die höchste', () {
      expect(wahl(-1), 'Unterleger 2 mm');
      expect(wahl(0), 'Unterleger 2 mm');
      expect(wahl(2), 'Unterleger 2 mm');
      expect(wahl(3), '2 × Unterleger 2 mm');
      expect(wahl(4), '2 × Unterleger 2 mm');
      expect(wahl(5), 'Unterleger 5 mm');
      expect(wahl(6), 'Unterleger 5 mm + Unterleger 2 mm');
      expect(wahl(8), 'Unterleger 8 mm');
      expect(wahl(9), '2 × Unterleger 5 mm');
      expect(wahl(10), '2 × Unterleger 5 mm');
      expect(wahl(11), 'Unterleger 8 mm + Unterleger 5 mm');
      expect(wahl(14), '2 × Unterleger 8 mm');
      expect(wahl(16), '2 × Unterleger 8 mm');
      expect(wahl(17), '2 × Unterleger 8 mm');
      expect(padAusgleichBis, const Millimeter(17));
    });

    test('Stelzfüße ab 18 mm: der erste passende in Datenreihenfolge', () {
      expect(wahl(18), 'Keil 14-22');
      expect(wahl(22), 'Keil 14-22');
      expect(wahl(23), 'Keil 18-32');
      expect(wahl(36), 'Fuß 35-55 (10)');
      expect(wahl(55), 'Fuß 35-55 (10)');
      expect(wahl(68), 'Fuß 55-95 (20)');
      expect(wahl(200), 'Fuß 80-200 (5)');
      // ohne Pads auch darunter
      expect(wahl(14, ohnePads), 'Keil 14-22');
    });

    test('Lücke: der nächste Stelzfuß; außerhalb der Grenzen keiner', () {
      expect(wahl(33), 'Keil 18-32');
      expect(wahl(34), 'Fuß 35-55 (10)');
      expect(wahl(201), isNull);
      expect(wahl(13, ohnePads), isNull);
      expect(wahl(0, const []), isNull);
      // nur Pads: darüber keiner
      final nurPads = [
        for (final b in alle)
          if (b.pad) b,
      ];
      expect(wahl(17, nurPads), '2 × Unterleger 8 mm');
      expect(wahl(18, nurPads), isNull);
      // Lücke zwischen zwei Füßen: der nähere
      final luecke = [ohnePads[0], ohnePads.last];
      expect(wahl(50, luecke), 'Keil 14-22');
      // gleich weit: der frühere
      expect(wahl(51, luecke), 'Keil 14-22');
      expect(wahl(52, luecke), 'Fuß 80-200 (5)');
      // mit Pads ab 18 mm unter dem niedrigsten Fuß: der nächste Fuß;
      // ohne Pads keiner
      final hoch = [...nurPads, ohnePads.last];
      expect(wahl(30, hoch), 'Fuß 80-200 (5)');
      expect(wahl(30, [ohnePads.last]), isNull);
    });
  });

  group('Höhengrenzen mit Meldung (M6-08, Abnahme)', () {
    final alle = auflagerbereiche(
      auflagerRegelwerk,
      ukArtikel,
      gewerblich: false,
      auflagen: Auflagen.stelzfuesseUndPads,
    );
    final ohnePads = auflagerbereiche(
      auflagerRegelwerk,
      ukArtikel,
      gewerblich: false,
      auflagen: Auflagen.stelzfuesse,
    );
    const aufbau = Millimeter(82);
    List<Millimeter> cm(List<int> mm) => [for (final h in mm) Millimeter(h)];

    test('Grenzen: mit Pads ab Aufbauhöhe, ohne ab dem kleinsten Fuß; '
        'Gummiband 1 mm dazu (Planungskern v6 Regel 3a.2.1)', () {
      expect(auflagergrenzen(alle, aufbau), (
        von: const Millimeter(82),
        bis: const Millimeter(283),
      ));
      expect(auflagergrenzen(ohnePads, aufbau), (
        von: const Millimeter(97),
        bis: const Millimeter(283),
      ));
      expect(auflagergrenzen(const [], aufbau), isNull);
      // nur Pads: zwei übereinander bis 17 mm
      final nurPads = [
        for (final b in alle)
          if (b.pad) b,
      ];
      expect(auflagergrenzen(nurPads, aufbau), (
        von: const Millimeter(82),
        bis: const Millimeter(100),
      ));
      expect(gummiband, const Millimeter(1));
    });

    test('unter der Mindesthöhe nur ohne Pads, über der Höchsthöhe immer', () {
      expect(auflagermeldungen(cm([86, 150]), aufbau, alle), isEmpty);
      expect(auflagermeldungen(cm([86, 150]), aufbau, ohnePads), [
        Auflagermeldung.unterMindesthoehe,
      ]);
      expect(auflagermeldungen(cm([97, 283]), aufbau, ohnePads), isEmpty);
      expect(auflagermeldungen(cm([96, 284]), aufbau, ohnePads), [
        Auflagermeldung.unterMindesthoehe,
        Auflagermeldung.ueberHoechsthoehe,
      ]);
      expect(auflagermeldungen(cm([284]), aufbau, const []), isEmpty);
    });

    test('Meldungen: Nummern und Formatfehler', () {
      expect(Auflagermeldung.unterMindesthoehe.nummer, 0);
      expect(Auflagermeldung.ueberHoechsthoehe.nummer, 1);
      for (final m in Auflagermeldung.values) {
        expect(Auflagermeldung.ausNummer(m.nummer), m);
      }
      expect(() => Auflagermeldung.ausNummer(2), throwsFormatException);
    });
  });

  group('Abstand der Auflager (M6-08, Abnahme „Abstände aus dem '
      'Regelwerk“)', () {
    test('aus den Artikeldaten, sonst 60 cm; gewerblich zwei Drittel; '
        'vorhandene UK: Spannweite', () {
      expect(
        auflagerabstand(f01, const Millimeter(500)),
        const Millimeter(500),
      );
      expect(auflagerabstand(f01, null), auflagerAbstandVorgabe);
      expect(auflagerAbstandVorgabe, const Millimeter(600));
      expect(
        auflagerabstand(f01.mitGewerblich(true), const Millimeter(600)),
        const Millimeter(400),
      );
      expect(
        auflagerabstand(f01.mitGewerblich(true), const Millimeter(500)),
        const Millimeter(333),
      );
      final vorhanden = f01
          .mitTerrassenart(Terrassenart.vorhandeneUk)
          .mitGewerblich(true);
      expect(auflagerabstand(vorhanden, null), const Millimeter(800));
    });
  });

  group('Auf Stellfüßen (Planungskern v6, Regel 3.11)', () {
    Hoehenpunkte hoehen(List<int> mm, {int? aufbau = 82}) => Hoehenpunkte(
      hoehen: [for (final h in mm) Millimeter(h)],
      aufbauhoehe: aufbau == null ? null : Millimeter(aufbau),
    );

    test('normale Terrasse: ab 18 mm Ausgleichshöhe an einem Punkt, ohne '
        'Pads immer', () {
      expect(mitStellfuessen(f01, hoehen([86, 100])), isFalse);
      // 101 − 82 − 1 = 18 mm
      expect(mitStellfuessen(f01, hoehen([86, 101])), isTrue);
      expect(
        mitStellfuessen(f01.mitAuflagen(Auflagen.stelzfuesse), hoehen([86])),
        isTrue,
      );
    });

    test('ohne Aufbauhöhe, Hochterrasse und vorhandene UK nicht', () {
      expect(mitStellfuessen(f01, hoehen([300], aufbau: null)), isFalse);
      for (final art in [
        Terrassenart.hochterrasse,
        Terrassenart.vorhandeneUk,
      ]) {
        expect(
          mitStellfuessen(
            f01.mitTerrassenart(art).mitAuflagen(Auflagen.stelzfuesse),
            hoehen([300]),
          ),
          isFalse,
        );
      }
    });
  });

  group('Unterbau (M6-08)', () {
    final hoehen = Hoehenpunkte(
      hoehen: const [Millimeter(86), Millimeter(300)],
      aufbauhoehe: const Millimeter(82),
    );

    test('normale Terrasse: Abstand, Bereiche, Grenzen und Meldungen', () {
      final u = unterbauFuer(
        f01,
        hoehen: hoehen,
        regelwerk: auflagerRegelwerk,
        uk: ukArtikel,
      );
      expect(u.auflagerabstand, const Millimeter(600));
      expect(u.auflager, hasLength(8));
      expect(u.auflager.first.titel, 'Unterleger 2 mm');
      expect(u.hoeheVon, const Millimeter(82));
      expect(u.hoeheBis, const Millimeter(283));
      expect(u.meldungen, [Auflagermeldung.ueberHoechsthoehe]);
      expect(u.auflager.clear, throwsUnsupportedError);
      expect(u.meldungen.clear, throwsUnsupportedError);
    });

    test('ohne Aufbauhöhe keine Grenzen; Hochterrasse und vorhandene UK nur '
        'der Abstand; ohne UK oder unbekannt', () {
      final ungeprueft = unterbauFuer(
        f01,
        hoehen: Hoehenpunkte(hoehen: const [Millimeter(86)]),
        regelwerk: auflagerRegelwerk,
        uk: ukArtikel,
      );
      expect(ungeprueft.auflager, hasLength(8));
      expect(ungeprueft.hoeheVon, isNull);
      expect(ungeprueft.hoeheBis, isNull);
      expect(ungeprueft.meldungen, isEmpty);
      for (final art in [
        Terrassenart.hochterrasse,
        Terrassenart.vorhandeneUk,
      ]) {
        final u = unterbauFuer(
          f01.mitTerrassenart(art),
          hoehen: hoehen,
          regelwerk: auflagerRegelwerk,
          uk: ukArtikel,
        );
        expect(u.auflagerabstand, isNotNull);
        expect(u.auflager, isEmpty);
        expect(u.meldungen, isEmpty);
      }
      final ohneUk = unterbauFuer(
        f01,
        hoehen: hoehen,
        regelwerk: auflagerRegelwerk,
      );
      expect(ohneUk.auflagerabstand, isNull);
      expect(ohneUk.auflager, isEmpty);
      expect(ohneUk.feldbreite, isNull);
      final fremd = unterbauFuer(
        f01,
        hoehen: hoehen,
        regelwerk: Regelwerk(
          Artikeldatei(quelle: 't', version: '2', eintraege: const []),
        ),
        uk: ukArtikel,
      );
      expect(fremd.auflagerabstand, auflagerAbstandVorgabe);
      expect(fremd.auflager, isEmpty);
      final ohne = unterbauFuer(f01, hoehen: hoehen, uk: ukArtikel);
      expect(ohne.auflagerabstand, auflagerAbstandVorgabe);
      expect(ohne.hoeheVon, isNull);
    });

    test('Transportformat in der Berechnung: hin und zurück, '
        'abwärtskompatibel', () {
      final u = unterbauFuer(
        f01.mitAuflagen(Auflagen.stelzfuesse),
        hoehen: Hoehenpunkte(
          hoehen: const [Millimeter(90), Millimeter(400)],
          aufbauhoehe: const Millimeter(82),
        ),
        regelwerk: auflagerRegelwerk,
        uk: ukArtikel,
      );
      final b = Berechnung(umriss: const [], flaeche: 0, unterbau: u);
      final z = Berechnung.ausBytes(b.zuBytes()).unterbau;
      expect(z.auflagerabstand, u.auflagerabstand);
      expect(z.auflager, u.auflager);
      expect(z.hoeheVon, const Millimeter(97));
      expect(z.hoeheBis, const Millimeter(283));
      expect(z.meldungen, [
        Auflagermeldung.unterMindesthoehe,
        Auflagermeldung.ueberHoechsthoehe,
      ]);
      expect(b.mitPlanung(0).unterbau, same(u));
      final leer = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0).zuBytes(),
      ).unterbau;
      expect(leer.auflagerabstand, isNull);
      expect(leer.auflager, isEmpty);
      expect(leer.hoeheVon, isNull);
      expect(leer.meldungen, isEmpty);
      // ältere Berechnung ohne Platz 110
      final fbb = fb.Builder();
      fbb.startTable(1);
      fbb.finish(fbb.endTable());
      expect(Berechnung.ausBytes(fbb.buffer).unterbau.auflagerabstand, isNull);
    });
  });
}
