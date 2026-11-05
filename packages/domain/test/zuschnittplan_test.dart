import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikel _artikel(String nummer, String titel) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: titel,
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  holzart: robinie,
  serie: basic,
);

final _diele = _artikel('10-10-073-R', 'Diele');
final _uk = _artikel('10-10-031', 'UK');

Lieferdiele _d(int laenge, List<int> schnitte) =>
    Lieferdiele(Millimeter(laenge), [for (final s in schnitte) Millimeter(s)]);

List<String> _text(Zuschnittplan p) => [for (final z in p.zeilen) '$z'];

void main() {
  test('gleiche Schnitte zusammen, Häufigkeit als Menge; Artikel in der '
      'Reihenfolge, längste Ausgangslänge, dann größte Menge zuerst', () {
    final p = Zuschnittplan.aus([
      (artikel: _diele, stueck: _d(4000, [2000, 2000]), anzahl: 1),
      (artikel: _uk, stueck: _d(4000, [3090]), anzahl: 13),
      (artikel: _diele, stueck: _d(6000, [6000]), anzahl: 2),
      (artikel: _diele, stueck: _d(4000, [2000, 2000]), anzahl: 23),
      (artikel: _diele, stueck: _d(6000, [5000]), anzahl: 3),
      (artikel: _diele, stueck: _d(4000, [3000]), anzahl: 24),
      (artikel: _diele, stueck: _d(4000, [3500]), anzahl: 24),
    ]);
    expect(_text(p), [
      '3 × 6000: 5000 (10-10-073-R)',
      '2 × 6000: 6000 (10-10-073-R)',
      '24 × 4000: 2000 + 2000 (10-10-073-R)',
      '24 × 4000: 3000 (10-10-073-R)',
      '24 × 4000: 3500 (10-10-073-R)',
      '13 × 4000: 3090 (10-10-031)',
    ]);
    expect(p.zeilen.first.titel, 'Diele');
    expect(p.zeilen.last.titel, 'UK');
    expect(p.istLeer, isFalse);
    expect(Zuschnittplan.leer.istLeer, isTrue);
    expect(Zuschnittplan.aus(const []), Zuschnittplan.leer);
    expect(p.zeilen.clear, throwsUnsupportedError);
    expect(() => p.zeilen.first.schnitte.clear(), throwsUnsupportedError);
  });

  test('Gleichheit über alle Felder', () {
    Zuschnittzeile zeile({
      String nummer = 'a',
      String titel = 't',
      int laenge = 4000,
      int menge = 1,
      List<int> schnitte = const [2000],
    }) => Zuschnittzeile(
      nummer: Artikelnummer(nummer),
      titel: titel,
      ausgangslaenge: Millimeter(laenge),
      menge: menge,
      schnitte: [for (final s in schnitte) Millimeter(s)],
    );
    final z = zeile();
    expect(z, zeile());
    expect(z.hashCode, zeile().hashCode);
    for (final andere in [
      zeile(nummer: 'b'),
      zeile(titel: 'u'),
      zeile(laenge: 5000),
      zeile(menge: 2),
      zeile(schnitte: const [2001]),
      zeile(schnitte: const [2000, 1000]),
    ]) {
      expect(z, isNot(andere));
    }
    expect(z, isNot(Object()));
    expect(Zuschnittplan([z]), Zuschnittplan([zeile()]));
    expect(Zuschnittplan([z]).hashCode, Zuschnittplan([zeile()]).hashCode);
    expect(Zuschnittplan([z]), isNot(Zuschnittplan([zeile(menge: 3)])));
    expect(Zuschnittplan([z]), isNot(Zuschnittplan([z, z])));
    expect(Zuschnittplan([z]), isNot(Object()));
  });

  test('Berechnung: Plätze 167 und 168 hin und zurück, in der Kopie mit '
      'Planung; fehlen: leer', () {
    final belag = Zuschnittplan.aus([
      (artikel: _diele, stueck: _d(4000, [2000, 2000]), anzahl: 24),
    ]);
    final uk = Zuschnittplan.aus([
      (artikel: _uk, stueck: _d(4000, [3090]), anzahl: 22),
    ]);
    final b = Berechnung(
      umriss: const [],
      flaeche: 1,
    ).mitPlanung(1, zuschnittBelag: belag, zuschnittUk: uk);
    final zurueck = Berechnung.ausBytes(b.zuBytes());
    expect(zurueck.zuschnittBelag, belag);
    expect(zurueck.zuschnittUk, uk);
    expect(b.zuschnittBelag, belag);
    final ohne = Berechnung.ausBytes(
      Berechnung(umriss: const [], flaeche: 0).zuBytes(),
    );
    expect(ohne.zuschnittBelag.istLeer, isTrue);
    expect(ohne.zuschnittUk.istLeer, isTrue);
    expect(b.mitPlanung(1).zuschnittUk.istLeer, isTrue);
    // alte Puffer ohne die Felder und Zeilen ohne Werte
    final fbb = fb.Builder()..startTable(0);
    final leer = fbb.endTable();
    final zeilen = fbb.writeList([leer]);
    fbb
      ..startTable(1)
      ..addOffset(0, zeilen);
    final plan = fbb.endTable();
    fbb
      ..startTable(169)
      ..addOffset(168, plan);
    fbb.finish(fbb.endTable());
    final alt = Berechnung.ausBytes(fbb.buffer);
    expect(alt.zuschnittBelag.istLeer, isTrue);
    expect('${alt.zuschnittUk.zeilen.single}', '0 × 0:  ()');
  });
}
