@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

/// Ablage mit genau einer gespeicherten Konfiguration.
final class _Ablage implements KonfigurationsSpeicher {
  _Ablage(this.stand, this.planung);

  final KonfigurationsStand stand;
  final Planung planung;

  @override
  Uint8List lies(KonfigurationsStand gesucht, {bool ohnePruefcode = false}) {
    if (gesucht != stand) {
      throw KonfigurationUnbekannt(gesucht.nummer, gesucht.version);
    }
    return planung.zuBytes();
  }

  @override
  KonfigurationsStand speichere(
    Uint8List inhalt, {
    Konfigurationskennung? kennung,
  }) => throw UnimplementedError();

  @override
  void merkeEntwurf(
    String schluessel,
    Uint8List inhalt, {
    KonfigurationsStand? bezug,
  }) => throw UnimplementedError();

  @override
  Entwurf? entwurf(String schluessel) => throw UnimplementedError();
}

void main() {
  final diele = Artikel(
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
    profil: Profil.genutet,
  );
  final uk = Artikel(
    nummer: const Artikelnummer('10-10-031'),
    titel: 'UK',
    art: Artikelart.unterkonstruktion,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    abmessungen: Abmessungen(
      breite: const Millimeter(40),
      staerke: const Millimeter(60),
    ),
    holzart: robinie,
    serie: basic,
  );
  final regelwerk = Regelwerk(
    Artikeldatei(
      quelle: 'test',
      version: '1',
      eintraege: [
        Artikeleintrag(artikel: diele, angaben: const {'Abstand_UK': 400}),
        Artikeleintrag(artikel: uk),
      ],
    ),
  );
  final kennung = Konfigurationskennung.lies('2026-11-05-0001-ABCDE');
  final stand = KonfigurationsStand(kennung, 2);
  final planung = Planung.start.mitNeuerFlaeche().mitHaeufigkeit(3);

  group('Unterlagen der Planung', () {
    test('je Fläche eine Berechnung mit ihr als bearbeiteter, Werte der '
        'ganzen Planung', () {
      final u = UnterlagenDienst.unterlagen(
        planung,
        datum: DateTime(2026, 11, 5),
        belag: (_) => diele,
        regelwerk: regelwerk,
        unterkonstruktion: (_) => uk,
        stand: stand,
        kunde: Kundendaten(name: 'Max'),
        sprache: Unterlagensprache.englisch,
      );
      final titel = [for (final k in u.kapitel) k.titel];
      expect(titel, containsAll(['Terrace 1', 'Terrace 2']));
      expect(titel, contains('Terrace 2 – Substructure'));
      expect(titel, contains('Terrace 1 – Decking cutting plan'));
      expect(titel, contains('Material list'));
      expect(u.kopfzeile, contains('2026-11-05-0001-ABCDE · Version 2'));
      final zusammenfassung = u.kapitel.first.inhalt
          .whereType<Wertepaare>()
          .last
          .zeilen;
      // 4 × 14,832 m²: die zweite Fläche dreimal
      expect(zusammenfassung.first, ('Terrace area', '59.328 m²'));
      expect(zusammenfassung[1], ('Number of areas', '2'));
    });

    test('ohne Artikeldaten nur Geometrie', () {
      final u = UnterlagenDienst.unterlagen(
        Planung.start,
        datum: DateTime(2026, 11, 5),
      );
      expect(
        [for (final k in u.kapitel) k.titel],
        ['Planungsunterlagen', 'Ihre Terrasse', 'Rechtliche Hinweise'],
      );
    });
  });

  group('über den Router', () {
    late PlanerRouter router;
    late UnterlagenDienst dienst;
    late Session kunde;

    Future<void> starte({bool mitArtikeln = true}) async {
      router = PlanerRouter.starte(await testEinstellungen());
      final ablage = _Ablage(stand, planung);
      dienst = mitArtikeln
          ? await UnterlagenDienst.starte(
              router,
              ablage,
              belag: (_) => diele,
              regelwerk: () => regelwerk,
              unterkonstruktion: (_) => uk,
              uhr: () => DateTime(2026, 11, 5),
            )
          : await UnterlagenDienst.starte(router, ablage);
      kunde = await Client(
        realm: WampNamen.realm,
        transport: WebSocketTransport.withFlatBuffersSerializer(
          'ws://127.0.0.1:${router.webSocketPort}/ws',
        ),
      ).connect().first.timeout(const Duration(seconds: 20));
    }

    tearDown(() async {
      await kunde.close();
      await dienst.stoppe();
      await router.stoppe();
    });

    Future<String> pdf(List<Object?> argumente) async {
      final antwort = await kunde
          .callSingle(WampNamen.planungsunterlagenPdf, arguments: argumente)
          .timeout(const Duration(seconds: 20));
      return latin1.decode(antwort.arguments!.single! as Uint8List);
    }

    Matcher fehler(String uri, [Object? argumente]) => throwsA(
      isA<Error>()
          .having((e) => e.error, 'error', uri)
          .having((e) => e.arguments, 'arguments', argumente ?? anything),
    );

    test('PDF der gespeicherten Version, Sprache und Kundendaten', () async {
      await starte();
      final deutsch = await pdf([kennung.wert, 2]);
      expect(deutsch, startsWith('%PDF'));
      final englisch = await pdf([
        kennung.wert,
        2,
        'en',
        {'name': 'Max'},
      ]);
      expect(englisch, startsWith('%PDF'));
      expect(englisch.length, isNot(deutsch.length));
      final ohneKunde = await pdf([kennung.wert, 2, 'en']);
      expect(ohneKunde.length, lessThan(englisch.length));
    });

    test('unbekannte Version und falscher Prüfcode wie beim Laden', () async {
      await starte(mitArtikeln: false);
      expect(await pdf([kennung.wert, 2]), startsWith('%PDF'));
      await expectLater(
        pdf([kennung.wert, 3]),
        fehler(WampNamen.konfigurationUnbekannt, [kennung.nummer.wert, 3]),
      );
      await expectLater(
        pdf(['2026-11-05-0001-ABCDF', 2]),
        fehler(WampNamen.konfigurationUnbekannt, [kennung.nummer.wert, 2]),
      );
      await expectLater(
        pdf(['2026-11-05-0001', 2]),
        fehler(WampNamen.konfigurationUnbekannt, [kennung.nummer.wert, 2]),
      );
    });

    test('ungültige Aufrufe', () async {
      await starte();
      for (final argumente in [
        <Object?>[],
        [kennung.wert],
        [kennung.wert, 0],
        [kennung.wert, 2, 'de', 'kein Wörterbuch'],
        [
          kennung.wert,
          2,
          'de',
          {'name': 1},
        ],
      ]) {
        await expectLater(
          pdf(argumente),
          fehler(WampNamen.konfigurationUngueltig),
          reason: '$argumente',
        );
      }
    });
  });
}
