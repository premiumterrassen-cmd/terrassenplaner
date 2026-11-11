/// Bohrsenker als optionales Angebot – Planungsregeln Alexander
/// (Planungskern v6, 11.11.2026) Regel 4.5.
library;

import '../artikel/artikel.dart';
import '../ergebnisse/materialliste.dart';
import 'regelwerk.dart';

/// Optionale Position „Bohrsenker“ (Regel 4.5) zu den [bedarfe]n der ganzen
/// Planung: ein Stück, mit Preis aus den Artikeldaten, aber nicht in der
/// Summe ([Materialzusatz.optional]) – in Materialliste, Planungsunterlagen
/// und GrandTotal-Export, nicht im Warenkorb-Link. Es gibt sie, sobald die
/// Planung Clips oder Schrauben braucht (Holzbelag mit Befestigung), aber
/// nicht, wenn der Bohrsenker schon fest in der Planung ist (z. B. im
/// Zubehör gewählt). Der Bohrsenker ist der erste Werkzeug-Artikel mit
/// „Bohrsenker“ im Titel (50-80-008); ohne ihn in den Artikeldaten keine
/// Position.
Materialbedarf? bohrsenkerAngebot(
  Regelwerk? regelwerk,
  List<Materialbedarf> bedarfe,
) {
  final bohrsenker = regelwerk?.datei.eintraege
      .map((e) => e.artikel)
      .where(
        (a) => a.art == Artikelart.werkzeug && a.titel.contains('Bohrsenker'),
      )
      .firstOrNull;
  if (bohrsenker == null) return null;
  final befestigt = bedarfe.any(
    (b) =>
        b.stueck > 0 &&
        b.einheiten.any(
          (a) => a.art == Artikelart.clip || a.art == Artikelart.schraube,
        ),
  );
  final fest = bedarfe.any((b) => b.einheiten.contains(bohrsenker));
  if (!befestigt || fest) return null;
  return Materialbedarf(
    [bohrsenker],
    1,
    zusatz: Materialzusatz.optional,
    jePlanung: true,
  );
}
