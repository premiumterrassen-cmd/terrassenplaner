import 'dart:convert';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikeleintrag _diele() => Artikeleintrag(
  artikel: Artikel(
    nummer: const Artikelnummer('10-10-073-R'),
    titel: 'Terrassendiele Robinie PREMIUM SELECT 60 x 23 mm',
    art: Artikelart.diele,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    abmessungen: Abmessungen(
      breite: const Millimeter(60),
      staerke: const Millimeter(23),
      laengen: const [Millimeter(6000)],
    ),
    preisBrutto: const Cent(609),
    gewicht: const Gramm(1035),
    holzart: robinie,
    serie: premiumSelect,
    profil: Profil.genutet,
    oberseite: Oberseite.bombiert,
    bilder: const ['profil.webp', 'stirn.webp'],
  ),
  verweise: {
    'moeglicheBefestigungDeck': const [
      Artikelnummer('80-10-001-50'),
      Artikelnummer('80-10-001-100'),
    ],
    'moeglicheDrainage': const [],
  },
  angaben: const {'Abstand_UK': 400, 'UK_Abstand_vom_Rand': 0},
  benoetigt: const {Artikelnummer('50-80-003'): 1},
);

Artikeleintrag _clip() => Artikeleintrag(
  artikel: Artikel(
    nummer: const Artikelnummer('80-10-001-100'),
    titel: 'CLIP-FIXX VPE 100',
    art: Artikelart.clip,
    einheit: Verkaufseinheit(
      Mengeneinheit.karton,
      inhalt: 100,
      inhaltEinheit: Mengeneinheit.stueck,
    ),
  ),
);

void main() {
  test('Rundreise über JSON erhält alle Angaben', () {
    final datei = Artikeldatei(
      quelle: 'Terrassenplaner_Import_v6.xlsx',
      version: 'abc123',
      eintraege: [_diele(), _clip()],
    );
    final json =
        jsonDecode(jsonEncode(datei.alsJson())) as Map<String, Object?>;
    final zurueck = Artikeldatei.ausJson(json, [robinie]);
    expect(
      [zurueck.quelle, zurueck.version],
      ['Terrassenplaner_Import_v6.xlsx', 'abc123'],
    );
    expect(zurueck.alsJson(), datei.alsJson());

    final diele = zurueck[const Artikelnummer('10-10-073-R')]!;
    final a = diele.artikel;
    expect(
      [a.titel, a.art, a.holzart, a.serie, a.profil, a.oberseite],
      [
        'Terrassendiele Robinie PREMIUM SELECT 60 x 23 mm',
        Artikelart.diele,
        robinie,
        premiumSelect,
        Profil.genutet,
        Oberseite.bombiert,
      ],
    );
    expect(
      [a.abmessungen.breite, a.abmessungen.staerke, a.abmessungen.laengste],
      [const Millimeter(60), const Millimeter(23), const Millimeter(6000)],
    );
    expect([a.preisBrutto, a.gewicht], [const Cent(609), const Gramm(1035)]);
    expect(a.bilder, ['profil.webp', 'stirn.webp']);
    expect(diele.verweise, {
      'moeglicheBefestigungDeck': [
        const Artikelnummer('80-10-001-50'),
        const Artikelnummer('80-10-001-100'),
      ],
    }, reason: 'leere Verweise entfallen');
    expect(diele.angaben, {'Abstand_UK': 400, 'UK_Abstand_vom_Rand': 0});
    expect(diele.benoetigt, {const Artikelnummer('50-80-003'): 1});

    final clip = zurueck[const Artikelnummer('80-10-001-100')]!.artikel;
    expect(
      clip.einheit,
      Verkaufseinheit(
        Mengeneinheit.karton,
        inhalt: 100,
        inhaltEinheit: Mengeneinheit.stueck,
      ),
    );
    expect([
      clip.holzart,
      clip.serie,
      clip.preisBrutto,
      clip.abmessungen.breite,
    ], everyElement(isNull));
    expect(zurueck[const Artikelnummer('gibt-es-nicht')], isNull);
  });

  test('doppelte Artikelnummern werden abgelehnt', () {
    expect(
      () => Artikeldatei(
        quelle: 'q',
        version: 'v',
        eintraege: [_clip(), _clip()],
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.invalidValue,
          'Nummern',
          '80-10-001-100',
        ),
      ),
    );
  });

  test('unbekannte Holzart wird abgelehnt', () {
    final json = Artikeldatei(
      quelle: 'q',
      version: 'v',
      eintraege: [_diele()],
    ).alsJson();
    expect(() => Artikeldatei.ausJson(json, const []), throwsArgumentError);
  });

  test('Inhalte sind unveränderlich', () {
    final datei = Artikeldatei(
      quelle: 'q',
      version: 'v',
      eintraege: [_diele()],
    );
    final e = datei.eintraege.single;
    expect(datei.eintraege.clear, throwsUnsupportedError);
    expect(e.verweise.clear, throwsUnsupportedError);
    expect(
      e.verweise['moeglicheBefestigungDeck']!.clear,
      throwsUnsupportedError,
    );
    expect(e.angaben.clear, throwsUnsupportedError);
    expect(e.benoetigt.clear, throwsUnsupportedError);
    expect(_clip().verweise, isEmpty);
  });
}
