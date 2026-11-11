@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_router/connectanum_router.dart' as wamp_router;
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

/// Zubehör aus dem Schritt „Zubehör“ (M8-01).
final _vlies = Artikel(
  nummer: const Artikelnummer('50-90-001'),
  titel: 'Schutz-Vlies',
  art: Artikelart.sonstiges,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  preisBrutto: const Cent(2380),
  gewicht: const Gramm(800),
  zubehoergruppe: Zubehoergruppe.allgemein,
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
      Artikeleintrag(artikel: _vlies),
    ],
  ),
);

const _schluessel = (
  nummer: Artikelnummer('10-10-073-R'),
  laenge: Millimeter(5000),
  zusatz: null,
);

/// F01 mit zwei Schutz-Vliesen aus dem Zubehör.
final _mitVlies = Planung.start.mitStand(
  Planungsstand.start.mitZubehoermenge(_vlies.nummer, 2),
);

String _export(
  List<Object?> argumente, {
  Regelwerk? regelwerk,
  bool mitMengen = false,
}) => ExportDienst.grandTotalAuftrag(
  argumente,
  belag: (_) => _diele,
  regelwerk: regelwerk,
  unterkonstruktion: (_) => null,
  mitMengen: mitMengen,
)();

const _dielen =
    'Terrassendiele Robinie PREMIUM SELECT 60 x 23 mm, genutet - Länge: '
    '5000 mm;Terrassendiele Robinie PREMIUM SELECT 60 x 23 mm, genutet;;';

