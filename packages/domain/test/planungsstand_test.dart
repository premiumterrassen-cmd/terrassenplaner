import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

RechteckGrundriss _rechteck(int ab, int bc) =>
    RechteckGrundriss(Millimeter(ab), Millimeter(bc));

void main() {
  group('Rechteck (M4-02)', () {
    test('Start wie im alten Planer: 480 × 309 cm, 14,832 m²', () {
      const r = RechteckGrundriss.start;
      expect([r.ab.mm, r.bc.mm], [4800, 3090]);
      expect(r.form, Terrassenform.rechteck);
      expect(r.masse, [const Millimeter(4800), const Millimeter(3090)]);
      expect(r.kontur.flaeche, 14832000);
      expect(r.kontur.punkte, const [
        Punkt(0, 0),
        Punkt(4800, 0),
        Punkt(4800, 3090),
        Punkt(0, 3090),
      ]);
      expect(Planungsstand.start.grundriss, r);
    });

    test('Fläche folgt den Maßen', () {
      expect(_rechteck(5400, 3600).kontur.flaeche, 19440000);
      expect(_rechteck(500, 20000).kontur.flaeche, 10000000);
    });

    test('Seiten zwischen 50 und 2000 cm', () {
      const text = 'muss zwischen 50 und 2000 cm liegen';
      expect(() => _rechteck(499, 3000), wirftArgumentFehler('ab', 499, text));
      expect(
        () => _rechteck(3000, 20001),
        wirftArgumentFehler('bc', 20001, text),
      );
      expect(Grundriss.kleinsteSeite, const Millimeter(500));
      expect(Grundriss.groessteSeite, const Millimeter(20000));
    });

    test('Gleichheit nach Maßen', () {
      expect(_rechteck(4000, 3000), _rechteck(4000, 3000));
      expect(_rechteck(4000, 3000).hashCode, _rechteck(4000, 3000).hashCode);
      expect(_rechteck(4000, 3000) == _rechteck(4000, 3001), isFalse);
      expect(_rechteck(4000, 3000) == _rechteck(4001, 3000), isFalse);
      expect(_rechteck(4000, 3000) == Object(), isFalse);
    });

    test('aus Form und Maßen', () {
      expect(
        Grundriss.aus(Terrassenform.rechteck, const [
          Millimeter(4000),
          Millimeter(3000),
        ]),
        _rechteck(4000, 3000),
      );
      expect(
        () => Grundriss.aus(Terrassenform.rechteck, const [Millimeter(4000)]),
        wirftArgumentFehler('masse', 1, 'Rechteck braucht zwei Maße'),
      );
      expect(Terrassenform.rechteck.nummer, 0);
    });
  });

  group('Planungsstand', () {
    test('Gleichheit über den Grundriss, Kopie mit neuem Grundriss', () {
      const start = Planungsstand.start;
      expect(start, const Planungsstand());
      expect(start.hashCode, RechteckGrundriss.start.hashCode);
      final neu = start.mitGrundriss(_rechteck(5400, 3600));
      expect(neu.grundriss, _rechteck(5400, 3600));
      expect(neu == start, isFalse);
      expect(neu, Planungsstand(grundriss: _rechteck(5400, 3600)));
      expect(start == Object(), isFalse);
      final v = Verlauf(start)..setze(const Planungsstand());
      expect(v.kannRueckgaengig, isFalse);
    });

    test('Transportformat hin und zurück', () {
      final stand = Planungsstand(grundriss: _rechteck(5400, 3600));
      final bytes = stand.zuBytes();
      expect(Planungsstand.ausBytes(bytes), stand);
      expect(Planungsstand.schema, 1);
      final puffer = fb.BufferContext.fromBytes(bytes);
      final wurzel = puffer.derefObject(0);
      expect(const fb.Uint16Reader().vTableGet(puffer, wurzel, 4, 0), 1);
    });

    test('kaputte Nachrichten werden abgewiesen', () {
      Uint8List tabelle(void Function(fb.Builder) inhalt) {
        final fbb = fb.Builder();
        inhalt(fbb);
        fbb.finish(fbb.endTable());
        return fbb.buffer;
      }

      expect(
        () => Planungsstand.ausBytes(tabelle((fbb) => fbb.startTable(2))),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Planungsstand ohne Grundriss',
          ),
        ),
      );
      Uint8List mitGrundriss(int form, List<int> masse) => tabelle((fbb) {
        final masseOrt = fbb.writeListInt32(masse);
        fbb
          ..startTable(2)
          ..addUint8(0, form)
          ..addOffset(1, masseOrt);
        final ort = fbb.endTable();
        fbb
          ..startTable(2)
          ..addOffset(1, ort);
      });
      expect(
        () => Planungsstand.ausBytes(mitGrundriss(7, [4000, 3000])),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannte Terrassenform 7',
          ),
        ),
      );
      expect(
        () => Planungsstand.ausBytes(mitGrundriss(0, [4000])),
        throwsArgumentError,
      );
      expect(
        () => Planungsstand.ausBytes(mitGrundriss(0, [4000, 100])),
        throwsArgumentError,
      );
      expect(
        Planungsstand.ausBytes(mitGrundriss(0, [4000, 3000])).grundriss,
        _rechteck(4000, 3000),
      );
    });
  });

  group('Berechnung', () {
    test('Transportformat hin und zurück', () {
      final b = Berechnung(
        umriss: const [Punkt(0, 0), Punkt(4800.5, 0), Punkt(4800.5, 3090)],
        flaeche: 14832000,
      );
      final zurueck = Berechnung.ausBytes(b.zuBytes());
      expect(zurueck.umriss, b.umriss);
      expect(zurueck.flaeche, 14832000);
      expect(zurueck.flaecheQuadratmeter, 14.832);
      expect(() => b.umriss.add(Punkt.ursprung), throwsUnsupportedError);
    });

    test('leere Nachricht: kein Umriss, Fläche 0', () {
      final fbb = fb.Builder()..startTable(2);
      fbb.finish(fbb.endTable());
      final leer = Berechnung.ausBytes(fbb.buffer);
      expect(leer.umriss, isEmpty);
      expect(leer.flaeche, 0);
    });
  });

  test('WAMP-Name der Berechnung', () {
    expect(
      WampNamen.planungBerechnen,
      'de.robinienwelt.terrassenplaner.kunde.planung.berechnen',
    );
  });
}
