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

Artikel _artikel(
  String nummer,
  Artikelart art, {
  int inhalt = 1,
  int? breite,
  List<int> laengen = const [],
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Artikel $nummer',
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: inhalt),
  abmessungen: Abmessungen(
    breite: breite == null ? null : Millimeter(breite),
    laengen: [for (final l in laengen) Millimeter(l)],
  ),
);

/// RELO V eloxiert (VPE 10), Auflagerprofil blank (VPE 14), Farbvariante
/// anthrazit mit eigenem Auflagerprofil, Eckverbundwinkel VPE 50/25.
final _v = _artikel('v-eloxiert', Artikelart.rinne, inhalt: 10, breite: 120);
final _va = _artikel('va-blank', Artikelart.rinnenzubehoer, inhalt: 14);
final _vAnthrazit = _artikel('v-anthrazit', Artikelart.rinne, inhalt: 10);
final _vaAnthrazit = _artikel('va-anthrazit', Artikelart.rinnenzubehoer);
final _e50 = _artikel('e-50', Artikelart.eckverbinder, inhalt: 50);
final _e25 = _artikel('e-25', Artikelart.eckverbinder, inhalt: 25);
final _ukHolz = Artikel(
  nummer: const Artikelnummer('uk'),
  titel: 'UK',
  art: Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(40),
    staerke: const Millimeter(60),
    laengen: const [Millimeter(4000)],
  ),
  holzart: robinie,
  serie: basic,
);

/// Regelwerk mit den [rinnen] als Drainage-Varianten des Belags. Die erste
/// Rinne hat die [zubehoer]-Verweise, alle Rinnen das [pflicht]zubehör; die
/// UK nennt die [ukEck]-Verbinder.
Regelwerk _regelwerk(
  List<Artikel> rinnen, {
  List<Artikel> zubehoer = const [],
  Map<Artikel, int> pflicht = const {},
  List<Artikel> ukEck = const [],
  bool mitUk = true,
}) {
  final weitere = {
    ...zubehoer,
    ...pflicht.keys,
    ...ukEck,
    _va,
    _vAnthrazit,
    _vaAnthrazit,
  }.difference(rinnen.toSet());
  return Regelwerk(
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
        for (final (i, r) in rinnen.indexed)
          Artikeleintrag(
            artikel: r,
            verweise: {
              if (i == 0)
                Beziehung.zubehoer.spalte: [for (final z in zubehoer) z.nummer],
            },
            benoetigt: {
              for (final MapEntry(:key, :value) in pflicht.entries)
                key.nummer: value,
            },
          ),
        if (mitUk)
          Artikeleintrag(
            artikel: _ukHolz,
            verweise: {
              Beziehung.eckverbinder.spalte: [for (final e in ukEck) e.nummer],
            },
          ),
        for (final a in weitere)
          Artikeleintrag(
            artikel: a,
            verweise: {
              if (a == _vAnthrazit)
                Beziehung.zubehoer.spalte: [_vaAnthrazit.nummer],
            },
          ),
      ],
    ),
  );
}

/// Stück des Artikels [a] im Bedarf [b].
int _anzahl(Anschlussbedarf b, Artikel a) => b.bedarf
    .where((m) => m.einheiten.first == a)
    .fold(0, (s, m) => s + m.stueck);

