import 'dart:typed_data';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Uint8List _aenderung(int seq) => baueAenderung(
  schluessel: 'k1:$seq',
  knoten: 'k1',
  seq: seq,
  entitaet: 'Benutzer',
  uid: '0192f3a0-0000-7000-8000-00000000000$seq',
  partition: 'global',
  hlc: '1760000000000-0-k1',
  art: 'anlegen',
);

void main() {
  group('Aenderung (ObjectBox-Speicherformat)', () {
    test('Bauen und Lesen ergeben dieselben Felder', () {
      final sicht = AenderungSicht(_aenderung(7));
      expect(sicht.schluessel, 'k1:7');
      expect(sicht.knoten, 'k1');
      expect(sicht.seq, 7);
      expect(sicht.entitaet, 'Benutzer');
      expect(sicht.uid, '0192f3a0-0000-7000-8000-000000000007');
      expect(sicht.partition, 'global');
      expect(sicht.hlc, '1760000000000-0-k1');
      expect(sicht.art, 'anlegen');
    });

    test('Schemaname entspricht der ObjectBox-Entität', () {
      expect(AenderungSicht.schemaName, 'Aenderung');
    });
  });

  group('Stapel', () {
    test('enthält Schema und alle Einträge in Reihenfolge', () {
      final eintraege = [for (var i = 1; i <= 3; i++) _aenderung(i)];
      final stapel = Stapel(Stapel.baue(AenderungSicht.schemaName, eintraege));
      expect(stapel.schema, 'Aenderung');
      expect(stapel.laenge, 3);
      expect(stapel.eintraege, eintraege);
      expect(AenderungSicht(stapel[2]).seq, 3);
    });

    test('Einträge sind Ausschnitte des Stapel-Puffers (keine Kopie)', () {
      final bytes = Stapel.baue('Aenderung', [_aenderung(1), _aenderung(2)]);
      final eintrag = Stapel(bytes)[1];
      expect(AenderungSicht(eintrag).schluessel, 'k1:2');
      // Gleicher Speicher: eine Änderung im Stapel ist im Eintrag sichtbar.
      final vorher = eintrag[0];
      bytes[eintrag.offsetInBytes - bytes.offsetInBytes] ^= 0xff;
      expect(eintrag[0], vorher ^ 0xff);
    });

    test('leerer Stapel', () {
      final stapel = Stapel(Stapel.baue('Aenderung', const []));
      expect(stapel.laenge, 0);
      expect(stapel.eintraege, isEmpty);
    });

    test('leerer Eintrag bleibt leer', () {
      final stapel = Stapel(Stapel.baue('Aenderung', [Uint8List(0)]));
      expect(stapel[0], isEmpty);
    });
  });

  test('PPT-Kennung für typisierte Nutzlasten', () {
    expect(WampNamen.pptSchema, startsWith('x_'));
    expect(WampNamen.pptSerializer, 'flatbuffers');
  });

  test('Ausschnitt-Leser belegt einen Offset (4 Byte) im Vektor', () {
    expect(const AusschnittLeser().size, 4);
  });
}
