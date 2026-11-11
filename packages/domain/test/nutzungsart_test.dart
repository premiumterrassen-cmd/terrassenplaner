import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Planungsstand im Transportformat vor M6-05 (bzw. nur mit Nutzungsart).
Uint8List _alt({int? nutzungsart}) {
  final fbb = fb.Builder();
  final masseOrt = fbb.writeListInt32([4800, 3090]);
  fbb
    ..startTable(2)
    ..addUint8(0, 0)
    ..addOffset(1, masseOrt);
  final ort = fbb.endTable();
  fbb
    ..startTable(82)
    ..addOffset(1, ort)
    ..addUint8(81, nutzungsart);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

/// UK-Holz Robinie 40 x 60 mm wie in F01 (Lieferlängen der Serie 4/5/6 m).
final _uk = Artikel(
  nummer: const Artikelnummer('10-10-031'),
  titel: 'UK 40 x 60',
  art: Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(40),
    staerke: const Millimeter(60),
    laengen: const [Millimeter(6000)],
  ),
  holzart: robinie,
  serie: basic,
);

const _abstand = Millimeter(400);

/// Lieferstücke je Länge in mm.
Map<int, int> _lieferung(Ukzusatz z) => {
  for (final b in z.bedarf) b.laenge!.mm: b.stueck,
};

/// Zuschnitte je Länge, Lage und Anzahl.
Map<(int, Stuecklage), int> _zuschnitte(Ukzusatz z) {
  final n = <(int, Stuecklage), int>{};
  for (final s in z.stuecke) {
    n.update((s.laenge.mm, s.lage), (a) => a + 1, ifAbsent: () => 1);
  }
  return n;
}

