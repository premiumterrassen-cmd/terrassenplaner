import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

final _belag = Artikel(
  nummer: const Artikelnummer('10-10-073'),
  titel: 'Diele',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(60),
    staerke: const Millimeter(21),
    laengen: const [Millimeter(5000)],
  ),
  holzart: robinie,
  serie: basic,
);

Artikel _rinne(
  String nummer, {
  int? breite = 120,
  List<int> laengen = const [1200],
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Rinne $nummer',
  art: Artikelart.rinne,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  abmessungen: Abmessungen(
    breite: breite == null ? null : Millimeter(breite),
    laengen: [for (final l in laengen) Millimeter(l)],
  ),
);

final _auflage = Artikel(
  nummer: const Artikelnummer('50-30-004'),
  titel: 'Auflagerprofil',
  art: Artikelart.rinnenzubehoer,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
);

Regelwerk _regelwerk(List<Artikel> rinnen, {int? abstand, int anzahl = 1}) =>
    Regelwerk(
      Artikeldatei(
        quelle: 'test',
        version: '1',
        eintraege: [
          Artikeleintrag(
            artikel: _belag,
            verweise: {
              Beziehung.drainage.spalte: [for (final r in rinnen) r.nummer],
            },
          ),
          for (final r in rinnen)
            Artikeleintrag(
              artikel: r,
              benoetigt: {_auflage.nummer: anzahl},
              angaben: {'Abstand_Stelzfuesse': ?abstand},
            ),
          Artikeleintrag(artikel: _auflage),
        ],
      ),
    );

/// F38: wie F37, dazu Rinne an A — B, gesamte Seite (innen).
final _f38 = Planungsstand.start
    .mitAngrenzend(0, an: true)
    .mitVerblendet(1, an: true)
    .mitVerblendet(2, an: true)
    .mitVerblendet(3, an: true)
    .mitRinne(0, Rinnenlage.gesamteSeite);

int _anzahl(Anschlussbedarf b, Artikel a, [int? laenge]) => b.bedarf
    .where((m) => m.einheiten.single == a && m.laenge?.mm == laenge)
    .fold(0, (s, m) => s + m.stueck);

void main() {
  group('Rinnen im Planungsstand (M7-03)', () {
    const f01 = Planungsstand.start;

    test('Rinne setzen, Lage ändern, entfernen; Transportformat', () {
      final r = f01.mitRinne(2, Rinnenlage.vorElement);
      expect(r.anschluss.rinnen, [(seite: 2, lage: Rinnenlage.vorElement)]);
      expect(r.anschluss.rinneAn(2), Rinnenlage.vorElement);
      expect(r.anschluss.rinneAn(1), isNull);
      expect(r.anschluss.leer, isFalse);
      final zwei = r.mitRinne(0, Rinnenlage.imElement);
      expect([for (final x in zwei.anschluss.rinnen) x.seite], [0, 2]);
      expect(
        zwei.mitRinne(2, Rinnenlage.gesamteSeite).anschluss.rinneAn(2),
        Rinnenlage.gesamteSeite,
      );
      expect(r.mitRinne(2, null), f01);
      expect(r == f01.mitRinne(2, Rinnenlage.imElement), isFalse);
      expect(
        r.anschluss.hashCode ==
            f01.mitRinne(2, Rinnenlage.imElement).anschluss.hashCode,
        isFalse,
      );
      expect(r.anschluss.rinnen.clear, throwsUnsupportedError);
      expect(Planungsstand.ausBytes(zwei.zuBytes()), zwei);
      expect(Planungsstand.ausBytes(_f38.zuBytes()), _f38);
      expect(() => f01.mitRinne(4, Rinnenlage.imElement), throwsRangeError);
    });

    test('eine Rolle je Seite, nur die Rinne bleibt am Bauelement (F38)', () {
      expect(_f38.anschluss.angrenzend, [0]);
      expect(_f38.anschluss.rinneAn(0), Rinnenlage.gesamteSeite);
      final verblendet = f01.mitVerblendet(1, an: true);
      final mitRinne = verblendet.mitRinne(1, Rinnenlage.gesamteSeite);
      expect(mitRinne.anschluss.verblendet, isEmpty);
      final wieder = mitRinne.mitVerblendet(1, an: true);
      expect(wieder.anschluss.rinnen, isEmpty);
      expect(wieder.anschluss.verblendet, [1]);
      // abwählen nimmt nichts weg
      expect(
        mitRinne.mitVerblendet(1, an: false).anschluss.rinneAn(1),
        Rinnenlage.gesamteSeite,
      );
      expect(verblendet.mitRinne(1, null).anschluss.verblendet, [1]);
      expect(
        _f38.mitAngrenzend(0, an: false).anschluss.rinneAn(0),
        Rinnenlage.gesamteSeite,
      );
    });

    test('Lage aus dem Transportformat', () {
      for (final l in Rinnenlage.values) {
        expect(Rinnenlage.ausNummer(l.nummer), l);
      }
      expect([for (final l in Rinnenlage.values) l.nummer], [0, 1, 2, 3]);
      expect(() => Rinnenlage.ausNummer(4), throwsFormatException);
    });
  });

  test('Anschlussergebnis: Rinne blau, auch am Bauelement', () {
    final seiten = anschlussergebnis(_f38).seiten;
    expect(
      [for (final s in seiten) (s.seite, s.rolle)],
      [
        (0, Seitenrolle.bauelement),
        (1, Seitenrolle.verblendung),
        (2, Seitenrolle.verblendung),
        (3, Seitenrolle.verblendung),
        (0, Seitenrolle.rinne),
      ],
    );
    expect(seiten.last.bis, const Punkt(4800, 0));
    expect(Seitenrolle.ausNummer(3), Seitenrolle.rinne);
    expect(Anschlussmeldung.ausNummer(5), Anschlussmeldung.ohneRinnenartikel);
  });

  group('Rinnenartikel und Belagfläche (M7-03)', () {
    final a = _rinne('50-30-002');
    final b = _rinne('50-30-012');

    test('Lage wählt die Variante in Datenreihenfolge, sonst die erste', () {
      final r = _regelwerk([a, b]);
      expect(rinnenartikel(r, _belag, Rinnenlage.gesamteSeite), a);
      expect(rinnenartikel(r, _belag, Rinnenlage.imElement), b);
      expect(rinnenartikel(r, _belag, Rinnenlage.vorElement), b);
      expect(rinnenartikel(_regelwerk([a]), _belag, Rinnenlage.imElement), a);
      expect(rinnenartikel(_regelwerk([]), _belag, Rinnenlage.imElement), null);
      expect(rinnenartikel(null, _belag, Rinnenlage.imElement), null);
      expect(
        rinnenartikel(
          Regelwerk(
            Artikeldatei(quelle: 't', version: '1', eintraege: const []),
          ),
          _belag,
          Rinnenlage.imElement,
        ),
        null,
      );
    });

    test('F38: Seite A — B um die Rinnenbreite nach innen, 14,256 m²', () {
      final belag = rinnenstand(_f38, _belag, _regelwerk([a]));
      expect(belag.grundriss.ecken, const [
        Punkt(0, 120),
        Punkt(4800, 120),
        Punkt(4800, 3090),
        Punkt(0, 3090),
      ]);
      expect(belag.kontur.flaeche / 1e6, closeTo(14.256, 1e-9));
      expect(belag.anschluss, _f38.anschluss);
      // ohne Belag, ohne Artikel oder Breite: unverändert
      expect(rinnenstand(_f38, null, _regelwerk([a])), same(_f38));
      expect(rinnenstand(_f38, _belag, _regelwerk([])), same(_f38));
      expect(
        rinnenstand(_f38, _belag, _regelwerk([_rinne('x', breite: null)])),
        same(_f38),
      );
      expect(belagstand(_f38, (_) => const Millimeter(0)), same(_f38));
    });

    test('zwei Rinnen an einer Ecke, im Uhrzeigersinn, gerade Ecke', () {
      final stand = Planungsstand.start
          .mitRinne(1, Rinnenlage.gesamteSeite)
          .mitRinne(2, Rinnenlage.gesamteSeite);
      expect(belagstand(stand, (_) => const Millimeter(100)).grundriss.ecken, [
        Punkt.ursprung,
        const Punkt(4700, 0),
        const Punkt(4700, 2990),
        const Punkt(0, 2990),
      ]);
      // umgekehrter Umlauf: innen liegt rechts
      final rechtsherum = Planungsstand.start
          .mitGrundriss(
            FreiformGrundriss(const [
              Punkt(0, 0),
              Punkt(0, 3000),
              Punkt(4000, 3000),
              Punkt(4000, 0),
            ], geschlossen: true),
          )
          .mitRinne(0, Rinnenlage.gesamteSeite);
      expect(
        belagstand(rechtsherum, (_) => const Millimeter(100)).grundriss.ecken,
        const [
          Punkt(100, 0),
          Punkt(100, 3000),
          Punkt(4000, 3000),
          Punkt(4000, 0),
        ],
      );
      // gestreckte Ecke: der Punkt wandert senkrecht mit
      final gestreckt = Planungsstand.start
          .mitGrundriss(
            FreiformGrundriss(const [
              Punkt(0, 0),
              Punkt(2000, 0),
              Punkt(4000, 0),
              Punkt(4000, 3000),
              Punkt(0, 3000),
            ], geschlossen: true),
          )
          .mitRinne(1, Rinnenlage.gesamteSeite);
      expect(
        belagstand(gestreckt, (_) => const Millimeter(100)).grundriss.ecken,
        const [
          Punkt(0, 0),
          Punkt(2000, 100),
          Punkt(4000, 100),
          Punkt(4000, 3000),
          Punkt(0, 3000),
        ],
      );
    });

    test('zu schmal für die Rinne: Stand bleibt', () {
      final schmal = Planungsstand.start
          .mitGrundriss(
            RechteckGrundriss(const Millimeter(1000), const Millimeter(500)),
          )
          .mitRinne(0, Rinnenlage.gesamteSeite)
          .mitRinne(2, Rinnenlage.gesamteSeite);
      expect(belagstand(schmal, (_) => const Millimeter(300)), same(schmal));
      // zu kurze Seiten
      final kurz = schmal
          .mitRinne(0, null)
          .mitRinne(2, null)
          .mitRinne(1, Rinnenlage.gesamteSeite);
      expect(belagstand(kurz, (_) => const Millimeter(990)), same(kurz));
    });
  });

  group('Rinnenbedarf (M7-03)', () {
    test('F38: 4 Rinnen à 1200 mm und 6 Auflagerprofile', () {
      final rinne = _rinne('50-30-002');
      final b = rinnenbedarf(
        _f38,
        belag: _belag,
        regelwerk: _regelwerk([rinne], abstand: 1000),
      );
      expect(_anzahl(b, rinne, 1200), 4);
      expect(_anzahl(b, _auflage), 6);
      expect(b.meldungen, isEmpty);
      expect(b.stuecke, isEmpty);
    });

    test('ohne Abstand je Rinnenstück mal Anzahl; ohne Längen in lfm', () {
      final rinne = _rinne('50-30-002');
      expect(
        _anzahl(
          rinnenbedarf(
            _f38,
            belag: _belag,
            regelwerk: _regelwerk([rinne], anzahl: 2),
          ),
          _auflage,
        ),
        8,
      );
      final lfm = _rinne('50-30-003', laengen: const []);
      final b = rinnenbedarf(
        _f38.mitRinne(1, Rinnenlage.gesamteSeite),
        belag: _belag,
        regelwerk: _regelwerk([lfm]),
      );
      // 480 cm → 5, 309 cm → 4
      expect(_anzahl(b, lfm), 9);
      expect(_anzahl(b, _auflage), 2);
      // lange Seite: mehrere Längen
      final kurz = _rinne('50-30-005', laengen: const [1000, 4000]);
      final c = rinnenbedarf(
        _f38,
        belag: _belag,
        regelwerk: _regelwerk([kurz]),
      );
      // 480 cm → 4000 + 1000 mm
      expect(_anzahl(c, kurz, 4000), 1);
      expect(_anzahl(c, kurz, 1000), 1);
      expect(_anzahl(c, kurz), 0);
      expect(_anzahl(c, _auflage), 2);
    });

    test('ohne Artikel oder Belag: Hinweis, kein Material', () {
      for (final b in [
        rinnenbedarf(_f38, belag: _belag, regelwerk: _regelwerk([])),
        rinnenbedarf(_f38, regelwerk: _regelwerk([])),
      ]) {
        expect(b.bedarf, isEmpty);
        expect(b.meldungen, [Anschlussmeldung.ohneRinnenartikel]);
      }
      expect(rinnenbedarf(Planungsstand.start).meldungen, isEmpty);
    });

    test('Bedarfe zusammenführen', () {
      final a = Anschlussbedarf(
        meldungen: const [Anschlussmeldung.unterlueftung],
      );
      final b = Anschlussbedarf(
        bedarf: [
          Materialbedarf([_auflage], 1),
        ],
        meldungen: const [Anschlussmeldung.ohneRinnenartikel],
        stuecke: [
          Planstueck(
            _belag.nummer,
            _belag.titel,
            const Millimeter(100),
            ganzeLaenge: const Millimeter(100),
          ),
        ],
        blenden: [(_belag, const Millimeter(100))],
      );
      final c = a.und(b);
      expect(c.blenden, b.blenden);
      expect(b.und(b).blenden, [...b.blenden, ...b.blenden]);
      expect(c.meldungen, [
        Anschlussmeldung.unterlueftung,
        Anschlussmeldung.ohneRinnenartikel,
      ]);
      expect(c.bedarf, b.bedarf);
      expect(c.stuecke, b.stuecke);
      expect(b.und(a).stuecke, b.stuecke);
    });
  });
}
