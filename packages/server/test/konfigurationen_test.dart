import 'dart:io';
import 'dart:typed_data';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

Uint8List _inhalt(int laenge) => Planung([
  Terrassenflaeche(
    Planungsstand(
      grundriss: RechteckGrundriss(Millimeter(laenge), const Millimeter(3000)),
    ),
  ),
]).zuBytes();

/// Kennung aus `JJJJ-MM-TT-NNNN-XXXXX`.
Konfigurationskennung _kennung(String text) => Konfigurationskennung.lies(text);

KonfigurationsStand _stand(String kennung, int version) =>
    KonfigurationsStand(_kennung(kennung), version);

void main() {
  late Directory ordner;
  late Datenbank db;
  late Konfigurationsablage ablage;
  late ZaehlZufall zufall;
  var jetzt = DateTime(2026, 11, 4, 9, 30);

  setUp(() {
    ordner = Directory.systemTemp.createTempSync('planer-konfig-');
    jetzt = DateTime(2026, 11, 4, 9, 30);
    db = Datenbank.oeffne('${ordner.path}/daten', knoten: 'k1');
    zufall = ZaehlZufall();
    ablage = Konfigurationsablage(db, uhr: () => jetzt, zufall: zufall);
  });

  tearDown(() {
    db.schliesse();
    ordner.deleteSync(recursive: true);
  });

  group('speichern', () {
    test('erstes Speichern: neue Nummer des Tages, Version 1', () {
      final stand = ablage.speichere(_inhalt(4000));
      expect(stand, _stand('2026-11-04-0001-ABCDE', 1));
      expect(ablage.lies(stand), _inhalt(4000));
      expect(zufall.grenzen, {Pruefcode.alphabet.length});

      final kopf = db.store.box<Konfiguration>().getAll().single;
      expect(kopf.nummer, '2026-11-04-0001');
      expect(kopf.partition, '2026-11-04-0001');
      expect(kopf.tag, '2026-11-04');
      expect(kopf.laufend, 1);
      expect(kopf.aktuelleVersion, 1);
      expect(kopf.pruefcode, 'ABCDE');
      expect(kopf.schema, 1);
      expect(UuidV7.zeitstempel(kopf.uid), isPositive);
      final version = db.store.box<KonfigurationsVersion>().getAll().single;
      expect(version.schluessel, '2026-11-04-0001/1');
      expect(version.partition, '2026-11-04-0001');
      expect(version.nummer, '2026-11-04-0001');
      expect(version.version, 1);
      expect(version.knoten, 'k1');
      expect(kopf.erstelltAm, version.hlc);

      // Version und Kopf in derselben Transaktion protokolliert
      expect(
        [
          for (final a in db.aenderungenSeit(0))
            (a.entitaet, a.art, a.partition),
        ],
        [
          ('KonfigurationsVersion', 'anlegen', '2026-11-04-0001'),
          ('Konfiguration', 'anlegen', '2026-11-04-0001'),
        ],
      );
    });

    test('jede Nummer bekommt ihren eigenen Prüfcode', () {
      expect(
        ablage.speichere(_inhalt(1000)).kennung.wert,
        '2026-11-04-0001-ABCDE',
      );
      expect(
        ablage.speichere(_inhalt(1000)).kennung.wert,
        '2026-11-04-0002-FGHJK',
      );
    });

    test('laufende Nummer je Tag, neuer Tag beginnt bei 1', () {
      expect(ablage.speichere(_inhalt(1000)).nummer.wert, '2026-11-04-0001');
      expect(ablage.speichere(_inhalt(1000)).nummer.wert, '2026-11-04-0002');
      jetzt = DateTime(2026, 11, 3, 23, 59);
      expect(ablage.speichere(_inhalt(1000)).nummer.wert, '2026-11-03-0001');
      jetzt = DateTime(2026, 11, 4, 23, 59);
      expect(ablage.speichere(_inhalt(1000)).nummer.wert, '2026-11-04-0003');
      jetzt = DateTime(2026, 11, 5);
      expect(ablage.speichere(_inhalt(1000)).nummer.wert, '2026-11-05-0001');
    });

    test('weiteres Speichern: nächste Version, alte bleiben unverändert', () {
      final v1 = ablage.speichere(_inhalt(4000));
      final v2 = ablage.speichere(_inhalt(5000), kennung: v1.kennung);
      final v3 = ablage.speichere(_inhalt(6000), kennung: v1.kennung);
      expect(v2, _stand('2026-11-04-0001-ABCDE', 2));
      expect(v3, _stand('2026-11-04-0001-ABCDE', 3));
      expect(ablage.lies(v1), _inhalt(4000));
      expect(ablage.lies(v2), _inhalt(5000));
      expect(ablage.lies(v3), _inhalt(6000));
      final kopf = db.store.box<Konfiguration>().getAll().single;
      expect(kopf.aktuelleVersion, 3);
      expect(kopf.pruefcode, 'ABCDE');
      expect(kopf.erstelltAm, isNot(kopf.hlc));
      expect(db.store.box<KonfigurationsVersion>().count(), 3);
      expect(db.aenderungenSeit(2).map((a) => (a.entitaet, a.art)), [
        ('KonfigurationsVersion', 'anlegen'),
        ('Konfiguration', 'aendern'),
        ('KonfigurationsVersion', 'anlegen'),
        ('Konfiguration', 'aendern'),
      ]);
    });

    test('unveränderte Planung: keine neue Version', () {
      final v1 = ablage.speichere(_inhalt(4000));
      final seq = db.letzteSequenz;
      expect(ablage.speichere(_inhalt(4000), kennung: v1.kennung), v1);
      expect(db.letzteSequenz, seq);
      final v2 = ablage.speichere(_inhalt(4001), kennung: v1.kennung);
      expect(v2.version, 2);
      // gleich lang, anderer Inhalt – und wieder gleich
      final kuerzer = Uint8List.fromList(_inhalt(4002));
      expect(ablage.speichere(kuerzer, kennung: v1.kennung).version, 3);
      expect(ablage.speichere(_inhalt(4002), kennung: v1.kennung).version, 3);
    });

    test('unbekannte Nummer oder falscher Prüfcode: nichts gespeichert', () {
      ablage.speichere(_inhalt(4000));
      final seq = db.letzteSequenz;
      for (final text in ['2026-11-04-0009-ABCDE', '2026-11-04-0001-ABCDF']) {
        final nummer = text.substring(0, 15);
        expect(
          () => ablage.speichere(_inhalt(5000), kennung: _kennung(text)),
          throwsA(
            isA<KonfigurationUnbekannt>()
                .having((e) => e.nummer.wert, 'nummer', nummer)
                .having((e) => e.version, 'version', isNull)
                .having((e) => '$e', 'text', 'Konfiguration $nummer unbekannt'),
          ),
          reason: text,
        );
      }
      expect(db.letzteSequenz, seq);
    });

    test('Tag voll: Fehler, nichts gespeichert', () {
      db.speichere(
        Konfiguration(
          nummer: '2026-11-04-9999',
          tag: '2026-11-04',
          laufend: 9999,
        ),
      );
      expect(() => ablage.speichere(_inhalt(1000)), throwsRangeError);
      expect(db.store.box<KonfigurationsVersion>().count(), 0);
      expect(db.letzteSequenz, 1);
    });
  });

  group('laden', () {
    test('unbekannte Nummer oder Version', () {
      final v1 = ablage.speichere(_inhalt(4000));
      for (final stand in [
        _stand('2026-11-04-0001-ABCDE', 2),
        _stand('2026-11-04-0002-ABCDE', 1),
        // falscher Prüfcode: wie unbekannt
        _stand('2026-11-04-0001-ABCDF', 1),
        _stand('2026-11-04-0001-FGHJK', 1),
      ]) {
        expect(
          () => ablage.lies(stand),
          throwsA(
            isA<KonfigurationUnbekannt>()
                .having((e) => e.nummer, 'nummer', stand.nummer)
                .having((e) => e.version, 'version', stand.version)
                .having(
                  (e) => '$e',
                  'text',
                  'Konfiguration ${stand.nummer.wert} Version '
                      '${stand.version} unbekannt',
                ),
          ),
        );
      }
      expect(ablage.lies(v1), isNotEmpty);
    });

    test('Kennung zur Nummer (für Mitarbeiter, M9-10)', () {
      final v1 = ablage.speichere(_inhalt(4000));
      expect(ablage.kennung(v1.nummer), v1.kennung);
      expect(
        () => ablage.kennung(const Konfigurationsnummer('2026-11-04-0002')),
        throwsA(
          isA<KonfigurationUnbekannt>()
              .having((e) => e.nummer.wert, 'nummer', '2026-11-04-0002')
              .having((e) => e.version, 'version', isNull),
        ),
      );
      ablage.speichere(_inhalt(5000));
      expect(
        ablage.kennung(const Konfigurationsnummer('2026-11-04-0002')).wert,
        '2026-11-04-0002-FGHJK',
      );
    });

    test('Grabsteine gelten als unbekannt', () {
      final v1 = ablage.speichere(_inhalt(4000));
      db.loesche(db.store.box<KonfigurationsVersion>().getAll().single);
      expect(() => ablage.lies(v1), throwsA(isA<KonfigurationUnbekannt>()));
      db.loesche(db.store.box<Konfiguration>().getAll().single);
      expect(
        () => ablage.speichere(_inhalt(1000), kennung: v1.kennung),
        throwsA(isA<KonfigurationUnbekannt>()),
      );
      expect(
        () => ablage.kennung(v1.nummer),
        throwsA(isA<KonfigurationUnbekannt>()),
      );
    });
  });

  group('Entwurf', () {
    const schluessel = '0123456789abcdef0123456789abcdef';

    test('ohne Entwurf: null', () {
      expect(ablage.entwurf(schluessel), isNull);
    });

    test('merken, überschreiben, Bezug, Frist', () {
      final v1 = ablage.speichere(_inhalt(1000));
      ablage.speichere(_inhalt(2000), kennung: v1.kennung);
      final seq = db.letzteSequenz;
      ablage.merkeEntwurf(schluessel, _inhalt(4000));
      final e = ablage.entwurf(schluessel)!;
      expect(e.inhalt, _inhalt(4000));
      expect(e.bezug, isNull);
      final z = db.store.box<Zwischenstand>().getAll().single;
      expect(z.partition, schluessel);
      expect(z.schema, 1);
      expect(
        z.ablaufAm,
        jetzt.add(const Duration(days: 30)).millisecondsSinceEpoch,
      );

      jetzt = jetzt.add(const Duration(days: 1));
      final bezug = _stand('2026-11-04-0001-ABCDE', 2);
      ablage.merkeEntwurf(schluessel, _inhalt(5000), bezug: bezug);
      expect(db.store.box<Zwischenstand>().count(), 1);
      final neu = ablage.entwurf(schluessel)!;
      expect(neu.inhalt, _inhalt(5000));
      // mit Prüfcode zurück
      expect(neu.bezug, bezug);
      expect(db.aenderungenSeit(seq).map((a) => (a.entitaet, a.art)), [
        ('Zwischenstand', 'anlegen'),
        ('Zwischenstand', 'aendern'),
      ]);

      // Frist: bis knapp davor da, danach weg
      jetzt = jetzt.add(
        Konfigurationsablage.standardFrist - const Duration(milliseconds: 1),
      );
      expect(ablage.entwurf(schluessel), isNotNull);
      jetzt = jetzt.add(const Duration(milliseconds: 1));
      expect(ablage.entwurf(schluessel), isNull);
      jetzt = jetzt.add(const Duration(days: 1));
      expect(ablage.entwurf(schluessel), isNull);
      expect(ablage.entwurf('ffffffffffffffffffffffffffffffff'), isNull);
    });

    test('unverändert: kein Schreiben; Bezug oder Inhalt neu: Schreiben', () {
      ablage
        ..speichere(_inhalt(1000))
        ..speichere(_inhalt(2000));
      final seq = db.letzteSequenz;
      final bezug = _stand('2026-11-04-0001-ABCDE', 1);
      ablage
        ..merkeEntwurf(schluessel, _inhalt(4000), bezug: bezug)
        ..merkeEntwurf(schluessel, _inhalt(4000), bezug: bezug);
      expect(db.letzteSequenz, seq + 1);
      ablage.merkeEntwurf(
        schluessel,
        _inhalt(4000),
        bezug: _stand('2026-11-04-0001-ABCDE', 2),
      );
      expect(db.letzteSequenz, seq + 2);
      ablage.merkeEntwurf(
        schluessel,
        _inhalt(4000),
        bezug: _stand('2026-11-04-0002-FGHJK', 2),
      );
      expect(db.letzteSequenz, seq + 3);
      expect(
        ablage.entwurf(schluessel)!.bezug,
        _stand('2026-11-04-0002-FGHJK', 2),
      );
      ablage.merkeEntwurf(schluessel, _inhalt(4000));
      expect(db.letzteSequenz, seq + 4);
      expect(ablage.entwurf(schluessel)!.bezug, isNull);
      ablage.merkeEntwurf(schluessel, _inhalt(4001));
      expect(db.letzteSequenz, seq + 5);
    });

    test('Bezug mit falschem Prüfcode oder unbekannter Nummer: Fehler', () {
      ablage.speichere(_inhalt(1000));
      final seq = db.letzteSequenz;
      for (final stand in [
        _stand('2026-11-04-0001-FGHJK', 1),
        _stand('2026-11-04-0002-ABCDE', 1),
      ]) {
        expect(
          () => ablage.merkeEntwurf(schluessel, _inhalt(4000), bezug: stand),
          throwsA(
            isA<KonfigurationUnbekannt>()
                .having((e) => e.nummer, 'nummer', stand.nummer)
                .having((e) => e.version, 'version', 1),
          ),
        );
      }
      expect(db.letzteSequenz, seq);
      expect(ablage.entwurf(schluessel), isNull);
    });

    test('Bezug auf eine inzwischen gelöschte Konfiguration: ohne Bezug', () {
      final v1 = ablage.speichere(_inhalt(1000));
      ablage.merkeEntwurf(schluessel, _inhalt(4000), bezug: v1);
      db.loesche(db.store.box<Konfiguration>().getAll().single);
      final e = ablage.entwurf(schluessel)!;
      expect(e.inhalt, _inhalt(4000));
      expect(e.bezug, isNull);
    });

    test('eigene Frist; Grabstein gilt als kein Entwurf', () {
      final kurz = Konfigurationsablage(
        db,
        uhr: () => jetzt,
        entwurfFrist: const Duration(hours: 1),
      );
      expect(kurz.entwurfFrist, const Duration(hours: 1));
      kurz.merkeEntwurf(schluessel, _inhalt(4000));
      jetzt = jetzt.add(const Duration(hours: 1));
      expect(kurz.entwurf(schluessel), isNull);
      jetzt = jetzt.subtract(const Duration(minutes: 1));
      expect(kurz.entwurf(schluessel), isNotNull);
      db.loesche(db.store.box<Zwischenstand>().getAll().single);
      expect(kurz.entwurf(schluessel), isNull);
    });
  });

  test('ohne Uhr und Zufall: aktuelle Ortszeit, sicherer Prüfcode', () {
    final standard = Konfigurationsablage(db);
    expect(standard.entwurfFrist, Konfigurationsablage.standardFrist);
    expect(Konfigurationsablage.standardFrist, const Duration(days: 30));
    final stand = standard.speichere(_inhalt(1000));
    expect(stand.nummer.tag, Konfigurationsnummer.tagAus(DateTime.now()));
    final code = stand.kennung.pruefcode;
    expect(Pruefcode.pruefe(code.wert), code);
    expect(standard.lies(stand), _inhalt(1000));
  });
}
