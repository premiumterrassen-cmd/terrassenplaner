import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

Lastergebnis _ergebnis(
  String name,
  Map<Vorgang, List<Duration>> zeiten, {
  Map<Vorgang, int> fehler = const {},
  Duration laufzeit = const Duration(seconds: 10),
}) => Lastergebnis(
  profil: Lastprofil(
    name: name,
    sitzungen: 1,
    dauer: laufzeit,
    schritte: zeiten.keys.toList(),
  ),
  laufzeit: laufzeit,
  zeiten: zeiten,
  fehler: fehler,
);

Szenarioergebnis _szenario(
  String name,
  List<Lastergebnis> ergebnisse, {
  double? speicher,
  double? kerne,
}) => Szenarioergebnis(
  Szenario(name, 'Test', [for (final e in ergebnisse) e.profil]),
  ergebnisse,
  speicherSpitzeMb: speicher,
  cpuKerne: kerne,
);

Map<String, Zielwert> _nachKennung(List<Zielwert> z) => {
  for (final w in z) w.kennung: w,
};

void main() {
  test(
    'Zielwert: höchstens oder mindestens, umgerechnet; ohne Messung nie',
    () {
      Zielwert z(
        double gemessen,
        double zielserver, {
        bool mindestens = false,
      }) => Zielwert(
        kennung: 'k',
        beschreibung: 'b',
        grenze: 10,
        einheit: 'ms',
        gemessen: gemessen,
        zielserver: zielserver,
        mindestens: mindestens,
      );
      expect(z(5, 10).erreicht, isTrue);
      expect(z(5, 10.1).erreicht, isFalse);
      expect(z(5, 10, mindestens: true).erreicht, isTrue);
      expect(z(5, 11, mindestens: true).erreicht, isTrue);
      expect(z(5, 9.9, mindestens: true).erreicht, isFalse);
      expect(z(-1, -1).erreicht, isFalse);
      expect(z(0, 0).erreicht, isTrue);
      expect(z(5, 10).alsJson(), {
        'kennung': 'k',
        'beschreibung': 'b',
        'grenze': 10.0,
        'einheit': 'ms',
        'gemessen': 5.0,
        'zielserver': 10.0,
        'erreicht': true,
      });
      expect(Zielwerte.faktor, 2);
      expect(Zielwerte.speicherMb, 1024);
    },
  );

  test('nutzer: Fehler, Speicher, p95 und CPU (Faktor 2)', () {
    final z = _nachKennung(
      Zielwerte.pruefe([
        _szenario(
          'nutzer',
          [
            _ergebnis('nutzer', {
              Vorgang.berechnen: [_ms(100), _ms(125)],
              Vorgang.speichern: [_ms(126)],
              Vorgang.laden: [_ms(50)],
            }),
          ],
          speicher: 80,
          kerne: 0.5,
        ),
      ]),
    );
    expect(z.keys, [
      'nutzer.fehler',
      'nutzer.speicher',
      'nutzer.berechnen',
      'nutzer.speichern',
      'nutzer.laden',
      'nutzer.cpu',
    ]);
    expect(z['nutzer.fehler']!.erreicht, isTrue);
    expect(z['nutzer.speicher']!.zielserver, 80);
    expect(z['nutzer.speicher']!.grenze, 1024);
    expect(z['nutzer.berechnen']!.gemessen, 125);
    expect(z['nutzer.berechnen']!.zielserver, 250);
    expect(z['nutzer.berechnen']!.erreicht, isTrue);
    expect(z['nutzer.berechnen']!.beschreibung, 'p95 berechnen');
    expect(z['nutzer.speichern']!.erreicht, isFalse);
    expect(z['nutzer.laden']!.zielserver, 100);
    expect(z['nutzer.berechnen']!.grenze, 250);
    expect(z['nutzer.speichern']!.grenze, 250);
    expect(z['nutzer.laden']!.grenze, 250);
    expect(z['nutzer.cpu']!.zielserver, 1);
    expect(z['nutzer.cpu']!.erreicht, isTrue);
  });

  test('ohne Messung des Servers keine Speicher- und CPU-Werte', () {
    final z = Zielwerte.pruefe([
      _szenario('nutzer', [
        _ergebnis('nutzer', {
          Vorgang.berechnen: [_ms(1)],
        }),
      ]),
    ]);
    expect(z.map((w) => w.kennung), [
      'nutzer.fehler',
      'nutzer.berechnen',
      'nutzer.speichern',
      'nutzer.laden',
    ]);
    // ohne erfolgreiche Aufrufe ist ein Zeit-Zielwert verfehlt
    expect(z[2].gemessen, -1);
    expect(z[2].zielserver, -1);
    expect(z[2].erreicht, isFalse);
    expect(z[3].erreicht, isFalse);
  });

  test('Fehler zählen über alle Profile', () {
    final z = Zielwerte.pruefe([
      _szenario('gross', [
        _ergebnis(
          'gross',
          {
            Vorgang.berechnenGross: [_ms(1000)],
          },
          fehler: {Vorgang.berechnenGross: 1},
        ),
        _ergebnis(
          'nebenher',
          {
            Vorgang.berechnen: [_ms(200)],
            Vorgang.speichern: [_ms(300)],
          },
          fehler: {Vorgang.speichern: 2},
        ),
      ]),
    ]);
    final k = _nachKennung(z);
    expect(k['gross.fehler']!.gemessen, 3);
    expect(k['gross.fehler']!.erreicht, isFalse);
    expect(k['gross.berechnenGross']!.zielserver, 2000);
    expect(k['gross.berechnenGross']!.grenze, 5000);
    expect(k['gross.nebenher.berechnen']!.zielserver, 400);
    expect(k['gross.nebenher.berechnen']!.grenze, 500);
    expect(k['gross.nebenher.speichern']!.zielserver, 600);
    expect(k['gross.nebenher.speichern']!.erreicht, isFalse);
  });

  test('sitzungen und durchsatz', () {
    final k = _nachKennung(
      Zielwerte.pruefe([
        _szenario('sitzungen', [
          _ergebnis('sitzungen', {
            Vorgang.berechnen: [_ms(250)],
            Vorgang.speichern: [_ms(251)],
          }),
        ]),
        _szenario('durchsatz', [
          _ergebnis('durchsatz', {
            Vorgang.hallo: [for (var i = 0; i < 40000; i++) _ms(50)],
          }),
        ]),
        _szenario('unbekannt', [
          _ergebnis('x', {
            Vorgang.hallo: [_ms(1)],
          }),
        ]),
      ]),
    );
    expect(k['sitzungen.berechnen']!.erreicht, isTrue);
    expect(k['sitzungen.berechnen']!.grenze, 500);
    expect(k['sitzungen.speichern']!.erreicht, isFalse);
    expect(k['durchsatz.aufrufe']!.gemessen, 4000);
    expect(k['durchsatz.aufrufe']!.zielserver, 2000);
    expect(k['durchsatz.aufrufe']!.erreicht, isTrue);
    expect(k['durchsatz.aufrufe']!.einheit, '1/s');
    expect(k['durchsatz.hallo']!.zielserver, 100);
    expect(k['durchsatz.hallo']!.erreicht, isTrue);
    expect(k.keys.where((n) => n.startsWith('unbekannt')), [
      'unbekannt.fehler',
    ]);
  });
}