void main() {
  const f01 = Planungsstand.start;

  group('Nutzungsart (M6-05)', () {
    test('fünf Arten wie im alten Planer, Nummern 0 bis 4', () {
      expect([for (final a in Nutzungsart.values) a.nummer], [0, 1, 2, 3, 4]);
      expect(Nutzungsart.values.first, Nutzungsart.schwimmend);
    });

    test('Rahmen, Versteifung und Warnung zur Verwindung', () {
      expect(
        [for (final a in Nutzungsart.values) a.mitRahmen],
        [false, false, true, true, false],
      );
      expect(
        [for (final a in Nutzungsart.values) a.versteift],
        [false, true, false, true, false],
      );
      expect(
        [for (final a in Nutzungsart.values) a.verwindungsgefahr],
        [true, false, false, false, false],
      );
    });

    test('Nummer aus dem Transportformat', () {
      for (final a in Nutzungsart.values) {
        expect(Nutzungsart.ausNummer(a.nummer), a);
      }
      expect(
        () => Nutzungsart.ausNummer(5),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannte Nutzungsart 5',
          ),
        ),
      );
    });
  });

  group('Planungsstand mit Nutzungsart (M6-05)', () {
    test('Vorgabe schwimmende Verlegung (F01)', () {
      expect(f01.nutzungsart, Nutzungsart.schwimmend);
      expect(f01.wirksameNutzungsart, Nutzungsart.schwimmend);
      expect(f01.doppelteUk, isFalse);
    });

    test('ändern; Gleichheit und Hash; Wahl bleibt beim Wechsel der Art', () {
      final rahmen = f01.mitNutzungsart(Nutzungsart.rahmen);
      expect(rahmen.nutzungsart, Nutzungsart.rahmen);
      expect(rahmen == f01, isFalse);
      expect(rahmen.hashCode == f01.hashCode, isFalse);
      expect(rahmen.mitNutzungsart(Nutzungsart.schwimmend), f01);
      // bei Hochterrasse und vorhandener UK entfällt 3.6 (M6-01, F28, F29)
      final hoch = rahmen.mitTerrassenart(Terrassenart.hochterrasse);
      expect(hoch.nutzungsart, Nutzungsart.rahmen);
      expect(hoch.wirksameNutzungsart, isNull);
      expect(
        rahmen.mitTerrassenart(Terrassenart.vorhandeneUk).wirksameNutzungsart,
        isNull,
      );
      expect(
        hoch.mitTerrassenart(Terrassenart.normal).wirksameNutzungsart,
        Nutzungsart.rahmen,
      );
    });

    test('zwei UK-Lagen bei doppelter UK und Hochterrasse', () {
      expect(f01.mitNutzungsart(Nutzungsart.doppelteUk).doppelteUk, isTrue);
      expect(f01.mitTerrassenart(Terrassenart.hochterrasse).doppelteUk, isTrue);
      final vorhanden = f01
          .mitNutzungsart(Nutzungsart.doppelteUk)
          .mitTerrassenart(Terrassenart.vorhandeneUk);
      expect(vorhanden.doppelteUk, isFalse);
    });

    test('Transportformat: hin und zurück, abwärtskompatibel', () {
      for (final a in Nutzungsart.values) {
        final stand = f01.mitNutzungsart(a);
        expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      }
      expect(
        Planungsstand.ausBytes(_alt()).nutzungsart,
        Nutzungsart.schwimmend,
      );
      expect(
        Planungsstand.ausBytes(_alt(nutzungsart: 4)).nutzungsart,
        Nutzungsart.doppelteUk,
      );
      expect(
        () => Planungsstand.ausBytes(_alt(nutzungsart: 7)),
        throwsA(isA<FormatException>()),
      );
    });

    test('doppelte UK prüft die Höhen mit zwei Lagen (F34: 8,6 cm reicht '
        'nicht – der alte Planer prüfte das nicht)', () {
      final uk = (a: const Millimeter(40), b: const Millimeter(60));
      final eine = pruefeHoehen(
        const [Millimeter(86)],
        art: Terrassenart.normal,
        dielenstaerke: const Millimeter(21),
        uk: uk,
      );
      expect(eine.korrigiert, isFalse);
      final zwei = pruefeHoehen(
        const [Millimeter(86)],
        art: Terrassenart.normal,
        doppelteUk: true,
        dielenstaerke: const Millimeter(21),
        uk: uk,
      );
      expect(zwei.mindesthoehe, const Millimeter(101));
      expect(zwei.korrigiert, isTrue);
      expect(zwei.hoehen, const [Millimeter(101)]);
    });
  });

  group('zusätzliches UK-Holz (M6-05, Fachkonzept 3.6)', () {
    test('schwimmende Verlegung: keins (F01)', () {
      final z = ukZusatz(f01, _uk, ukAbstand: _abstand);
      expect(z, same(Ukzusatz.keiner));
      expect(z.stuecke, isEmpty);
      expect(z.bedarf, isEmpty);
      expect(z.streben, isEmpty);
    });

    test('Rahmen: zwei Hölzer à 480 cm → 2 × 5000 mm wie F32', () {
      final z = ukZusatz(
        f01.mitNutzungsart(Nutzungsart.rahmen),
        _uk,
        ukAbstand: _abstand,
      );
      expect(_zuschnitte(z), {(4800, Stuecklage.laengs): 2});
      expect(_lieferung(z), {5000: 2});
      expect(z.streben, isEmpty);
      expect(z.bedarf.first.einheiten, [_uk]);
      expect(z.stuecke.first.ganzeLaenge, const Millimeter(6000));
      expect(z.stuecke.first.farbe, Stueckfarbe.blau);
    });

    test('Rahmen bei senkrechter Verlegung: quer über 309 cm', () {
      final z = ukZusatz(
        f01
            .mitNutzungsart(Nutzungsart.rahmen)
            .mitVerlegerichtung(Verlegerichtung.senkrecht),
        _uk,
        ukAbstand: _abstand,
      );
      expect(_zuschnitte(z), {(3090, Stuecklage.laengs): 2});
      expect(_lieferung(z), {4000: 2});
    });

    test('doppelte UK: zweite Lage 9 × 480 cm → 9 × 5000 mm wie F34; '
        'Hochterrasse ebenso (F28)', () {
      for (final stand in [
        f01.mitNutzungsart(Nutzungsart.doppelteUk),
        f01.mitTerrassenart(Terrassenart.hochterrasse),
      ]) {
        final z = ukZusatz(stand, _uk, ukAbstand: _abstand);
        expect(_zuschnitte(z), {(4800, Stuecklage.laengs): 9});
        expect(_lieferung(z), {5000: 9});
      }
    });

    test('Versteifung ohne Rahmen: Leiterverband in zwei Reihen à zwölf '
        'Streben zu 36 cm (F31)', () {
      final stand = f01.mitNutzungsart(Nutzungsart.versteifungOhneRahmen);
      expect(strebenreihen(stand, const Millimeter(3090)), 2);
      final z = ukZusatz(stand, _uk, ukAbstand: _abstand);
      expect(_zuschnitte(z), {(360, Stuecklage.quer): 24});
      // 24 × 36 cm = 8,64 m: ein 6-m-Holz für 16, ein 4-m-Holz für 8
      expect(_lieferung(z), {4000: 1, 6000: 1});
      expect(z.stuecke.first.farbe, Stueckfarbe.gruen);
      expect(z.streben, hasLength(24));
      final erste = z.streben.first;
      expect(erste.von.x, closeTo(20, 1e-9));
      expect(erste.bis.x, closeTo(380, 1e-9));
      expect(erste.von.y, closeTo(1030, 1e-9));
      expect(erste.bis.y, closeTo(1030, 1e-9));
      expect(z.streben.last.von.y, closeTo(2060, 1e-9));
      expect(z.streben.last.bis.x, closeTo(4780, 1e-9));
    });

    test('Versteifung mit Rahmen: Rahmen und Leiterverband (F33)', () {
      final z = ukZusatz(
        f01.mitNutzungsart(Nutzungsart.versteifungMitRahmen),
        _uk,
        ukAbstand: _abstand,
      );
      expect(_zuschnitte(z), {
        (4800, Stuecklage.laengs): 2,
        (360, Stuecklage.quer): 24,
      });
      expect(_lieferung(z), {4000: 1, 5000: 2, 6000: 1});
    });

    test('Reihen des Leiterverbands: höchstens 120 cm, mindestens eine', () {
      final stand = f01.mitNutzungsart(Nutzungsart.versteifungMitRahmen);
      for (final (mm, reihen) in [
        (500, 1),
        (1200, 1),
        (1201, 1),
        (2400, 1),
        (2401, 2),
        (3600, 2),
        (3601, 3),
      ]) {
        expect(strebenreihen(stand, Millimeter(mm)), reihen, reason: '$mm');
      }
      expect(strebenreihen(f01, const Millimeter(3090)), 0);
      expect(
        strebenreihen(
          stand.mitTerrassenart(Terrassenart.hochterrasse),
          const Millimeter(3090),
        ),
        0,
      );
    });

    test('Streben nur, wo ihre Mitte in der Fläche liegt (L-Form)', () {
      // L-Form: 480 × 309 cm, oben rechts 240 × 150 cm ausgespart
      final l = f01
          .mitGrundriss(
            FreiformGrundriss(const [
              Punkt(0, 0),
              Punkt(4800, 0),
              Punkt(4800, 1590),
              Punkt(2400, 1590),
              Punkt(2400, 3090),
              Punkt(0, 3090),
            ], geschlossen: true),
          )
          .mitNutzungsart(Nutzungsart.versteifungMitRahmen);
      final z = ukZusatz(l, _uk, ukAbstand: _abstand);
      // Reihe 1 (y = 103 cm) über die ganze Breite, Reihe 2 (206 cm) nur links
      expect(z.streben.where((s) => s.von.y < 1500), hasLength(12));
      expect(z.streben.where((s) => s.von.y > 1500), hasLength(6));
      // Rahmen an den drei waagrechten Kanten
      expect(_zuschnitte(z)[(4800, Stuecklage.laengs)], 1);
      expect(_zuschnitte(z)[(2400, Stuecklage.laengs)], 2);
    });

    test('zweite Lage einer L-Form: Abschnitte je Linie', () {
      final l = f01
          .mitGrundriss(
            FreiformGrundriss(const [
              Punkt(0, 0),
              Punkt(4800, 0),
              Punkt(4800, 1600),
              Punkt(2400, 1600),
              Punkt(2400, 3200),
              Punkt(0, 3200),
            ], geschlossen: true),
          )
          .mitNutzungsart(Nutzungsart.doppelteUk);
      final z = ukZusatz(l, _uk, ukAbstand: _abstand);
      // 3200 / 400 = 8 Felder, 9 Linien: bis 120 cm volle Breite, ab der
      // Stufe bei 160 cm nur noch 240 cm
      expect(_zuschnitte(z), {
        (4800, Stuecklage.laengs): 4,
        (2400, Stuecklage.laengs): 5,
      });
    });

    test('Trapez abseits des Ursprungs: Rahmen an allen schrägen Kanten, '
        'zweite Lage je Linie so lang wie die Fläche dort breit ist', () {
      final trapez = f01.mitGrundriss(
        FreiformGrundriss(const [
          Punkt(500, 1000),
          Punkt(4500, 1000),
          Punkt(3500, 3000),
          Punkt(1500, 3000),
        ], geschlossen: true),
      );
      final rahmen = ukZusatz(
        trapez.mitNutzungsart(Nutzungsart.rahmen),
        _uk,
        ukAbstand: _abstand,
      );
      expect(_zuschnitte(rahmen), {
        (4000, Stuecklage.laengs): 1,
        (2236, Stuecklage.laengs): 2,
        (2000, Stuecklage.laengs): 1,
      });
      final doppelt = ukZusatz(
        trapez.mitNutzungsart(Nutzungsart.doppelteUk),
        _uk,
        ukAbstand: _abstand,
      );
      // 2000 / 400 = 5 Felder, 6 Linien ab y = 100 cm (die Ränder einen
      // halben mm nach innen)
      expect(_zuschnitte(doppelt), {
        (4000, Stuecklage.laengs): 1,
        (3600, Stuecklage.laengs): 1,
        (3200, Stuecklage.laengs): 1,
        (2800, Stuecklage.laengs): 1,
        (2400, Stuecklage.laengs): 1,
        (2001, Stuecklage.laengs): 1,
      });
      final streben = ukZusatz(
        trapez.mitNutzungsart(Nutzungsart.versteifungOhneRahmen),
        _uk,
        ukAbstand: _abstand,
      ).streben;
      // eine Reihe in der Mitte (y = 200 cm), UK-Linien ab x = 50 cm alle
      // 40 cm; Streben nur, wo ihre Mitte in der Fläche liegt (100–400 cm):
      // die Felder mit der Mitte bei 110 bis 390 cm
      expect(streben.map((s) => s.von.y).toSet(), {2000});
      expect(streben.first.von.x, closeTo(920, 1e-9));
      expect(streben.last.bis.x, closeTo(4080, 1e-9));
      expect(streben, hasLength(8));
    });

    test('U-Form: zwei Abschnitte auf einer Linie der zweiten Lage', () {
      final u = f01
          .mitGrundriss(
            FreiformGrundriss(const [
              Punkt(0, 0),
              Punkt(3000, 0),
              Punkt(3000, 800),
              Punkt(2000, 800),
              Punkt(2000, 400),
              Punkt(1000, 400),
              Punkt(1000, 800),
              Punkt(0, 800),
            ], geschlossen: true),
          )
          .mitNutzungsart(Nutzungsart.doppelteUk);
      // Linien bei 0 (volle Breite), 400 (auf der Stufe: zwei Schenkel)
      // und 800 (Rand, halber mm nach innen: zwei Schenkel)
      expect(_zuschnitte(ukZusatz(u, _uk, ukAbstand: _abstand)), {
        (3000, Stuecklage.laengs): 1,
        (1000, Stuecklage.laengs): 4,
      });
    });

    test('diagonal: die Streben liegen quer zu den UK-Linien', () {
      final z = ukZusatz(
        f01
            .mitNutzungsart(Nutzungsart.versteifungOhneRahmen)
            .mitVerlegerichtung(Verlegerichtung.diagonal45),
        _uk,
        ukAbstand: _abstand,
      );
      expect(z.streben, isNotEmpty);
      for (final s in z.streben) {
        final r = s.bis - s.von;
        // parallel zu den Dielen (45°)
        expect(r.x, closeTo(r.y, 1e-6));
      }
    });

    test('erzwungene UK-Länge gilt auch für das zusätzliche Holz', () {
      final z = ukZusatz(
        f01
            .mitNutzungsart(Nutzungsart.rahmen)
            .mitUkLaenge(const Millimeter(6000)),
        _uk,
        ukAbstand: _abstand,
      );
      expect(_lieferung(z), {6000: 2});
    });

    test('UK ohne Maße: keins', () {
      final ohne = Artikel(
        nummer: const Artikelnummer('20-10-001'),
        titel: 'Alu',
        art: Artikelart.aluUnterkonstruktion,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
        abmessungen: Abmessungen(breite: const Millimeter(40)),
      );
      expect(
        ukZusatz(
          f01.mitNutzungsart(Nutzungsart.rahmen),
          ohne,
          ukAbstand: _abstand,
        ),
        same(Ukzusatz.keiner),
      );
    });

    test('Ukzusatz ist unveränderlich', () {
      final z = ukZusatz(
        f01.mitNutzungsart(Nutzungsart.versteifungMitRahmen),
        _uk,
        ukAbstand: _abstand,
      );
      expect(z.stuecke.clear, throwsUnsupportedError);
      expect(z.bedarf.clear, throwsUnsupportedError);
      expect(z.streben.clear, throwsUnsupportedError);
    });
  });

  test('zweite Lage im Kreis: Hölzer so lang wie die Sehnen', () {
    final z = ukZusatz(
      Planungsstand.start
          .mitForm(Terrassenform.kreis)
          .mitNutzungsart(Nutzungsart.doppelteUk),
      _uk,
      ukAbstand: _abstand,
    );
    final laengen = [for (final s in z.stuecke) s.laenge.mm];
    expect(laengen, isNotEmpty);
    // keine Sehne länger als der Durchmesser 3600 mm, die mittleren fast
    expect(laengen.every((l) => l > 0 && l <= 3600), isTrue);
    expect(laengen.any((l) => l > 3500), isTrue);
    // Trapez mit schräger Seite von (4000, 0) nach (2000, 3000): bei y ist
    // die Lage 4000 − 2/3 · y lang
    final trapez = ukZusatz(
      Planungsstand(
        grundriss: FreiformGrundriss(const [
          Punkt(0, 0),
          Punkt(4000, 0),
          Punkt(2000, 3000),
          Punkt(0, 3000),
        ], geschlossen: true),
      ).mitNutzungsart(Nutzungsart.doppelteUk),
      _uk,
      ukAbstand: _abstand,
    );
    final lagen = [for (final s in trapez.stuecke) s.laenge.mm];
    expect(lagen.every((l) => l >= 2000 && l <= 4000), isTrue);
    expect(lagen.any((l) => l < 2100), isTrue);
  });

  group('Lieferstücke (M6-05)', () {
    const laengen = [Millimeter(4000), Millimeter(5000), Millimeter(6000)];
    Map<int, int> liefer(List<int> stuecke, {int? fest}) => {
      for (final MapEntry(:key, :value) in Dielenliste.aus(
        lieferhoelzer(
          [for (final s in stuecke) Millimeter(s)],
          laengen,
          fest: fest == null ? null : Millimeter(fest),
        ),
      ).anzahl.entries)
        key.mm: value,
    };

    /// Zuschnitt als Texte „Länge: Schnitte“ (M9-02).
    List<String> hoelzer(List<int> stuecke) => [
      for (final d in lieferhoelzer([
        for (final s in stuecke) Millimeter(s),
      ], laengen))
        '${d.laenge.mm}: ${[for (final s in d.schnitte) s.mm].join(' + ')}',
    ];

    test('lange Stücke einzeln wie eine Dielenreihe (R-B10)', () {
      expect(liefer([4800, 3090, 2000]), {4000: 2, 5000: 1});
      expect(liefer([8000]), {4000: 1, 6000: 1});
      expect(liefer([4800], fest: 6000), {6000: 1});
      // eine nicht gelieferte Wunschlänge gilt nicht
      expect(liefer([4800], fest: 4500), {5000: 1});
    });

    test('kurze Stücke aus gemeinsamen Hölzern, so wenig Rest wie möglich', () {
      expect(liefer([1999]), {4000: 1});
      expect(liefer(List.filled(10, 500)), {5000: 1});
      expect(liefer(List.filled(11, 500)), {6000: 1});
      expect(liefer(List.filled(12, 500)), {6000: 1});
      expect(liefer(List.filled(13, 500)), {4000: 1, 6000: 1});
      // ein neues Holz so lang wie der Rest aller kurzen Stücke
      expect(liefer(List.filled(8, 1500)), {6000: 2});
      // zuerst in ein angeschnittenes Holz, in das das Stück passt
      expect(liefer([1900, 1900, 1900, 300]), {6000: 1});
      expect(liefer([1900, 1900, 1900, 1900]), {4000: 1, 6000: 1});
    });

    test('Zuschnitt je Lieferholz (M9-02): lange einzeln, über der '
        'längsten gestückelt, kurze zuerst in die Reste der langen '
        '(M10-01), dann gemeinsam', () {
      expect(hoelzer([8000, 3090, 1900, 1900, 300]), [
        '6000: 6000',
        '4000: 2000 + 1900',
        '4000: 3090 + 300',
        '4000: 1900',
      ]);
      // F28: zwei Stützen à 39,9 cm im Rest von 400 cm für 309 cm
      expect(hoelzer([3090, 399, 399, 399]), [
        '4000: 3090 + 399 + 399',
        '4000: 399',
      ]);
      expect(hoelzer([13000]), ['6000: 6000', '6000: 6000', '4000: 1000']);
      // Regel 3.5: Reststück mindestens 50 cm (610 cm → 560 + 50 cm)
      expect(hoelzer([6100]), ['6000: 5600', '4000: 500']);
      expect(hoelzer([6100, 3090]), ['6000: 5600', '4000: 3090 + 500']);
    });

    test('ohne Lieferlängen nichts', () {
      expect(lieferhoelzer(const [Millimeter(500)], const []), isEmpty);
      expect(liefer(const []), isEmpty);
    });

    test(
      'UK-Achsabstand: der des Belags, höchstens der der Holzart (R-C01)',
      () {
        expect(ukAbstandFuer(robinie, null), robinie.ukAchsabstandMax);
        expect(
          ukAbstandFuer(robinie, const Millimeter(350)),
          const Millimeter(350),
        );
        expect(
          ukAbstandFuer(robinie, const Millimeter(600)),
          robinie.ukAchsabstandMax,
        );
        expect(
          ukAbstandFuer(robinie, robinie.ukAchsabstandMax),
          robinie.ukAchsabstandMax,
        );
      },
    );
  });
}
