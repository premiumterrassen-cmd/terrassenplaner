@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/konfiguration/konfigurations_steuerung.dart';
import 'package:terrassenplaner_app/src/verbindung/planer_verbindung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Ende-zu-Ende gegen einen echten Router mit Hallo-Dienst (M0-12).
void main() {
  test('hallo() liefert die Begrüßung des Servers', () async {
    final health = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final healthPort = health.port;
    await health.close();
    final router = PlanerRouter.starte(
      RouterEinstellungen(
        authToken: 't',
        dienstTicket: 'k',
        port: 0,
        healthListen: '127.0.0.1:$healthPort',
      ),
    );
    addTearDown(router.stoppe);
    final dienst = await HalloDienst.starte(router);
    addTearDown(dienst.stoppe);
    final modell3d = await Modell3dDienst.starte(router);
    addTearDown(modell3d.stoppe);
    final planung = await PlanungsDienst.starte(router);
    addTearDown(planung.stoppe);
    final artikel = await ArtikelDienst.starte(
      router,
      Artikeldatei(
        quelle: 'test.xlsx',
        version: 'v1',
        eintraege: [
          Artikeleintrag(
            artikel: Artikel(
              nummer: const Artikelnummer('10-10-060-R'),
              titel: 'Diele',
              art: Artikelart.diele,
              einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
              abmessungen: Abmessungen(breite: const Millimeter(60)),
              preisBrutto: const Cent(1300),
              holzart: robinie,
              serie: premiumSelect,
            ),
          ),
          Artikeleintrag(
            artikel: Artikel(
              nummer: const Artikelnummer('50-80-006'),
              titel: 'Schutz-Vlies',
              art: Artikelart.sonstiges,
              einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
              zubehoergruppe: Zubehoergruppe.allgemein,
            ),
          ),
        ],
      ),
    );
    addTearDown(artikel.stoppe);

    final verbindung = PlanerVerbindung(
      Uri.parse('ws://127.0.0.1:${router.webSocketPort}/ws'),
    );
    expect(verbindung.adresse.port, router.webSocketPort);
    expect(
      await verbindung.hallo(),
      'Verbunden mit Terrassenplaner – ALTO HOLZ',
    );
    final glb = await verbindung.modell3dRechteck(
      const Millimeter(4000),
      const Millimeter(3000),
    );
    expect(glb, isA<Uint8List>());
    expect(
      glb,
      Modell3dDienst.rechteck(const Millimeter(4000), const Millimeter(3000)),
    );
    // M4-02/M4-14: Planung hin, Berechnung zurück – typisiert
    final berechnung = await verbindung.berechne(Planung.start);
    expect(berechnung.flaecheQuadratmeter, 14.832);
    expect(berechnung.umriss[1], const Punkt(4800, 0));
    // M5-01: Beläge mit Preisen vom Server
    final belaege = await verbindung.belaege();
    expect(belaege.version, 'v1');
    expect(belaege.vorgabe!.artikel.serie, premiumSelect);
    expect(belaege.vorgabe!.preisJeM2, const Cent(20000));
    // M6-03: Unterkonstruktionen zum Belag (die Testdatei hat keine)
    for (final belag in [null, const Artikelnummer('10-10-060-R')]) {
      final uk = await verbindung.unterkonstruktionen(belag);
      expect(uk.version, 'v1');
      expect(uk.angebote, isEmpty);
    }
    // M8-01: Zubehör der acht Gruppen
    final zubehoer = await verbindung.zubehoer();
    expect(zubehoer.version, 'v1');
    expect(
      zubehoer.gruppen[Zubehoergruppe.allgemein]!.single.titel,
      'Schutz-Vlies',
    );
  });

  test(
    'Speichern, Laden und Entwurf über den Konfigurationsdienst (M9-05)',
    () async {
      final health = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final healthPort = health.port;
      await health.close();
      final router = PlanerRouter.starte(
        RouterEinstellungen(
          authToken: 't',
          dienstTicket: 'k',
          port: 0,
          healthListen: '127.0.0.1:$healthPort',
        ),
      );
      addTearDown(router.stoppe);
      final speicher = _Speicher();
      final dienst = await KonfigurationsDienst.starte(router, speicher);
      addTearDown(dienst.stoppe);
      // M9-06: Planungsunterlagen aus derselben Ablage
      final unterlagen = await UnterlagenDienst.starte(router, speicher);
      addTearDown(unterlagen.stoppe);
      final verbindung = PlanerVerbindung(
        Uri.parse('ws://127.0.0.1:${router.webSocketPort}/ws'),
      );

      final planung = Planung([
        Terrassenflaeche(Planungsstand.start.mitForm(Terrassenform.oForm)),
        Terrassenflaeche(Planungsstand.start, haeufigkeit: 3),
      ], aktiv: 1);
      final v1 = await verbindung.speichere(planung);
      expect(
        v1,
        KonfigurationsStand(
          Konfigurationskennung.lies('2026-11-04-0001-K7QXM'),
          1,
        ),
      );
      final v2 = await verbindung.speichere(Planung.start, kennung: v1.kennung);
      expect(v2.version, 2);
      // Abnahme: geladen identisch zum gespeicherten Stand, alte Version bleibt
      expect(await verbindung.lade(v1), planung);
      expect(await verbindung.lade(v2), Planung.start);
      for (final unbekannt in [
        KonfigurationsStand(v1.kennung, 3),
        // falscher Prüfcode (M9-05b)
        KonfigurationsStand(
          Konfigurationskennung(v1.nummer, const Pruefcode('K7QXN')),
          1,
        ),
      ]) {
        await expectLater(
          verbindung.lade(unbekannt),
          throwsA(
            isA<KonfigurationNichtGefunden>().having(
              (e) => e.stand,
              'stand',
              unbekannt,
            ),
          ),
        );
      }
      // andere Fehler des Dienstes werden durchgereicht
      await expectLater(
        verbindung.lade(
          KonfigurationsStand(
            const Konfigurationskennung(
              Konfigurationsnummer('2026-02-30-0001'),
              Pruefcode('K7QXM'),
            ),
            1,
          ),
        ),
        throwsA(isNot(isA<KonfigurationNichtGefunden>())),
      );
      await expectLater(
        verbindung.speichere(
          Planung.start,
          kennung: Konfigurationskennung.lies('2026-11-04-0099-K7QXM'),
        ),
        throwsA(anything),
      );

      const schluessel = '0123456789abcdef0123456789abcdef';
      expect(await verbindung.entwurf(schluessel), isNull);
      await verbindung.merkeEntwurf(schluessel, planung);
      expect(await verbindung.entwurf(schluessel), (
        planung: planung,
        bezug: null,
      ));
      await verbindung.merkeEntwurf(schluessel, Planung.start, bezug: v2);
      expect(await verbindung.entwurf(schluessel), (
        planung: Planung.start,
        bezug: v2,
      ));
      await expectLater(verbindung.entwurf('kein'), throwsA(anything));

      // M9-06: PDF der gespeicherten Version
      final pdf = await verbindung.unterlagen(v1, 'en');
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      await expectLater(
        verbindung.unterlagen(KonfigurationsStand(v1.kennung, 9), 'de'),
        throwsA(anything),
      );
    },
  );

  test('ohne Server: Fehler statt Hängen', () async {
    final frei = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = frei.port;
    await frei.close();
    final verbindung = PlanerVerbindung(Uri.parse('ws://127.0.0.1:$port/ws'));
    await expectLater(verbindung.speichere(Planung.start), throwsA(anything));
  });

  test('Packed-Nutzlast materialisiert als ein Binärargument', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(PlanerVerbindung.verpacke(bytes).arguments, [bytes]);
  });
}