/// F38: wie F37, dazu Rinne an A — B, gesamte Seite (innen).
final _f38 = Planungsstand.start
    .mitAngrenzend(0, an: true)
    .mitVerblendet(1, an: true)
    .mitVerblendet(2, an: true)
    .mitVerblendet(3, an: true)
    .mitRinne(0, Rinnenlage.gesamteSeite);

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

  group('Rinne je Kante (Planungskern v11, Regel 13.1.1)', () {
    Planungsstand freiform(List<Punkt> punkte) => Planungsstand.start
        .mitGrundriss(FreiformGrundriss(punkte, geschlossen: true));

    test('nur gerade waagerechte oder senkrechte Seiten ab 30 cm', () {
      const s = Planungsstand.start;
      expect(
        [for (var i = -1; i <= 5; i++) rinneMoeglich(s, i)],
        [false, true, true, true, true, false, false],
      );
      // genau 30 cm ja, 29,9 cm nein
      for (final (breite, erwartet) in [(300.0, true), (299.0, false)]) {
        final f = freiform([
          Punkt.ursprung,
          Punkt(breite, 0),
          Punkt(breite, 1000),
          const Punkt(0, 1000),
        ]);
        expect(rinneMoeglich(f, 0), erwartet);
      }
      // waagerecht bis 5 mm Abweichung, senkrecht ebenso
      for (final (d, erwartet) in [(5.0, true), (6.0, false)]) {
        final schraeg = freiform([
          Punkt.ursprung,
          Punkt(1000, d),
          Punkt(1000 + d, 1000),
          const Punkt(0, 1000),
        ]);
        expect(rinneMoeglich(schraeg, 0), erwartet);
        expect(rinneMoeglich(schraeg, 1), erwartet);
      }
      // Bogen (Stich) nein, Kreis und offene Freiform haben keine Seiten
      final bogen = s.mitRundungen(
        Rundungen.keine.mitSeite(0, const Millimeter(100)),
      );
      expect(rinneMoeglich(bogen, 0), isFalse);
      expect(rinneMoeglich(bogen, 1), isTrue);
      expect(rinneMoeglich(s.mitGrundriss(KreisGrundriss.vorgabe), 0), isFalse);
    });

    test('Kante, Länge und Richtung nach innen', () {
      expect(rinnenkanten(_f38), [
        (
          seite: 0,
          von: Punkt.ursprung,
          bis: const Punkt(4800, 0),
          innen: const Punkt(0, 1),
        ),
      ]);
      expect(rinnenlaenge(rinnenkanten(_f38).single), 4800);
      // nicht mögliche Seiten fallen weg, mit [geplant] nur die gewählten
      final bogen = _f38
          .mitRinne(1, Rinnenlage.gesamteSeite)
          .mitRundungen(Rundungen.keine.mitSeite(0, const Millimeter(100)));
      expect([for (final k in rinnenkanten(bogen)) k.seite], [1]);
      final zwei = _f38.mitRinne(2, Rinnenlage.imElement);
      expect(
        [for (final k in rinnenkanten(zwei, geplant: (s) => s == 2)) k.seite],
        [2],
      );
      expect(rinnenkanten(zwei)[1].innen, const Punkt(0, -1));
    });

    test('Lage wählt die Variante in Datenreihenfolge, sonst die erste', () {
      final r = _regelwerk([_v, _vAnthrazit]);
      expect(rinnenartikel(r, _belag, Rinnenlage.gesamteSeite), _v);
      expect(rinnenartikel(r, _belag, Rinnenlage.imElement), _vAnthrazit);
      expect(rinnenartikel(r, _belag, Rinnenlage.vorElement), _vAnthrazit);
      expect(rinnenartikel(_regelwerk([_v]), _belag, Rinnenlage.imElement), _v);
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

    test('F38: Belag endet 15,7 cm vor A — B, 14,0784 m²', () {
      final belag = rinnenstand(_f38, _belag, _regelwerk([_v]));
      expect(belag.grundriss.ecken, const [
        Punkt(0, 157),
        Punkt(4800, 157),
        Punkt(4800, 3090),
        Punkt(0, 3090),
      ]);
      expect(belag.kontur.flaeche / 1e6, closeTo(14.0784, 1e-9));
      expect(belag.anschluss, _f38.anschluss);
      // ohne Belag oder Artikel: unverändert
      expect(rinnenstand(_f38, null, _regelwerk([_v])), same(_f38));
      expect(rinnenstand(_f38, _belag, _regelwerk([])), same(_f38));
      expect(geplanteRinnen(_f38, null, _regelwerk([_v])), isEmpty);
      expect(belagstand(_f38, const []), same(_f38));
      // nicht mögliche Seite: kein Versatz
      final bogen = _f38.mitRundungen(
        Rundungen.keine.mitSeite(0, const Millimeter(100)),
      );
      expect(rinnenstand(bogen, _belag, _regelwerk([_v])), same(bogen));
    });

    test('zwei Rinnen an einer Ecke, im Uhrzeigersinn, gestreckte Ecke', () {
      final stand = Planungsstand.start
          .mitRinne(1, Rinnenlage.gesamteSeite)
          .mitRinne(2, Rinnenlage.gesamteSeite);
      expect(belagstand(stand, rinnenkanten(stand)).grundriss.ecken, [
        Punkt.ursprung,
        const Punkt(4643, 0),
        const Punkt(4643, 2933),
        const Punkt(0, 2933),
      ]);
      // umgekehrter Umlauf: innen liegt rechts
      final rechtsherum = freiform(const [
        Punkt(0, 0),
        Punkt(0, 3000),
        Punkt(4000, 3000),
        Punkt(4000, 0),
      ]).mitRinne(0, Rinnenlage.gesamteSeite);
      expect(
        belagstand(rechtsherum, rinnenkanten(rechtsherum)).grundriss.ecken,
        const [
          Punkt(157, 0),
          Punkt(157, 3000),
          Punkt(4000, 3000),
          Punkt(4000, 0),
        ],
      );
      // gestreckte Ecke: der Punkt wandert senkrecht mit
      final gestreckt = freiform(const [
        Punkt(0, 0),
        Punkt(2000, 0),
        Punkt(4000, 0),
        Punkt(4000, 3000),
        Punkt(0, 3000),
      ]).mitRinne(1, Rinnenlage.gesamteSeite);
      expect(
        belagstand(gestreckt, rinnenkanten(gestreckt)).grundriss.ecken,
        const [
          Punkt(0, 0),
          Punkt(2000, 157),
          Punkt(4000, 157),
          Punkt(4000, 3000),
          Punkt(0, 3000),
        ],
      );
    });

    test('schräge Nachbarseiten: die Ecken wandern auf ihnen mit', () {
      final trapez = freiform(const [
        Punkt(0, 0),
        Punkt(4000, 0),
        Punkt(3000, 2000),
        Punkt(1000, 2000),
      ]).mitRinne(2, Rinnenlage.gesamteSeite);
      final ecken = belagstand(trapez, rinnenkanten(trapez)).grundriss.ecken;
      expect(ecken.take(2), const [Punkt(0, 0), Punkt(4000, 0)]);
      expect(ecken[2].x, closeTo(3078.5, 1e-9));
      expect(ecken[2].y, closeTo(1843, 1e-9));
      expect(ecken[3].x, closeTo(921.5, 1e-9));
      expect(ecken[3].y, closeTo(1843, 1e-9));
    });

    test('zu schmal für die Rinne: Stand bleibt', () {
      // umgeklappt: zwei Rinnen in 30 cm
      final schmal =
          freiform(const [
                Punkt(0, 0),
                Punkt(1000, 0),
                Punkt(1000, 300),
                Punkt(0, 300),
              ])
              .mitRinne(0, Rinnenlage.gesamteSeite)
              .mitRinne(2, Rinnenlage.gesamteSeite);
      expect(belagstand(schmal, rinnenkanten(schmal)), same(schmal));
      // gekreuzt: die Nachbarseiten laufen vor der Rinne zusammen
      final spitz = freiform(const [
        Punkt(0, 0),
        Punkt(1000, 0),
        Punkt(600, 100),
        Punkt(400, 100),
      ]).mitRinne(0, Rinnenlage.gesamteSeite);
      expect(belagstand(spitz, rinnenkanten(spitz)), same(spitz));
    });
  });

  group('Artikel der Rinne (Regel 13.1.5)', () {
    test('eloxiert: Profil der Lage, Auflagerprofil aus dem Zubehör', () {
      expect(
        rinnensatz(
          _regelwerk([_v], zubehoer: [_e50, _va]),
          _belag,
          Rinnenlage.gesamteSeite,
          Rinnenfarbe.eloxiert,
        ),
        (profil: _v, auflagerprofil: _va),
      );
      // Pflichtzubehör zuerst
      expect(
        rinnensatz(
          _regelwerk([_v], zubehoer: [_va], pflicht: {_vaAnthrazit: 1}),
          _belag,
          Rinnenlage.gesamteSeite,
          Rinnenfarbe.eloxiert,
        )!.auflagerprofil,
        _vaAnthrazit,
      );
      expect(
        rinnensatz(
          _regelwerk([_v]),
          _belag,
          Rinnenlage.gesamteSeite,
          Rinnenfarbe.eloxiert,
        ),
        (profil: _v, auflagerprofil: null),
      );
      expect(
        rinnensatz(
          _regelwerk([]),
          _belag,
          Rinnenlage.gesamteSeite,
          Rinnenfarbe.eloxiert,
        ),
        isNull,
      );
    });

    test('anthrazit: Farbvariante aus dem Zubehör der Rinne', () {
      expect(
        rinnensatz(
          _regelwerk([_v], zubehoer: [_va, _vAnthrazit]),
          _belag,
          Rinnenlage.gesamteSeite,
          Rinnenfarbe.anthrazit,
        ),
        (profil: _vAnthrazit, auflagerprofil: _vaAnthrazit),
      );
      expect(
        rinnensatz(
          _regelwerk([_v], zubehoer: [_va]),
          _belag,
          Rinnenlage.gesamteSeite,
          Rinnenfarbe.anthrazit,
        ),
        isNull,
      );
    });

    test('Eckverbundwinkel: aus der UK, sonst aus dem Zubehör der Rinne', () {
      expect(
        eckwinkel(
          _regelwerk([_v], zubehoer: [_e50], ukEck: [_e25]),
          _v,
          _ukHolz,
        ),
        [_e25],
      );
      expect(
        eckwinkel(_regelwerk([_v], zubehoer: [_va, _e50, _e25]), _v, _ukHolz),
        [_e50, _e25],
      );
      expect(
        eckwinkel(
          _regelwerk([_v], zubehoer: [_e50], mitUk: false),
          _v,
          _ukHolz,
        ),
        [_e50],
      );
      expect(eckwinkel(_regelwerk([_v], zubehoer: [_e50]), _v, null), [_e50]);
      expect(eckwinkel(_regelwerk([_v]), _v, _ukHolz), isEmpty);
    });

    test('Farbe im Planungsstand und im Transportformat', () {
      final anthrazit = _f38.mitRinnenfarbe(Rinnenfarbe.anthrazit);
      expect(_f38.anschluss.rinnenfarbe, Rinnenfarbe.eloxiert);
      expect(anthrazit.anschluss.rinnenfarbe, Rinnenfarbe.anthrazit);
      expect(anthrazit == _f38, isFalse);
      expect(anthrazit.anschluss.hashCode == _f38.anschluss.hashCode, isFalse);
      expect(Planungsstand.ausBytes(anthrazit.zuBytes()), anthrazit);
      // andere Rollen behalten die Farbe
      expect(
        anthrazit
            .mitVerblendet(1, an: true)
            .mitBlendenhoehe(1, const Millimeter(100))
            .anschluss
            .rinnenfarbe,
        Rinnenfarbe.anthrazit,
      );
      expect(anthrazit.mitRinnenfarbe(Rinnenfarbe.eloxiert), _f38);
      for (final f in Rinnenfarbe.values) {
        expect(Rinnenfarbe.ausNummer(f.nummer), f);
      }
      expect([for (final f in Rinnenfarbe.values) f.nummer], [0, 1]);
      expect(() => Rinnenfarbe.ausNummer(2), throwsFormatException);
    });
  });

  group('Rinnenbedarf (Regel 13.1.5, R-D11)', () {
    Planungsstand breit(double laenge) => Planungsstand.start
        .mitGrundriss(
          FreiformGrundriss([
            Punkt.ursprung,
            Punkt(laenge, 0),
            Punkt(laenge, 3000),
            const Punkt(0, 3000),
          ], geschlossen: true),
        )
        .mitRinne(0, Rinnenlage.gesamteSeite);

    test('F38: 4 Profile, 6 Auflagerprofile, Hinweis zur Montage', () {
      final b = rinnenbedarf(
        _f38,
        belag: _belag,
        regelwerk: _regelwerk([_v], zubehoer: [_va]),
      );
      expect(_anzahl(b, _v), 4);
      expect(_anzahl(b, _va), 6);
      expect(b.meldungen, [Anschlussmeldung.rinnenmontage]);
      expect(b.stuecke, isEmpty);
      // verpackt: 1 Karton à 10 Profile, 1 Karton à 14 Auflagerprofile
      final liste = Materialliste.aus(b.bedarf);
      expect(
        [for (final p in liste.positionen) (p.nummer, p.anzahl)],
        [(_v.nummer, 1), (_va.nummer, 1)],
      );
    });

    test('Profile je 1,20 m und Auflagerprofile 2 × Länge / 1,88 m', () {
      final r = _regelwerk([_v], zubehoer: [_va]);
      int profile(double l) =>
          _anzahl(rinnenbedarf(breit(l), belag: _belag, regelwerk: r), _v);
      int auflager(double l) =>
          _anzahl(rinnenbedarf(breit(l), belag: _belag, regelwerk: r), _va);
      expect([profile(3600), profile(3601), profile(1200)], [3, 4, 1]);
      expect([auflager(940), auflager(941), auflager(1880)], [1, 2, 2]);
    });

    test('Eckverbundwinkel: 2 je Stützholz, sonst Hinweis', () {
      final b = rinnenbedarf(
        _f38.mitRinne(1, Rinnenlage.gesamteSeite),
        belag: _belag,
        regelwerk: _regelwerk([_v], zubehoer: [_va], ukEck: [_e50, _e25]),
        uk: _ukHolz,
        stuetzhoelzer: 9,
      );
      final winkel = b.bedarf.last;
      expect(winkel.einheiten, [_e50, _e25]);
      expect(winkel.stueck, 18);
      // zwei Rinnen: 4 + 3 Profile
      expect(_anzahl(b, _v), 7);
      expect(b.meldungen, [Anschlussmeldung.rinnenmontage]);
      final ohne = rinnenbedarf(
        _f38,
        belag: _belag,
        regelwerk: _regelwerk([_v]),
        uk: _ukHolz,
        stuetzhoelzer: 1,
      );
      expect(ohne.meldungen, [
        Anschlussmeldung.rinnenmontage,
        Anschlussmeldung.eckwinkelFehlt,
      ]);
      // ohne Auflagerprofil nur die Profile
      expect([for (final m in ohne.bedarf) m.einheiten.single], [_v]);
    });

    test('Farbe fehlt, Seite nicht möglich, ohne Artikel oder Belag', () {
      final anthrazit = rinnenbedarf(
        _f38.mitRinnenfarbe(Rinnenfarbe.anthrazit),
        belag: _belag,
        regelwerk: _regelwerk([_v], zubehoer: [_va]),
      );
      expect(anthrazit.bedarf, isEmpty);
      expect(anthrazit.meldungen, [
        Anschlussmeldung.rinnenfarbeFehlt,
        Anschlussmeldung.rinnenmontage,
      ]);
      final bogen = rinnenbedarf(
        _f38.mitRundungen(Rundungen.keine.mitSeite(0, const Millimeter(100))),
        belag: _belag,
        regelwerk: _regelwerk([_v]),
      );
      expect(bogen.bedarf, isEmpty);
      expect(bogen.meldungen, [Anschlussmeldung.rinneNichtMoeglich]);
      for (final b in [
        rinnenbedarf(_f38, belag: _belag, regelwerk: _regelwerk([])),
        rinnenbedarf(_f38, regelwerk: _regelwerk([])),
      ]) {
        expect(b.bedarf, isEmpty);
        expect(b.meldungen, [Anschlussmeldung.ohneRinnenartikel]);
      }
      expect(rinnenbedarf(Planungsstand.start).meldungen, isEmpty);
      expect(
        Anschlussmeldung.ausNummer(8),
        Anschlussmeldung.rinneNichtMoeglich,
      );
      expect(Anschlussmeldung.ausNummer(9), Anschlussmeldung.rinnenfarbeFehlt);
      expect(Anschlussmeldung.ausNummer(10), Anschlussmeldung.rinnenmontage);
      expect(Anschlussmeldung.ausNummer(11), Anschlussmeldung.eckwinkelFehlt);
    });

    test('Stützhölzer: erstes und letztes 5 cm vom Ende, höchstens 42 cm', () {
      expect(stuetzholzstellen(520), [50, 470]);
      final drei = stuetzholzstellen(521);
      expect(drei, hasLength(3));
      expect(drei[1], closeTo(260.5, 1e-9));
      expect(stuetzholzstellen(300), [50, 250]);
      final f38 = stuetzholzstellen(3090);
      expect(f38, hasLength(9));
      expect(f38.last, closeTo(3040, 1e-9));
      expect(f38[1] - f38[0], closeTo(373.75, 1e-9));
      expect(stuetzholzstellen(60), [50, 50]);
    });

    test('Bedarfe zusammenführen', () {
      final a = Anschlussbedarf(
        meldungen: const [Anschlussmeldung.unterlueftung],
      );
      final b = Anschlussbedarf(
        bedarf: [
          Materialbedarf([_va], 1),
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

  group('UK an der Rinne (Regel 13.1.3/13.1.4, R-C19)', () {
    UkVerlegung verlegt(Planungsstand s) {
      final kanten = rinnenkanten(s);
      return ukVerlegung(
        s,
        _ukHolz,
        abstand: const Millimeter(400),
        belagstand: belagstand(s, kanten),
        rinnen: kanten,
      );
    }

    test('Rinne längs der Dielen: Linien laufen bis an die Kante', () {
      final v = verlegt(_f38);
      expect(v.linien, isNotEmpty);
      for (final l in v.linien) {
        expect(l.abschnitte, [(0.0, 3090.0)]);
      }
      expect(v.stuetzen, isEmpty);
      // ohne Rinnen endet die UK am Belag
      final nurBelag = ukVerlegung(
        _f38,
        _ukHolz,
        abstand: const Millimeter(400),
        belagstand: belagstand(_f38, rinnenkanten(_f38)),
      );
      expect(nurBelag.linien.first.abschnitte, [(157.0, 3090.0)]);
    });

    test('nur Linien an der Rinne laufen durch', () {
      // Kerbe: rechts liegt eine Kante auf Höhe der Belagkante
      final s = Planungsstand.start
          .mitGrundriss(
            FreiformGrundriss(const [
              Punkt(0, 0),
              Punkt(2000, 0),
              Punkt(2000, 600),
              Punkt(3000, 600),
              Punkt(3000, 157),
              Punkt(4000, 157),
              Punkt(4000, 3000),
              Punkt(0, 3000),
            ], geschlossen: true),
          )
          .mitRinne(0, Rinnenlage.gesamteSeite);
      final v = verlegt(s);
      final links = v.linien.where((l) => l.x < 2000);
      final rechts = v.linien.where((l) => l.x > 3000);
      expect(links, isNotEmpty);
      expect(rechts, isNotEmpty);
      for (final l in links) {
        expect(l.abschnitte.first.$1, 0);
      }
      for (final l in rechts) {
        expect(l.abschnitte.first.$1, 157);
      }
    });

    test('Rinne quer zu den Dielen: letzte UK am Belag, Stützhölzer', () {
      final v = verlegt(
        Planungsstand.start.mitRinne(1, Rinnenlage.gesamteSeite),
      );
      expect(v.lagen.last, closeTo(4623, 1e-9));
      expect(v.stuetzen, hasLength(9));
      final erste = v.stuetzen.first;
      expect(erste.von.x, closeTo(4643, 1e-9));
      expect(erste.bis.x, closeTo(4800, 1e-9));
      expect(erste.von.y, closeTo(50, 1e-9));
      expect(v.stuetzen.last.bis.y, closeTo(3040, 1e-9));
      expect(
        v.stuecke.where((s) => s.laenge == const Millimeter(157)),
        hasLength(9),
      );
      expect(
        v.laenge,
        closeTo(
          v.linien.fold(
                0.0,
                (s, l) => s + l.abschnitte.single.$2 - l.abschnitte.single.$1,
              ) +
              9 * 157,
          1e-6,
        ),
      );
      // Zeichnung: die Stützhölzer liegen unter den Hölzern
      expect(v.hoelzer.where((h) => h.von.x > 4640), hasLength(9));
    });

    test('Dielen diagonal: Stützhölzer quer zur Kante', () {
      final s = Planungsstand.start
          .mitVerlegerichtung(Verlegerichtung.diagonal45)
          .mitRinne(1, Rinnenlage.gesamteSeite);
      final v = verlegt(s);
      expect(v.stuetzen, hasLength(9));
      for (final h in v.stuetzen) {
        expect(h.von.abstand(h.bis), closeTo(157, 1e-9));
      }
    });
  });
}
