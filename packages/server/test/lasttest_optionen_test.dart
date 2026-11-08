import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

Matcher _hilfe = throwsA(
  isA<FormatException>().having(
    (f) => f.message,
    'message',
    LasttestOptionen.hilfe,
  ),
);

void main() {
  test('artikeldatei <pfad>', () {
    final o = LasttestOptionen.lies(['artikeldatei', '/tmp/a.json']);
    expect(
      o,
      isA<ArtikeldateiSchreiben>().having((a) => a.pfad, 'pfad', '/tmp/a.json'),
    );
  });

  test('lauf mit Vorgaben', () {
    final o = LasttestOptionen.lies(['lauf', '--url', 'ws://x/ws']) as Lauf;
    expect(o.url, 'ws://x/ws');
    expect(o.pid, isNull);
    expect(o.dauer, const Duration(seconds: 60));
    expect(o.faktor, 1);
    expect(o.szenarien, isEmpty);
    expect(o.ausgabe, isNull);
  });

  test('lauf mit allen Angaben, Szenarien mehrfach', () {
    final o = LasttestOptionen.lies([
      'lauf',
      '--pid',
      '42',
      '--dauer',
      '10',
      '--faktor',
      '0.5',
      '--szenario',
      'nutzer',
      '--szenario',
      'gross',
      '--ausgabe',
      'b.json',
      '--url',
      'ws://y/ws',
    ]) as Lauf;
    expect(o.url, 'ws://y/ws');
    expect(o.pid, 42);
    expect(o.dauer, const Duration(seconds: 10));
    expect(o.faktor, 0.5);
    expect(o.szenarien, ['nutzer', 'gross']);
    expect(o.ausgabe, 'b.json');
  });

  test('Fehler zeigen die Hilfe', () {
    expect(() => LasttestOptionen.lies(const []), _hilfe);
    expect(() => LasttestOptionen.lies(['artikeldatei']), _hilfe);
    expect(() => LasttestOptionen.lies(['artikeldatei', 'a', 'b']), _hilfe);
    expect(() => LasttestOptionen.lies(['unbekannt', 'x']), _hilfe);
    expect(() => LasttestOptionen.lies(['lauf']), _hilfe);
    expect(() => LasttestOptionen.lies(['lauf', '--url']), _hilfe);
    expect(
      () => LasttestOptionen.lies(['lauf', '--url', 'u', '--x', '1']),
      _hilfe,
    );
    expect(() => LasttestOptionen.lies(['lauf', '--pid', '1']), _hilfe);
    expect(
      () => LasttestOptionen.lies(['lauf', '--url', 'u', '--pid', 'x']),
      throwsFormatException,
    );
    expect(LasttestOptionen.hilfe, startsWith('Aufruf: lasttest.dart'));
  });
}
