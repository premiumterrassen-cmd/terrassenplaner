@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

Artikeldatei _datei(String version) => Artikeldatei(
  quelle: 'upload-$version.xlsx',
  version: version,
  eintraege: [
    Artikeleintrag(
      artikel: Artikel(
        nummer: const Artikelnummer('80-10-001'),
        titel: 'CLIP-FIXX',
        art: Artikelart.clip,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
      ),
    ),
  ],
);

void main() {
  late Directory ordner;
  late File datei;
  var zeit = DateTime(2026, 10, 23, 12);

  void schreibe(String inhalt) {
    datei.writeAsStringSync(inhalt);
    zeit = zeit.add(const Duration(minutes: 1));
    datei.setLastModifiedSync(zeit);
  }

  setUp(() {
    ordner = Directory.systemTemp.createTempSync('artikeldatei');
    datei = File('${ordner.path}/artikel.json');
  });
  tearDown(() => ordner.deleteSync(recursive: true));

  test('Konstanten', () {
    expect(ArtikeldateiQuelle.umgebungsvariable, 'PLANER_ARTIKELDATEI');
    expect(ArtikeldateiQuelle.standardPfad, 'artikel.json');
    expect(
      [ArtikeldateiQuelle.leer.quelle, ArtikeldateiQuelle.leer.version],
      ['keine Artikeldatei', 'leer'],
    );
    expect(ArtikeldateiQuelle.leer.eintraege, isEmpty);
    expect(ArtikeldateiQuelle('x').holzarten, [robinie]);
  });

  test('liefert nur neue Stände', () {
    final quelle = ArtikeldateiQuelle(datei.path);
    expect(quelle.neuerStand(), isNull, reason: 'Datei fehlt');

    schreibe(jsonEncode(_datei('v1').alsJson()));
    expect(quelle.neuerStand()!.version, 'v1');
    expect(quelle.neuerStand(), isNull, reason: 'unverändert');

    schreibe(jsonEncode(_datei('v2').alsJson()));
    expect(quelle.neuerStand()!.version, 'v2');
  });

  test('fehlerhafter Stand wirft nur einmal', () {
    final quelle = ArtikeldateiQuelle(datei.path);
    schreibe('{kaputt');
    expect(quelle.neuerStand, throwsFormatException);
    expect(quelle.neuerStand(), isNull);
  });

  test('Holzarten der Quelle lösen die Kennungen auf', () {
    final mitHolz = Artikeldatei(
      quelle: 'q',
      version: 'v',
      eintraege: [
        Artikeleintrag(
          artikel: Artikel(
            nummer: const Artikelnummer('10-10-073-R'),
            titel: 'Diele',
            art: Artikelart.diele,
            einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
            holzart: robinie,
            serie: premiumSelect,
          ),
        ),
      ],
    );
    schreibe(jsonEncode(mitHolz.alsJson()));
    expect(
      ArtikeldateiQuelle(datei.path, holzarten: const []).neuerStand,
      throwsArgumentError,
    );
  });

  test('Artikeldienst übernimmt neue Stände und meldet Fehler', () async {
    final router = PlanerRouter.starte(await testEinstellungen());
    addTearDown(router.stoppe);
    final dienst = await ArtikelDienst.starte(router, ArtikeldateiQuelle.leer);
    addTearDown(dienst.stoppe);
    final quelle = ArtikeldateiQuelle(datei.path);
    final meldungen = <String>[];

    await dienst.aktualisiere(quelle, meldungen.add);
    expect(dienst.datei.version, 'leer');

    schreibe(jsonEncode(_datei('v1').alsJson()));
    await dienst.aktualisiere(quelle, meldungen.add);
    expect(dienst.datei.version, 'v1');

    // Gleiche Version mit neuem Zeitstempel: nichts zu tun.
    schreibe(jsonEncode(_datei('v1').alsJson()));
    await dienst.aktualisiere(quelle, meldungen.add);

    schreibe('{kaputt');
    await dienst.aktualisiere(quelle, meldungen.add);
    expect(dienst.datei.version, 'v1');

    expect(meldungen, [
      'Artikeldaten v1 aus upload-v1.xlsx: 1 Artikel',
      startsWith(
        'Artikeldatei ${datei.path} nicht übernommen: FormatException',
      ),
    ]);
  });
}
