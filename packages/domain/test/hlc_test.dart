import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Hlc', () {
    test('Textform sortierbar und umkehrbar', () {
      const hlc = Hlc(1790000000000, 7, 'knoten-a');
      expect(hlc.toString(), '1790000000000-0007-knoten-a');
      expect(Hlc.ausText('1790000000000-0007-knoten-a'), hlc);
      expect(const Hlc(5, 1, 'k').toString(), '0000000000005-0001-k');
    });

    test('ungültiger Text wird abgewiesen', () {
      expect(
        () => Hlc.ausText('123-4'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Ungültiger HLC',
          ),
        ),
      );
    });

    test('Reihenfolge: Millisekunden, dann Zähler, dann Knoten', () {
      expect(const Hlc(2, 0, 'a').compareTo(const Hlc(1, 9, 'z')), 1);
      expect(const Hlc(1, 2, 'a').compareTo(const Hlc(1, 1, 'z')), 1);
      expect(const Hlc(1, 1, 'b').compareTo(const Hlc(1, 1, 'a')), 1);
      expect(const Hlc(1, 1, 'a').compareTo(const Hlc(1, 1, 'a')), 0);
      expect(const Hlc(1, 1, 'a').compareTo(const Hlc(1, 1, 'b')), -1);
    });

    test('Gleichheit und Hashcode', () {
      expect(const Hlc(1, 2, 'a') == const Hlc(1, 2, 'a'), isTrue);
      expect(const Hlc(1, 2, 'a') == const Hlc(1, 2, 'b'), isFalse);
      // ignore: unrelated_type_equality_checks
      expect(const Hlc(1, 2, 'a') == '1', isFalse);
      expect(const Hlc(1, 2, 'a').hashCode, const Hlc(1, 2, 'a').hashCode);
    });
  });

  group('HlcUhr.jetzt', () {
    test('neue Millisekunde: Zähler 0', () {
      var t = 1000;
      final uhr = HlcUhr(
        'a',
        uhr: () => DateTime.fromMillisecondsSinceEpoch(t),
      );
      expect(uhr.jetzt(), const Hlc(1000, 0, 'a'));
      t = 1001;
      expect(uhr.jetzt(), const Hlc(1001, 0, 'a'));
    });

    test('gleiche oder rückwärts laufende Uhr: Zähler steigt', () {
      var t = 1000;
      final uhr = HlcUhr(
        'a',
        uhr: () => DateTime.fromMillisecondsSinceEpoch(t),
      );
      uhr.jetzt();
      expect(uhr.jetzt(), const Hlc(1000, 1, 'a'));
      t = 900;
      expect(uhr.jetzt(), const Hlc(1000, 2, 'a'));
    });

    test('ohne Uhr: aktuelle Zeit, Knoten bleibt erhalten', () {
      final uhr = HlcUhr('k');
      expect(uhr.knoten, 'k');
      expect(
        uhr.jetzt().millis,
        closeTo(DateTime.now().millisecondsSinceEpoch, 1000),
      );
    });
  });

  group('HlcUhr.empfange', () {
    HlcUhr uhrBei(int t) =>
        HlcUhr('a', uhr: () => DateTime.fromMillisecondsSinceEpoch(t));

    test('physische Zeit am größten: Zähler 0', () {
      expect(
        uhrBei(500).empfange(const Hlc(100, 9, 'b')),
        const Hlc(500, 0, 'a'),
      );
    });

    test('fremder Zeitstempel am größten: dessen Zähler + 1', () {
      expect(
        uhrBei(100).empfange(const Hlc(500, 3, 'b')),
        const Hlc(500, 4, 'a'),
      );
    });

    test('eigener letzter Zeitstempel am größten: eigener Zähler + 1', () {
      final uhr = uhrBei(100);
      uhr.empfange(const Hlc(800, 5, 'b')); // letzter = 800/6
      expect(uhr.empfange(const Hlc(700, 9, 'c')), const Hlc(800, 7, 'a'));
    });

    test('eigener und fremder gleich: größerer Zähler + 1', () {
      final uhr = uhrBei(100);
      uhr.empfange(const Hlc(800, 2, 'b')); // letzter = 800/3
      expect(uhr.empfange(const Hlc(800, 9, 'c')), const Hlc(800, 10, 'a'));
      expect(uhr.empfange(const Hlc(800, 1, 'c')), const Hlc(800, 11, 'a'));
    });

    test('Ergebnis liegt nach beiden', () {
      final uhr = uhrBei(100);
      final vorher = uhr.jetzt();
      const fremd = Hlc(150, 2, 'b');
      final neu = uhr.empfange(fremd);
      expect(neu.compareTo(vorher), 1);
      expect(neu.compareTo(fremd), 1);
    });
  });
}
