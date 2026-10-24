@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:connectanum_client/connectanum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/artikel/artikel_quelle.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

Artikeleintrag _diele(String nummer) => Artikeleintrag(
  artikel: Artikel(
    nummer: Artikelnummer(nummer),
    titel: 'Diele $nummer',
    art: Artikelart.diele,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    holzart: robinie,
    serie: premiumSelect,
    profil: Profil.genutet,
  ),
  verweise: {
    'moeglicheBefestigungDeck': const [Artikelnummer('80-10-001')],
  },
);

final _clip = Artikeleintrag(
  artikel: Artikel(
    nummer: const Artikelnummer('80-10-001'),
    titel: 'CLIP-FIXX',
    art: Artikelart.clip,
    einheit: Verkaufseinheit(Mengeneinheit.stueck),
  ),
);

Artikeldatei _datei(String version, List<Artikeleintrag> eintraege) =>
    Artikeldatei(quelle: 'test', version: version, eintraege: eintraege);

/// Ende-zu-Ende gegen einen echten Router mit Artikeldienst (M2-06).
void main() {
  late PlanerRouter router;
  late ArtikelDienst dienst;
  late Session sitzung;
  late ArtikelQuelle quelle;

  setUp(() async {
    final health = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final healthPort = health.port;
    await health.close();
    router = PlanerRouter.starte(
      RouterEinstellungen(
        authToken: 't',
        dienstTicket: 'k',
        port: 0,
        healthListen: '127.0.0.1:$healthPort',
      ),
    );
    dienst = await ArtikelDienst.starte(
      router,
      _datei('v1', [_diele('10-10-073-R'), _clip]),
    );
    sitzung = await Client(
      realm: WampNamen.realm,
      transport: WebSocketTransport.withFlatBuffersSerializer(
        'ws://127.0.0.1:${router.webSocketPort}/ws',
      ),
    ).connect().first.timeout(const Duration(seconds: 20));
    quelle = await ArtikelQuelle.verbinde(sitzung);
  });

  tearDown(() async {
    await quelle.schliesse();
    await sitzung.close();
    await dienst.stoppe();
    await router.stoppe();
  });

  test('lädt Artikel je Filter und merkt sich die Antwort', () async {
    expect(quelle.version, isNull);
    final alle = quelle.liste();
    expect(identical(alle, quelle.liste()), isTrue);
    expect((await alle).map((a) => a.nummer.wert), [
      '10-10-073-R',
      '80-10-001',
    ]);
    expect(quelle.version, 'v1');
    expect((await alle).clear, throwsUnsupportedError);

    final belaege = await quelle.liste(
      const Artikelfilter(bereich: Bereich.belag),
    );
    expect(belaege.single.holzart, robinie);
  });

  test('lädt Regeln je Artikel', () async {
    final regeln = quelle.regeln(const Artikelnummer('10-10-073-R'));
    expect(
      identical(regeln, quelle.regeln(const Artikelnummer('10-10-073-R'))),
      isTrue,
    );
    final r = await regeln;
    expect(r.version, 'v1');
    expect(quelle.version, 'v1');
    expect(r.moeglich[Beziehung.befestigung]!.single.titel, 'CLIP-FIXX');
  });

  test('Fehler werden nicht gemerkt', () async {
    const unbekannt = Artikelnummer('99-99-999');
    final erster = quelle.regeln(unbekannt);
    await expectLater(erster, throwsA(anything));
    final zweiter = quelle.regeln(unbekannt);
    expect(identical(erster, zweiter), isFalse);
    await expectLater(zweiter, throwsA(anything));
  });

  test('neue Artikeldaten verwerfen den Zwischenspeicher', () async {
    final vorher = quelle.liste();
    await vorher;
    final gemeldet = quelle.aenderungen.first;
    await dienst.ersetze(_datei('v2', [_clip]));
    expect(await gemeldet.timeout(const Duration(seconds: 10)), 'v2');
    expect(quelle.version, 'v2');

    final nachher = quelle.liste();
    expect(identical(vorher, nachher), isFalse);
    expect((await nachher).single.titel, 'CLIP-FIXX');
  });
}
