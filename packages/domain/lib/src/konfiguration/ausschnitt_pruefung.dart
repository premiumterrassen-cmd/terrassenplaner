import '../geometrie/flaeche.dart';
import '../geometrie/mengen.dart';
import 'planungsstand.dart';

/// Was an einem Ausschnitt nicht stimmt (Fachkonzept 1.4, M4-12).
enum AusschnittProblem {
  /// „Der Ausschnitt darf nicht außerhalb der Terrasse sein!“
  ausserhalb,

  /// Zwei Ausschnitte überschneiden sich (Berührung ist erlaubt).
  kollision,

  /// Die Ausschnitte zerteilen die Terrasse in mehrere Stücke.
  teilung,
}

/// Eine Meldung zu Ausschnitt [ausschnitt]; bei einer Kollision ist
/// [anderer] der zweite Ausschnitt.
typedef AusschnittMeldung = ({
  AusschnittProblem problem,
  int ausschnitt,
  int? anderer,
});

/// Prüft die Ausschnitte des [stand]es (M4-12) mit dem Geometrie-Kern: jeder
/// liegt ganz in der Terrasse, keine zwei überschneiden sich, und die
/// Terrasse bleibt ein zusammenhängendes Stück. Leer = alles in Ordnung.
List<AusschnittMeldung> pruefeAusschnitte(Planungsstand stand) {
  final terrasse = Flaeche(stand.kontur);
  final flaechen = [for (final a in stand.ausschnitte) Flaeche(a.kontur)];
  final meldungen = <AusschnittMeldung>[];
  for (var i = 0; i < flaechen.length; i++) {
    if (!terrasse.umschliesst(flaechen[i])) {
      meldungen.add((
        problem: AusschnittProblem.ausserhalb,
        ausschnitt: i,
        anderer: null,
      ));
    }
    for (var j = 0; j < i; j++) {
      if (flaechen[i].ueberschneidet(flaechen[j])) {
        meldungen.add((
          problem: AusschnittProblem.kollision,
          ausschnitt: i,
          anderer: j,
        ));
      }
    }
  }
  // Teilung: nacheinander abziehen; der Ausschnitt, ab dem es mehrere
  // Stücke sind, ist der Grund
  var rest = [terrasse];
  for (var i = 0; i < flaechen.length; i++) {
    rest = verknuepfe(rest, [flaechen[i]], Verknuepfung.differenz);
    if (rest.length > 1) {
      meldungen.add((
        problem: AusschnittProblem.teilung,
        ausschnitt: i,
        anderer: null,
      ));
      break;
    }
  }
  return meldungen;
}
