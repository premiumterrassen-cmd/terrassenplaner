/// Material des ganzen Terrassenanschlusses einer Fläche (M7).
library;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../artikel/ukauswahl.dart';
import '../ergebnisse/materialliste.dart';
import '../konfiguration/planungsstand.dart';
import 'regelwerk.dart';
import 'rinnen.dart';
import 'treppen.dart';
import 'uk_zusatz.dart';
import 'verblendung.dart';

/// Verblendung (M7-02), Entwässerungsrinnen (M7-03) und Treppen (M7-05)
/// der Fläche [stand] zusammen. Alle Zuschnitte aus UK-Holz (Blendenträger,
/// Treppen-UK) werden gemeinsam zuerst aus den Resten der Hölzer der
/// UK-Verlegung ([ukStuecke]) geschnitten (`zusaetzlicheLieferstuecke`,
/// F37: keine weitere UK); eine erzwungene UK-Länge gilt auch hier. Ohne
/// [ukAbstand] gibt es keine UK-Verlegung und damit keine Blendenträger.
Anschlussbedarf anschlussbedarf(
  Planungsstand stand, {
  required List<Millimeter> hoehen,
  Artikel? belag,
  Regelwerk? regelwerk,
  Artikel? uk,
  Millimeter? ukAbstand,
  List<Millimeter> ukStuecke = const [],
}) {
  final teile =
      verblendungsbedarf(
            stand,
            hoehen: hoehen,
            belag: belag,
            regelwerk: regelwerk,
            uk: ukAbstand == null ? null : uk,
          )
          .und(rinnenbedarf(stand, belag: belag, regelwerk: regelwerk))
          .und(
            treppenbedarf(stand, belag: belag, uk: uk, ukAbstand: ukAbstand),
          );
  if (uk == null) return teile;
  final holz = [
    for (final s in teile.stuecke)
      if (s.nummer == uk.nummer) s.laenge,
  ];
  return teile.und(
    Anschlussbedarf(
      bedarf: [
        for (final MapEntry(key: laenge, value: anzahl)
            in zusaetzlicheLieferstuecke(
              holz,
              ukStuecke,
              ukLieferlaengen(uk),
              fest: stand.ukLaenge,
            ).entries)
          Materialbedarf([uk], anzahl, laenge: laenge),
      ],
    ),
  );
}