/// Konfigurationsspeicher im Arbeitsspeicher: Die App-Tests laufen ohne die
/// native ObjectBox-Bibliothek; ObjectBox selbst prüfen die Server-Tests.
final class _Speicher implements KonfigurationsSpeicher {
  final _versionen = <String, List<Uint8List>>{};
  final _entwuerfe = <String, Entwurf>{};

  /// Jede Nummer bekommt hier denselben Prüfcode; ein anderer gilt als
  /// unbekannt.
  @override
  KonfigurationsStand speichere(
    Uint8List inhalt, {
    Konfigurationskennung? kennung,
  }) {
    final k =
        kennung ??
        Konfigurationskennung(
          Konfigurationsnummer.vergib(
            DateTime(2026, 11, 4),
            _versionen.length + 1,
          ),
          const Pruefcode('K7QXM'),
        );
    final liste =
        _versionen[k.wert] ??
        (kennung == null
            ? (_versionen[k.wert] = [])
            : throw KonfigurationUnbekannt(k.nummer));
    liste.add(inhalt);
    return KonfigurationsStand(k, liste.length);
  }

  @override
  Uint8List lies(KonfigurationsStand stand, {bool ohnePruefcode = false}) {
    final liste = _versionen[stand.kennung.wert] ?? const [];
    if (stand.version > liste.length) {
      throw KonfigurationUnbekannt(stand.nummer, stand.version);
    }
    return liste[stand.version - 1];
  }

  @override
  void merkeEntwurf(
    String schluessel,
    Uint8List inhalt, {
    KonfigurationsStand? bezug,
  }) => _entwuerfe[schluessel] = (inhalt: inhalt, bezug: bezug);

  @override
  Entwurf? entwurf(String schluessel) => _entwuerfe[schluessel];
}
