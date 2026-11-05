@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_router/connectanum_router.dart'
    show LazyMessagePayload, RouterSession;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

/// Erfundene Testartikel – nur Verkaufsdaten.
Artikel _clip(String vpe, int inhalt) => Artikel(
  nummer: Artikelnummer('80-10-001-$vpe'),
  titel: 'CLIP-FIXX® "BLACK EDITION" - VPE $vpe',
  art: Artikelart.clip,
  einheit: Verkaufseinheit(Mengeneinheit.verpackungseinheit, inhalt: inhalt),
  preisBrutto: Cent(inhalt * 75),
);

final _clips = [_clip('50', 50), _clip('100', 100), _clip('250', 250)];

final _diele = Artikel(
  nummer: const Artikelnummer('10-10-073-R'),
  titel: 'Terrassendiele Robinie PREMIUM SELECT 60 x 23 mm, genutet',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(60),
    staerke: const Millimeter(23),
    laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
  ),
  preisBrutto: const Cent(1290),
  holzart: robinie,
  serie: premiumSelect,
  profil: Profil.genutet,
  bilder: const ['Diele_60x23.jpg'],
);

final _regelwerk = Regelwerk(
  Artikeldatei(
    quelle: 'test',
    version: '1',
    eintraege: [
      Artikeleintrag(
        artikel: _diele,
        verweise: {
          Beziehung.befestigung.spalte: [for (final c in _clips) c.nummer],
        },
        angaben: const {'Abstand_UK': 400},
      ),
      for (final c in _clips) Artikeleintrag(artikel: c),
    ],
  ),
);

const _schluessel = (
  nummer: Artikelnummer('10-10-073-R'),
  laenge: Millimeter(5000),
  zusatz: null,
);

String _export(
  List<Object?> argumente, {
  Regelwerk? regelwerk,
  bool mitMengen = false,
}) => ExportDienst.grandTotal(
  argumente,
  belag: (_) => _diele,
  regelwerk: regelwerk,
  unterkonstruktion: (_) => null,
  mitMengen: mitMengen,
);