void main() {
  group('Export für GrandTotal (M9-08)', () {
    test('F01: Dielen, Freidiele, Clips und Zubehör (M8)', () {
      final zeilen = _export([
        _mitVlies.zuBytes(),
        'https://planer.example/',
      ], regelwerk: _regelwerk).split('\r\n');
      expect(zeilen, [
        grandTotalSpalten.join(';'),
        // 6 mm Fuge (Planungskern v6): 47 statt 48 Reihen
        '${_dielen}47;60;23;5000;10-10-073-R;10.8403;12.90;'
            'https://planer.example/artikelbilder/Diele_60x23.webp;0.0069;'
            '243.225;0.3;235;Deckbelag;lfm',
        // Freidiele (M8-04, B-079): eigene Zeile mit Preis 0
        'Terrassendiele Robinie PREMIUM SELECT 60 x 23 mm, genutet - Länge: '
            '5000 mm - Freidiele;Terrassendiele Robinie PREMIUM SELECT 60 x '
            '23 mm, genutet;;1;60;23;5000;10-10-073-R;0.0000;0.00;'
            'https://planer.example/artikelbilder/Diele_60x23.webp;0.0069;'
            '5.175;0.3;5;Deckbelag;lfm',
        // ohne glattkantes Gegenstück auch die Randreihen mit Clips:
        // 611 × 1,05 → 642 Clips: 2 × 250 + 100 + 50 (Planungskern v6)
        '"CLIP-FIXX® ""BLACK EDITION"" - VPE 100";"CLIP-FIXX® ""BLACK '
            'EDITION"" - VPE 100";;1;;;;80-10-001-100;63.0252;75.00;;;;;;'
            'BefestigungDeck,Zubehoer;VPE',
        '"CLIP-FIXX® ""BLACK EDITION"" - VPE 250";"CLIP-FIXX® ""BLACK '
            'EDITION"" - VPE 250";;2;;;;80-10-001-250;157.5630;187.50;;;;;;'
            'BefestigungDeck,Zubehoer;VPE',
        '"CLIP-FIXX® ""BLACK EDITION"" - VPE 50";"CLIP-FIXX® ""BLACK '
            'EDITION"" - VPE 50";;1;;;;80-10-001-50;31.5126;37.50;;;;;;'
            'BefestigungDeck,Zubehoer;VPE',
        // Zubehör (M8-01): Warengruppe Zubehoer, Gewicht je Stück × Anzahl
        'Schutz-Vlies;Schutz-Vlies;;2;;;;50-90-001;20.0000;23.80;;;1.6;;;'
            'Zubehoer;Stück',
        '',
      ]);
    });

    test('geänderte Mengen des Mitarbeiters nur mit Freigabe', () {
      final planung = _mitVlies.mitMenge(_schluessel, 50);
      final zeilen = _export(
        [planung.zuBytes()],
        regelwerk: _regelwerk,
        mitMengen: true,
      ).split('\r\n');
      expect(zeilen[1], startsWith('${_dielen}50;60;23;5000;'));
      // ohne Adresse der App kein Bild-Link
      expect(zeilen[1], contains(';12.90;;0.0069;'));
      expect(
        _export([planung.zuBytes()], regelwerk: _regelwerk).split('\r\n')[1],
        startsWith('${_dielen}47;60;23;5000;'),
      );
    });

    test('ohne Regelwerk: Dielen ohne Artikelangaben', () {
      final zeilen = _export([Planung.start.zuBytes()]).split('\r\n');
      expect(zeilen, hasLength(4));
      expect(
        zeilen[1],
        endsWith(';47;;;5000;10-10-073-R;10.8403;12.90;;;;;235;;lfm'),
      );
      expect(zeilen[2], contains('- Freidiele;'));
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

    test('im Rechenwerk mit vorab nachgeschlagener UK (M10-02)', () async {
      final regelwerk = Regelwerk(Lastdaten.artikeldatei);
      final zwei = Planung([
        Terrassenflaeche(Planungsstand.start),
        Terrassenflaeche(Planungsstand.start.mitForm(Terrassenform.lForm)),
      ]);
      // UK nur für die zweite Fläche: das Nachschlagen je Stand zählt
      Artikel? nurZweite(Planungsstand s) =>
          s == zwei.flaechen.last.stand ? Lastdaten.unterkonstruktion : null;
      String Function() auftrag(Unterkonstruktionssuche uk) =>
          ExportDienst.grandTotalAuftrag(
            [zwei.zuBytes()],
            belag: (n) => n == null ? Lastdaten.diele : null,
            regelwerk: regelwerk,
            unterkonstruktion: uk,
          );
      final csv = await Rechenwerk(parallel: 1).rechne(auftrag(nurZweite));
      expect(csv, contains(Lastdaten.unterkonstruktion.titel));
      expect(csv, contains(Lastdaten.diele.titel));
      expect(csv, isNot(auftrag((_) => Lastdaten.unterkonstruktion)()));
      expect(
        auftrag((_) => null)(),
        isNot(contains(Lastdaten.unterkonstruktion.titel)),
      );
    });

    test('geänderte Mengen nur mit der Rolle mitarbeiter vom Router', () {
      wamp_router.Invocation aufruf(Map<String, Object?> custom) =>
          wamp_router.Invocation(
            1,
            2,
            wamp_router.InvocationDetails(null, null, false),
          )..details.custom.addAll(custom);
      expect(
        ExportDienst.darfMengenAendern(
          aufruf({'caller_authrole': Rollen.mitarbeiter}),
        ),
        isTrue,
      );
      for (final custom in [
        <String, Object?>{},
        {'caller_authrole': Rollen.kunde},
        {'caller_authrole': Rollen.dienst},
        {'caller_authid': Rollen.mitarbeiter},
      ]) {
        expect(
          ExportDienst.darfMengenAendern(aufruf(custom)),
          isFalse,
          reason: '$custom',
        );
      }
    });

    group('über den Router', () {
      late PlanerRouter router;
      late ExportDienst dienst;
      late wamp_router.RouterSession intern;

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
              payload: wamp_router.LazyMessagePayload.materialized(
                arguments: argumente,
              ),
            )
            .first
            .timeout(const Duration(seconds: 5));
        return antwort.arguments ?? const [];
      }

      test('eigene Dienst-Sitzung, Prozedur für Mitarbeiter', () {
        expect(ExportDienst.sitzungId, 'export-dienst');
        expect(
          WampNamen.exportGrandTotal,
          '${Rollen.mitarbeiterUri}export.grandtotal',
        );
      });

      test('liefert die Importdatei als Text', () async {
        final [csv as String] = await rufe([
          _mitVlies.mitMenge(_schluessel, 50).zuBytes(),
          'https://planer.example/',
        ]);
        final zeilen = csv.split('\r\n');
        expect(zeilen.first, grandTotalSpalten.join(';'));
        expect(csv, contains('artikelbilder/Diele_60x23.webp'));
        expect(zeilen, hasLength(8));
        // ein interner Dienst ist kein Mitarbeiter: berechnete Mengen
        expect(zeilen[1], startsWith('${_dielen}47;'));
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

      test('zu aufwendige Planung: Fehler planung_zu_aufwendig', () async {
        await dienst.stoppe();
        dienst = await ExportDienst.starte(
          router,
          belag: (_) => Lastdaten.diele,
          regelwerk: () => Regelwerk(Lastdaten.artikeldatei),
          unterkonstruktion: (_) => Lastdaten.unterkonstruktion,
          rechenwerk: Rechenwerk(
            parallel: 1,
            hoechstdauer: const Duration(milliseconds: 50),
          ),
        );
        await expectLater(
          rufe([Lastdaten.gross().zuBytes()]),
          throwsA(
            isA<Object>()
                .having(
                  (e) => (e as dynamic).error,
                  'error',
                  WampNamen.planungZuAufwendig,
                )
                .having(
                  (e) => ((e as dynamic).arguments as List).single,
                  'arguments',
                  contains('zu aufwendig'),
                ),
          ),
        );
        // falsche Argumente bleiben planung_ungueltig
        await expectLater(
          rufe(['keine Planung']),
          throwsA(
            isA<Object>().having(
              (e) => (e as dynamic).error,
              'error',
              WampNamen.planungUngueltig,
            ),
          ),
        );
      });

      test('Kunden dürfen nicht exportieren', () async {
        final kunde = await Client(
          realm: WampNamen.realm,
          transport: WebSocketTransport.withFlatBuffersSerializer(
            'ws://127.0.0.1:${router.webSocketPort}/ws',
          ),
        ).connect().first.timeout(const Duration(seconds: 20));
        addTearDown(kunde.close);
        expect(kunde.authRole, Rollen.kunde);
        await expectLater(
          kunde
              .callSingle(
                WampNamen.exportGrandTotal,
                arguments: [_mitVlies.zuBytes()],
                // eine selbst angegebene Rolle hilft nicht
                options: CallOptions(
                  discloseMe: true,
                  custom: {'caller_authrole': Rollen.mitarbeiter},
                ),
              )
              .timeout(const Duration(seconds: 5)),
          throwsA(
            isA<Object>().having(
              (e) => (e as dynamic).error,
              'error',
              'wamp.error.not_authorized',
            ),
          ),
        );
      });
    });
  });
}
