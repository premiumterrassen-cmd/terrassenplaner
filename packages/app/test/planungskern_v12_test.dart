import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/anschluss.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

/// Planungskern v12 (Planungsregeln Alexander, 12.11.2026), Abschnitt 14:
/// Bögen und Riegel vom Server in der Zeichnung, Hinweise zur Blende am
/// Bogen.
void main() {
  testWidgets('Bögen und Riegel aus dem Planbild', (tester) async {
    final planung = PlanungsSteuerung();
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: (_) async => Berechnung(
        umriss: const [Punkt(0, 0), Punkt(4800, 0), Punkt(4800, 3090)],
        flaeche: 1,
        planbild: Planbild(
          boegen: const [
            (
              seite: 1,
              laenge: 3530,
              radius: 2000,
              scheitel: Punkt(5530, 1545),
              aussen: Punkt(1, 0),
            ),
          ],
          riegel: const [(von: Punkt(40, 1000), bis: Punkt(395, 1000))],
        ),
      ),
    );
    addTearDown(() {
      berechnung.dispose();
      planung.dispose();
    });
    planung.setze(planung.aktuell.mitGewerblich(true));
    await tester.pump();
    final z = berechnung.zeichnung;
    expect(z.boegen, const [
      (
        seite: 1,
        laenge: 3530.0,
        radius: 2000.0,
        scheitel: Offset(5530, 1545),
        aussen: Offset(1, 0),
      ),
    ]);
    expect(z.riegel, const [(Offset(40, 1000), Offset(395, 1000))]);
  });

  test('Hinweise zur Blende am Bogen unter 4.2', () {
    expect(
      zurVerblendung,
      containsAll([
        Anschlussmeldung.bogenblende,
        Anschlussmeldung.bogenblendeRiegel,
      ]),
    );
    expect(
      anschlussmeldungText(de, Anschlussmeldung.bogenblende),
      startsWith('Blende am Bogen aus senkrechten Stücken'),
    );
    expect(
      anschlussmeldungText(en, Anschlussmeldung.bogenblendeRiegel),
      startsWith('Cladding along the arc higher than 30 cm'),
    );
    expect(de.bogenMass('3,53 m', '2,00 m'), 'Bogen 3,53 m · R 2,00 m');
    expect(de.rundungInnen, 'innen');
  });
}