void main() {
  group('Export für GrandTotal (M9-08)', () {
    test('F01: Dielen und Clips mit Maßen, Preisen und Bild-Link', () {
      final zeilen = _export([
        Planung.start.zuBytes(),
        'https://planer.example/',
      ], regelwerk: _regelwerk).split('\r\n');
      expect(zeilen, [
        grandTotalSpalten.join(';'),
        'Terrassendiele Robinie PREMIUM SELECT 60 x 23 mm, genutet - Länge: '
            '5000 mm;Terrassendiele Robinie PREMIUM SELECT 60 x 23 mm, '
            'genutet;;48;60;23;5000;10-10-073-R;10.8403;12.90;'
            'https://planer.example/artikelbilder/Diele_60x23.webp;0.0069;'
            '248.4;0.3;240;Deckbelag;lfm',
        // 637 Clips: 2 × 250 + 100 + 50 wie im alten Planer (B-094)
        '"CLIP-FIXX® ""BLACK EDITION"" - VPE 100";"CLIP-FIXX® ""BLACK '
            'EDITION"" - VPE 100";;1;;;;80-10-001-100;63.0252;75.00;;;;;;'
            'BefestigungDeck,Zubehoer;VPE',
        '"CLIP-FIXX® ""BLACK EDITION"" - VPE 250";"CLIP-FIXX® ""BLACK '
            'EDITION"" - VPE 250";;2;;;;80-10-001-250;157.5630;187.50;;;;;;'
            'BefestigungDeck,Zubehoer;VPE',
        '"CLIP-FIXX® ""BLACK EDITION"" - VPE 50";"CLIP-FIXX® ""BLACK '
            'EDITION"" - VPE 50";;1;;;;80-10-001-50;31.5126;37.50;;;;;;'
            'BefestigungDeck,Zubehoer;VPE',
        '',
      ]);
    });

    test('geänderte Mengen der Mitarbeiter-Ansicht nur mit Freigabe', () {
      final planung = Planung.start.mitMenge(_schluessel, 50);
      final zeilen = _export(
        [planung.zuBytes()],
        regelwerk: _regelwerk,
        mitMengen: true,
      ).split('\r\n');
      expect(zeilen[1], contains(';50;60;23;5000;'));
      expect(
        _export([planung.zuBytes()], regelwerk: _regelwerk).split('\r\n')[1],
        contains(';48;60;23;5000;'),
      );
      // ohne Adresse der App kein Bild-Link
      expect(zeilen[1], contains(';12.90;;0.0069;'));
    });

    test('ohne Regelwerk: Dielen ohne Artikelangaben', () {
      final zeilen = _export([Planung.start.zuBytes()]).split('\r\n');
      expect(zeilen, hasLength(3));
      expect(
        zeilen[1],
        endsWith(';48;;;5000;10-10-073-R;10.8403;12.90;;;;;240;;lfm'),
      );
    });

    test('falsche Argumente und Planungen werden abgewiesen', () {
      expect(() => _export(const []), throwsFormatException);
      expect(() => _export(['x']), throwsFormatException);
      expect(
        () => _export([Planung.start.zuBytes(), 1]),
        throwsFormatException,
      );
      expect(
        () => _export([Uint8List(ExportDienst.groessterInhalt + 1)]),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'planung')
              .having((e) => e.message, 'message', 'zu groß')
              .having(
                (e) => e.invalidValue,
                'wert',
                ExportDienst.groessterInhalt + 1,
              ),
        ),
      );
      expect(() => _export([Uint8List(8)]), throwsA(anything));
    });

    group('über den Router', () {
      late PlanerRouter router;
      late ExportDienst dienst;
      late RouterSession intern;

      setUp(() async {
        router = PlanerRouter.starte(await testEinstellungen());
        dienst = await ExportDienst.starte(
          router,
          belag: (_) => _diele,
          regelwerk: () => _regelwerk,
          unterkonstruktion: (_) => null,
        );
        intern = await router.dienstSitzung('test');
      });

      tearDown(() async {
        await intern.close();
        await dienst.stoppe();
        await router.stoppe();
      });

      Future<List<Object?>> rufe(List<Object?> argumente) async {
        final antwort = await intern
            .callLazyPayload(
              WampNamen.exportGrandTotal,
              payload: LazyMessagePayload.materialized(arguments: argumente),
            )
            .first
            .timeout(const Duration(seconds: 5));
        return antwort.arguments ?? const [];
      }

      test('liefert die Importdatei als Text', () async {
        final [csv as String] = await rufe([
          Planung.start.zuBytes(),
          'https://planer.example/',
        ]);
        expect(csv, startsWith('${grandTotalSpalten.join(';')}\r\n'));
        expect(csv, contains('artikelbilder/Diele_60x23.webp'));
        expect(csv.split('\r\n'), hasLength(6));
      });

      test('unlesbare Planung: Fehler planung_ungueltig', () async {
        await expectLater(
          rufe(['keine Planung']),
          throwsA(
            isA<Object>()
                .having(
                  (e) => (e as dynamic).error,
                  'error',
                  WampNamen.planungUngueltig,
                )
                .having(
                  (e) => ((e as dynamic).arguments as List).single,
                  'arguments',
                  contains('unerwartete Argumente'),
                ),
          ),
        );
        // ohne Argumente ebenso
        await expectLater(rufe(const []), throwsA(anything));
      });

      test('über WebSocket: geänderte Mengen erst mit Anmeldung', () async {
        final kunde = await Client(
          realm: WampNamen.realm,
          transport: WebSocketTransport.withFlatBuffersSerializer(
            'ws://127.0.0.1:${router.webSocketPort}/ws',
          ),
        ).connect().first.timeout(const Duration(seconds: 20));
        addTearDown(kunde.close);
        final antwort = await kunde
            .callSingle(
              WampNamen.exportGrandTotal,
              arguments: [Planung.start.mitMenge(_schluessel, 50).zuBytes()],
            )
            .timeout(const Duration(seconds: 5));
        final csv = antwort.arguments!.single! as String;
        // bis zur Mitarbeiter-Anmeldung (M9-10) die berechneten Mengen
        expect(csv.split('\r\n')[1], contains(';48;60;23;5000;'));
      });
    });
  });
}
