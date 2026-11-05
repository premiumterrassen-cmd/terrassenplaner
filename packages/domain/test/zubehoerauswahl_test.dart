import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikel _zubehoer(String nummer, String titel, Zubehoergruppe? gruppe) =>
    Artikel(
      nummer: Artikelnummer(nummer),
      titel: titel,
      art: Artikelart.sonstiges,
      einheit: Verkaufseinheit(Mengeneinheit.stueck),
      preisBrutto: const Cent(1990),
      zubehoergruppe: gruppe,
      bilder: const ['bild.webp'],
    );

void main() {
  group('Zubehörgruppe (M8-01)', () {
    test('acht Gruppen in der Reihenfolge des alten Planers', () {
      expect(
        [for (final g in Zubehoergruppe.values) g.datenname],
        [
          'Allgemein',
          'Anlieferung',
          'Clips & Schrauben',
          'Höhenausgleich',
          'Pads & EPDM Bänder',
          'Rhombusleisten',
          'Terrassenfliesen',
          'Terrassenöl RIBOL',
        ],
      );
    });

    test('liest die Einträge der Upload-Datei', () {
      for (final g in Zubehoergruppe.values) {
        expect(Zubehoergruppe.lies(g.datenname), g);
      }
      expect(
        Zubehoergruppe.lies(' Höhenausgleich '),
        Zubehoergruppe.hoehenausgleich,
      );
      expect(Zubehoergruppe.lies('Terrassenöl'), isNull);
      expect(Zubehoergruppe.lies(''), isNull);
    });
  });

  group('Zubehörauswahl (M8-01)', () {
    final vlies = _zubehoer(
      '50-80-006',
      'Schutz-Vlies',
      Zubehoergruppe.allgemein,
    );
    final bit = _zubehoer('50-80-002', 'Bit TX20', Zubehoergruppe.allgemein);
    final oel = _zubehoer(
      '568-250',
      'Öl 2,5 Liter',
      Zubehoergruppe.terrassenoel,
    );
    final ohne = _zubehoer('99-99-999', 'Kein Zubehör', null);

    test('Gruppen fest, Artikel in Datenreihenfolge, ohne Gruppe fehlt', () {
      final auswahl = Zubehoerauswahl.aus('v1', [vlies, ohne, oel, bit]);
      expect(auswahl.version, 'v1');
      expect(auswahl.gruppen.keys, Zubehoergruppe.values);
      expect(auswahl.gruppen[Zubehoergruppe.allgemein], [vlies, bit]);
      expect(auswahl.gruppen[Zubehoergruppe.terrassenoel], [oel]);
      expect(auswahl.gruppen[Zubehoergruppe.rhombusleisten], isEmpty);
      expect(auswahl.artikel(const Artikelnummer('568-250')), oel);
      expect(auswahl.artikel(const Artikelnummer('99-99-999')), isNull);
      expect(
        () => auswahl.gruppen[Zubehoergruppe.allgemein]!.add(oel),
        throwsUnsupportedError,
      );
      expect(
        () => auswahl.gruppen.remove(Zubehoergruppe.allgemein),
        throwsUnsupportedError,
      );
    });

    test('fehlende Gruppen werden leer ergänzt', () {
      final auswahl = Zubehoerauswahl('v2', {
        Zubehoergruppe.terrassenoel: [oel],
      });
      expect(auswahl.gruppen.keys, Zubehoergruppe.values);
      expect(auswahl.gruppen[Zubehoergruppe.allgemein], isEmpty);
    });

    test('JSON hin und zurück samt Gruppe des Artikels', () {
      final auswahl = Zubehoerauswahl.aus('v1', [vlies, oel, bit]);
      final json = auswahl.alsJson();
      expect((json['gruppen']! as Map).keys, [
        for (final g in Zubehoergruppe.values) g.name,
      ]);
      final zurueck = Zubehoerauswahl.ausJson(json, {robinie.id: robinie});
      expect(zurueck.version, 'v1');
      expect(zurueck.gruppen[Zubehoergruppe.allgemein], [vlies, bit]);
      final o = zurueck.gruppen[Zubehoergruppe.terrassenoel]!.single;
      expect(o.zubehoergruppe, Zubehoergruppe.terrassenoel);
      expect(o.titel, 'Öl 2,5 Liter');
      expect(o.preisBrutto, const Cent(1990));
      expect(o.bilder, ['bild.webp']);
      expect(artikelAlsJson(ohne)['zubehoergruppe'], isNull);
      expect(
        artikelAusJson(artikelAlsJson(ohne), const {}).zubehoergruppe,
        isNull,
      );
    });
  });
}
