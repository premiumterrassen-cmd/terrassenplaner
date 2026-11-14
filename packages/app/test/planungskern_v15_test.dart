import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/berechnung_steuerung.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

/// Planungskern v14/v15 (Planungsregeln Alexander, 13.11.2026), Regel 16.6
/// und 17: Buchstaben an abgerundeten Ecken und Aussparungen vom Server in
/// der Zeichnung, Texte.
void main() {
  testWidgets('Umrisspunkte und Aussparungsecken aus dem Planbild', (
    tester,
  ) async {
    final planung = PlanungsSteuerung();
    final berechnung = BerechnungsSteuerung(
      planung: planung,
      berechne: (_) async => Berechnung(
        umriss: const [Punkt(0, 0), Punkt(4800, 0), Punkt(4800, 3090)],
        flaeche: 1,
        planbild: Planbild(
          umrisspunkte: const [(ort: Punkt(4800, 2090), ecke: 2, buchstabe: 4)],
          aussparungsecken: const [
            (ort: Punkt(1000, 1000), ecke: 0, buchstabe: 27),
          ],
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
    expect(z.umrisspunkte, const [
      (ort: Offset(4800, 2090), ecke: 2, name: 'E'),
    ]);
    expect(z.aussparungsecken, const [
      (ort: Offset(1000, 1000), ecke: 0, name: 'AB'),
    ]);
  });

  test('Texte zur Ecke und zur Blende', () {
    expect(de.rundungZuGross(120), contains('höchstens 120 cm'));
    expect(
      en.rundungZuGross(120),
      'Radius too large – at most 120 cm at this corner.',
    );
    expect(de.rundungAnleitung, startsWith('Ecke abrunden: Ecke wählen'));
    expect(en.rundungAnleitung, startsWith('Round a corner'));
    expect(en.rundungEckeInnen, 'inwards (cove around the corner)');
    expect(en.verblendungBogen('C–E'), 'Arc C–E');
    expect(en.verblendungAussparung('A1', 'F–G'), 'A1: F–G');
    expect(en.verblendungZusatzFrage, startsWith('Arcs of rounded corners'));
  });
}
