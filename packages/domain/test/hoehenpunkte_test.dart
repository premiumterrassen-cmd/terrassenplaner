import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

List<Millimeter> _mm(List<int> werte) => [for (final w in werte) Millimeter(w)];

const _uk40x60 = (a: Millimeter(40), b: Millimeter(60));

/// „… 40 x 60 mm …“ aus einem Artikeltitel der Planungsunterlagen.
UkMasse? _masse(String? titel) {
  final treffer = RegExp(r'(\d+) x (\d+) mm').firstMatch(titel ?? '');
  if (treffer == null) return null;
  return (
    a: Millimeter(int.parse(treffer[1]!)),
    b: Millimeter(int.parse(treffer[2]!)),
  );
}

/// Planungsstand im Transportformat mit einzelnen Feldern aus M6-02.
Uint8List _alt({bool? gefaelle, int? hoehe, List<int>? eckhoehen}) {
  final fbb = fb.Builder();
  final masseOrt = fbb.writeListInt32([4800, 3090]);
  fbb
    ..startTable(2)
    ..addUint8(0, 0)
    ..addOffset(1, masseOrt);
  final ort = fbb.endTable();
  final eckenOrt = eckhoehen == null ? null : fbb.writeListInt32(eckhoehen);
  fbb
    ..startTable(25)
    ..addOffset(1, ort)
    ..addBool(22, gefaelle)
    ..addInt32(23, hoehe)
    ..addOffset(24, eckenOrt);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

void main() {
  group('pruefeHoehen (M6-02)', () {
    test('Aufbauhöhe: Belag plus UK hochkant; darüber unverändert', () {
      final p = pruefeHoehen(
        _mm([86, 150, 86, 150]),
        art: Terrassenart.normal,
        dielenstaerke: const Millimeter(23),
        uk: _uk40x60,
      );
      expect(p.hoehen, _mm([86, 150, 86, 150]));
      expect(p.aufbauhoehe, const Millimeter(83));
      expect(p.mindesthoehe, const Millimeter(63));
      expect(p.korrigiert, isFalse);
      expect(p.gedreht, isFalse);
      expect(() => p.hoehen.add(const Millimeter(1)), throwsUnsupportedError);
      // genau auf der Aufbauhöhe: noch hochkant
      final genau = pruefeHoehen(
        _mm([83]),
        art: Terrassenart.normal,
        dielenstaerke: const Millimeter(23),
        uk: (a: const Millimeter(60), b: const Millimeter(40)),
      );
      expect(genau.gedreht, isFalse);
      expect(genau.aufbauhoehe, const Millimeter(83));
    });

    test('darunter wird die UK gedreht (B-034), noch tiefer korrigiert', () {
      final gedreht = pruefeHoehen(
        _mm([86, 82]),
        art: Terrassenart.normal,
        dielenstaerke: const Millimeter(23),
        uk: _uk40x60,
      );
      expect(gedreht.gedreht, isTrue);
      expect(gedreht.korrigiert, isFalse);
      expect(gedreht.aufbauhoehe, const Millimeter(63));
      expect(gedreht.hoehen, _mm([86, 82]));
      final genau = pruefeHoehen(
        _mm([63]),
        art: Terrassenart.normal,
        dielenstaerke: const Millimeter(23),
        uk: _uk40x60,
      );
      expect(genau.korrigiert, isFalse);
      expect(genau.hoehen, _mm([63]));
      final korrigiert = pruefeHoehen(
        _mm([100, 50, 62]),
        art: Terrassenart.normal,
        dielenstaerke: const Millimeter(23),
        uk: _uk40x60,
      );
      expect(korrigiert.korrigiert, isTrue);
      expect(korrigiert.gedreht, isTrue);
      expect(korrigiert.hoehen, _mm([100, 63, 63]));
      expect(korrigiert.mindesthoehe, const Millimeter(63));
    });

    test('quadratische UK lässt sich nicht drehen', () {
      final p = pruefeHoehen(
        _mm([50]),
        art: Terrassenart.normal,
        dielenstaerke: const Millimeter(21),
        uk: (a: const Millimeter(40), b: const Millimeter(40)),
      );
      expect(p.gedreht, isFalse);
      expect(p.korrigiert, isTrue);
      expect(p.hoehen, _mm([61]));
      expect(p.aufbauhoehe, const Millimeter(61));
    });

    test('Hochterrasse: zwei Lagen UK (Lattenkreuz)', () {
      expect(Terrassenart.hochterrasse.ukLagen, 2);
      expect(Terrassenart.normal.ukLagen, 1);
      expect(Terrassenart.vorhandeneUk.ukLagen, 1);
      final p = pruefeHoehen(
        _mm([542]),
        art: Terrassenart.hochterrasse,
        dielenstaerke: const Millimeter(23),
        uk: _uk40x60,
      );
      expect(p.aufbauhoehe, const Millimeter(143));
      expect(p.mindesthoehe, const Millimeter(103));
      final tief = pruefeHoehen(
        _mm([120]),
        art: Terrassenart.hochterrasse,
        dielenstaerke: const Millimeter(23),
        uk: _uk40x60,
      );
      expect(tief.gedreht, isTrue);
      expect(tief.aufbauhoehe, const Millimeter(103));
    });

    test('ohne Dielenstärke oder UK-Maße ungeprüft', () {
      for (final p in [
        pruefeHoehen(_mm([10]), art: Terrassenart.normal, uk: _uk40x60),
        pruefeHoehen(
          _mm([10]),
          art: Terrassenart.normal,
          dielenstaerke: const Millimeter(23),
        ),
      ]) {
        expect(p.hoehen, _mm([10]));
        expect(p.aufbauhoehe, isNull);
        expect(p.mindesthoehe, isNull);
        expect(p.korrigiert, isFalse);
        expect(p.gedreht, isFalse);
      }
      expect(Hoehenpunkte.keine.hoehen, isEmpty);
    });

    test('Abnahme: Höhen an den Eckpunkten wie in den Planungsunterlagen '
        '(M1-02)', () {
      final faelle = [
        for (final f in Directory('test/referenzfaelle').listSync())
          if (f is File && f.path.endsWith('.json'))
            Referenzfall.ausJson(
              jsonDecode(f.readAsStringSync()) as Map<String, Object?>,
            ),
      ];
      var geprueft = 0;
      for (final fall in faelle) {
        final hoehen = fall.aufbauhoehenCm;
        if (hoehen == null || hoehen.isEmpty) continue;
        final namen = fall.grundriss.eckpunkte.cast<String>();
        final eingabe = [for (final n in namen) Millimeter.ausCm(hoehen[n]!)];
        final belag = _masse(fall.belag);
        final p = pruefeHoehen(
          eingabe,
          art: Terrassenart.normal,
          // „60 x 22 mm“: Breite x Stärke
          dielenstaerke: belag?.b,
          uk: fall.unterkonstruktion?.contains('Robinie') ?? false
              ? _masse(fall.unterkonstruktion)
              : null,
        );
        expect(p.hoehen, eingabe, reason: fall.id);
        expect(p.korrigiert, isFalse, reason: fall.id);
        geprueft++;
      }
      expect(geprueft, 18);
    });

    test('F30: Gefälle A = B = 15, C = D = 8,6 cm bleibt, UK hochkant', () {
      final stand = Planungsstand.start
          .mitGefaelle(true)
          .mitEckhoehe(0, const Millimeter(150))
          .mitEckhoehe(1, const Millimeter(150));
      expect(stand.hoehen, _mm([150, 150, 86, 86]));
      final p = pruefeHoehen(
        stand.hoehen,
        art: stand.terrassenart,
        dielenstaerke: const Millimeter(21),
        uk: _uk40x60,
      );
      expect(p.hoehen, _mm([150, 150, 86, 86]));
      expect(p.gedreht, isFalse);
      expect(p.korrigiert, isFalse);
    });
  });

  group('Planungsstand mit Höhenpunkten (M6-02)', () {
    const start = Planungsstand.start;

    test('Vorgabe ohne Gefälle mit der Vorgabehöhe der Art', () {
      expect(start.gefaelle, isFalse);
      expect(start.hoehe, isNull);
      expect(start.eckhoehen, isEmpty);
      expect(start.alleHoehe, const Millimeter(86));
      expect(start.hoehen, _mm([86, 86, 86, 86]));
      expect(
        start.mitTerrassenart(Terrassenart.hochterrasse).hoehen,
        _mm([542, 542, 542, 542]),
      );
      // Kreis: nur A
      expect(start.mitForm(Terrassenform.kreis).hoehen, _mm([86]));
      expect(start.mitForm(Terrassenform.lForm).hoehen, hasLength(6));
    });

    test('Höhe „Alle“ und je Eckpunkt; Gefälle aus und an', () {
      final alle = start.mitHoehe(const Millimeter(120));
      expect(alle.hoehe, const Millimeter(120));
      expect(alle.hoehen, _mm([120, 120, 120, 120]));
      expect(alle == start, isFalse);
      expect(alle.hashCode == start.hashCode, isFalse);
      final mit = alle.mitGefaelle(true);
      expect(mit.hoehen, _mm([120, 120, 120, 120]));
      expect(mit == alle, isFalse);
      expect(mit.hashCode == alle.hashCode, isFalse);
      final c = mit.mitEckhoehe(2, const Millimeter(90));
      expect(c.eckhoehen, _mm([120, 120, 90, 120]));
      expect(c.hoehen, _mm([120, 120, 90, 120]));
      expect(c == mit, isFalse);
      expect(c.hashCode == mit.hashCode, isFalse);
      expect(
        () => c.eckhoehen.add(const Millimeter(1)),
        throwsUnsupportedError,
      );
      // ohne Gefälle wieder „Alle“, die Eckhöhen bleiben für später
      final ohne = c.mitGefaelle(false);
      expect(ohne.hoehen, _mm([120, 120, 120, 120]));
      expect(ohne.mitGefaelle(true).hoehen, _mm([120, 120, 90, 120]));
      // eine Eckhöhe ohne Gefälle schaltet es nicht ein
      final still = alle.mitEckhoehe(0, const Millimeter(200));
      expect(still.gefaelle, isFalse);
      expect(still.eckhoehen, _mm([200, 120, 120, 120]));
      expect(still.mitGefaelle(true).hoehen, _mm([200, 120, 120, 120]));
      // weniger Ecken nach einem Formwechsel: die überzähligen zählen nicht
      final kreis = c.mitForm(Terrassenform.kreis);
      expect(kreis.hoehen, _mm([120]));
      expect(kreis.mitEckhoehe(0, const Millimeter(99)).eckhoehen, _mm([99]));
    });

    test('Gleichheit über die einzelnen Eckhöhen', () {
      final a = start.mitGefaelle(true).mitEckhoehe(1, const Millimeter(100));
      final b = start.mitGefaelle(true).mitEckhoehe(1, const Millimeter(101));
      final c = start.mitGefaelle(true).mitEckhoehe(1, const Millimeter(100));
      expect(a == b, isFalse);
      expect(a, c);
      expect(a.hashCode, c.hashCode);
    });

    test('Grenzen: über 0 bis 300 cm, Ecke muss es geben', () {
      expect(Planungsstand.hoeheGueltig(const Millimeter(0)), isFalse);
      expect(Planungsstand.hoeheGueltig(const Millimeter(1)), isTrue);
      expect(Planungsstand.hoeheGueltig(const Millimeter(3000)), isTrue);
      expect(Planungsstand.hoeheGueltig(const Millimeter(3001)), isFalse);
      expect(
        () => start.mitHoehe(const Millimeter(0)),
        wirftArgumentFehler('hoehe', 0, 'muss 1 bis 3000 mm sein'),
      );
      expect(
        () => start.mitEckhoehe(0, const Millimeter(3001)),
        wirftArgumentFehler('hoehe', 3001, 'muss 1 bis 3000 mm sein'),
      );
      expect(
        start.mitEckhoehe(3, const Millimeter(1)).eckhoehen.last,
        const Millimeter(1),
      );
      expect(
        () => start.mitEckhoehe(4, const Millimeter(100)),
        throwsA(
          isA<RangeError>()
              .having((e) => e.name, 'name', 'ecke')
              .having((e) => e.end, 'end', 3),
        ),
      );
      expect(
        () => start.mitEckhoehe(-1, const Millimeter(100)),
        throwsRangeError,
      );
    });

    test(
      'Art wechseln: Höhen springen auf die Vorgabehöhe, Gefälle bleibt',
      () {
        final stand = start
            .mitGefaelle(true)
            .mitHoehe(const Millimeter(100))
            .mitEckhoehe(0, const Millimeter(130))
            .mitTerrassenart(Terrassenart.vorhandeneUk);
        expect(stand.gefaelle, isTrue);
        expect(stand.hoehe, isNull);
        expect(stand.eckhoehen, isEmpty);
        expect(stand.hoehen, _mm([142, 142, 142, 142]));
      },
    );

    test('bleiben bei den anderen Änderungen', () {
      final stand = start
          .mitHoehe(const Millimeter(111))
          .mitGefaelle(true)
          .mitEckhoehe(1, const Millimeter(99));
      for (final s in [
        stand.mitGrundriss(RechteckGrundriss.start),
        stand.mitBelag(const Artikelnummer('10-10-146')),
        stand.mitVerlegeart(Verlegeart.halbverband),
        stand.mitAusgangspunkt(ecke: 1),
        stand.mitBefestigungsart(Befestigungsart.verschraubt),
        stand.mitSpannweite(const Millimeter(500)),
      ]) {
        expect(s.hoehen, _mm([111, 99, 111, 111]));
      }
    });

    test('Transport hin und zurück; fehlende Felder sind die Vorgabe', () {
      final stand = start
          .mitHoehe(const Millimeter(111))
          .mitGefaelle(true)
          .mitEckhoehe(1, const Millimeter(99));
      expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      expect(Planungsstand.ausBytes(start.zuBytes()), start);
      expect(Planungsstand.ausBytes(_alt()), start);
      final gelesen = Planungsstand.ausBytes(
        _alt(gefaelle: true, hoehe: 70, eckhoehen: [80, 90]),
      );
      expect(gelesen.gefaelle, isTrue);
      expect(gelesen.hoehe, const Millimeter(70));
      expect(gelesen.hoehen, _mm([80, 90, 70, 70]));
      expect(
        () => gelesen.eckhoehen.add(const Millimeter(1)),
        throwsUnsupportedError,
      );
    });
  });

  group('Berechnung mit Höhenpunkten (M6-02)', () {
    test('hin und zurück, auch in der Kopie mit Gesamtfläche', () {
      final b = Berechnung(
        umriss: const [],
        flaeche: 1,
        hoehenpunkte: Hoehenpunkte(
          hoehen: _mm([150, 63]),
          aufbauhoehe: const Millimeter(63),
          mindesthoehe: const Millimeter(62),
          korrigiert: true,
          gedreht: true,
        ),
      );
      for (final k in [
        Berechnung.ausBytes(b.zuBytes()),
        b.mitGesamtflaeche(2),
      ]) {
        final p = k.hoehenpunkte;
        expect(p.hoehen, _mm([150, 63]));
        expect(p.aufbauhoehe, const Millimeter(63));
        expect(p.mindesthoehe, const Millimeter(62));
        expect(p.korrigiert, isTrue);
        expect(p.gedreht, isTrue);
      }
    });

    test('ohne Höhenpunkte: leer, ungeprüft', () {
      final b = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 1).zuBytes(),
      );
      final p = b.hoehenpunkte;
      expect(p.hoehen, isEmpty);
      expect(p.aufbauhoehe, isNull);
      expect(p.mindesthoehe, isNull);
      expect(p.korrigiert, isFalse);
      expect(p.gedreht, isFalse);
    });
  });
}
