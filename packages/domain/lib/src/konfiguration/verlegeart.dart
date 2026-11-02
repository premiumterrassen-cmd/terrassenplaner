import '../artikel/einheiten.dart';

/// Verlegeart des Belags (Fachkonzept 2.3, M5-04): wo die Stöße der
/// Dielenreihen liegen. Die Stoßlinien laufen quer zur Verlegerichtung über
/// die ganze Fläche; jede Reihe wird an ihnen geschnitten (`reihenstuecke`).
///
/// Raster ist die Dielenlänge, mit der verlegt wird ([stossraster]). Die
/// Muster stimmen mit den Zuschnittlisten des alten Planers überein (F01,
/// F06–F12): bei 480 cm Halbverband 240 + 240 cm in jeder zweiten Reihe,
/// Drittelverband 160 + 320 cm und 320 + 160 cm; bei 800 cm mit 6-m-Dielen
/// Fugenschnitt 600 + 200 cm, Halbverband im Wechsel 600 + 200 und
/// 300 + 500 cm, Drittelverband 600 + 200, 200 + 600 und 400 + 400 cm,
/// Wechselverband 600 + 200 und 200 + 600 cm.
enum Verlegeart {
  /// „Auf Fuge geschnitten“: alle Stöße in einer Linie (Vorgabe).
  fugenschnitt(0),

  /// Jede zweite Reihe um eine halbe Diele versetzt.
  halbverband(1),

  /// Reihe für Reihe um ein Drittel der Diele versetzt.
  drittelverband(2),

  /// Jede zweite Reihe beginnt mit der ganzen Diele an der Gegenseite.
  wechselverband(3);

  const Verlegeart(this.nummer);

  /// Nummer im Transportformat (FlatBuffer des Planungsstands).
  final int nummer;

  /// Stoßlinien der Reihe [reihe] (0 = erste Reihe am Ausgangspunkt) in einer
  /// Fläche, die in Verlegerichtung von [von] bis [bis] reicht, aufsteigend
  /// und nur im Inneren der Fläche.
  List<Millimeter> stoesse(
    int reihe,
    Millimeter von,
    Millimeter bis,
    Millimeter raster,
  ) {
    final r = raster.mm;
    // Leere Flächen und negative Raster ergeben über die Anzahl keine Linien.
    if (r == 0) return const [];
    final int erste;
    final int anzahl;
    if (this == wechselverband && reihe.isOdd) {
      anzahl = (bis.mm - von.mm - 1) ~/ r;
      erste = bis.mm - anzahl * r;
    } else {
      final versatz = switch (this) {
        halbverband => reihe.isOdd ? r ~/ 2 : 0,
        drittelverband => r * (reihe % 3) ~/ 3,
        _ => 0,
      };
      erste = von.mm + (versatz == 0 ? r : versatz);
      anzahl = erste < bis.mm ? (bis.mm - erste - 1) ~/ r + 1 : 0;
    }
    return [for (var k = 0; k < anzahl; k++) Millimeter(erste + k * r)];
  }
}

/// Raster der Stoßlinien: die längste erlaubte Lieferlänge [laengste] (bei
/// erzwungener Länge diese), höchstens aber die [ausdehnung] der Fläche in
/// Verlegerichtung – passt eine Reihe in eine Diele, wird um Teile der Reihe
/// versetzt (480 cm Halbverband: 240 cm, nicht 250 cm).
Millimeter stossraster(Millimeter ausdehnung, Millimeter laengste) =>
    ausdehnung < laengste ? ausdehnung : laengste;
