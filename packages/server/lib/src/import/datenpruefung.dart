import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'artikel_import.dart';

/// Größtes plausibles Maß eines Artikels (längste Lieferlänge 7 m, Vlies- und
/// Bandrollen bis 10 m).
const groesstesMass = Millimeter(12000);

/// Datenprüfung über alle importierten Artikel (M2-03). Jeder Befund nennt
/// Excel-Zeile und Feld; kritische Befunde verhindern die Artikeldatei.
List<Befund> pruefeArtikel(List<({int zeile, Artikeleintrag eintrag})> liste) {
  final befunde = <Befund>[];
  final zeileVon = <Artikelnummer, int>{};
  for (final (:zeile, :eintrag) in liste) {
    final nummer = eintrag.artikel.nummer;
    final vorher = zeileVon[nummer];
    if (vorher != null) {
      befunde.add(
        Befund(
          zeile,
          'Artikelnummer',
          'doppelt (wie Zeile $vorher): ${nummer.wert}',
        ),
      );
    } else {
      zeileVon[nummer] = zeile;
    }
  }
  final vorhanden = zeileVon.keys.toSet();
  final regelwerk = Regelwerk(
    Artikeldatei(
      quelle: '',
      version: '',
      eintraege: [
        for (final (:zeile, :eintrag) in liste)
          if (zeileVon[eintrag.artikel.nummer] == zeile) eintrag,
      ],
    ),
  );
  for (final (:zeile, :eintrag) in liste) {
    befunde
      ..addAll(_verweise(zeile, eintrag, vorhanden))
      ..addAll(_befestigung(zeile, eintrag, regelwerk, vorhanden))
      ..addAll(_masse(zeile, eintrag.artikel))
      ..addAll(_holz(zeile, eintrag))
      ..addAll(_angaben(zeile, eintrag))
      ..addAll(_anzeige(zeile, eintrag.artikel));
  }
  return befunde..sort((a, b) => a.zeile - b.zeile);
}

Iterable<Befund> _verweise(
  int zeile,
  Artikeleintrag e,
  Set<Artikelnummer> vorhanden,
) sync* {
  for (final MapEntry(:key, :value) in e.verweise.entries) {
    for (final ziel in value) {
      if (!vorhanden.contains(ziel)) {
        yield Befund(zeile, key, 'Artikel ${ziel.wert} nicht vorhanden');
      }
    }
  }
  for (final ziel in e.benoetigt.keys) {
    if (!vorhanden.contains(ziel)) {
      yield Befund(
        zeile,
        'benoetigtesZubehoer',
        'Artikel ${ziel.wert} nicht vorhanden',
      );
    }
  }
}

/// Befestigung laut Verweisen muss zur Firmenregel passen (B-094, B-090);
/// nur bei ersten Vorkommen mit vollständigen Verweisen.
Iterable<Befund> _befestigung(
  int zeile,
  Artikeleintrag e,
  Regelwerk regelwerk,
  Set<Artikelnummer> vorhanden,
) sync* {
  final ziele = e.verweise[Beziehung.befestigung.spalte] ?? const [];
  if (regelwerk.datei[e.artikel.nummer] != e || !vorhanden.containsAll(ziele)) {
    return;
  }
  final widerspruch = regelwerk.befestigungWiderspruch(e.artikel.nummer);
  if (widerspruch != null) {
    yield Befund(zeile, Beziehung.befestigung.spalte, widerspruch);
  }
}

Iterable<Befund> _masse(int zeile, Artikel a) sync* {
  final m = a.abmessungen;
  for (final (feld, wert) in [
    ('Breite_cm', m.breite),
    ('Staerke_cm', m.staerke),
    for (final l in m.laengen) ('Laenge_cm', l),
  ]) {
    if (wert != null && wert > groesstesMass) {
      yield Befund(zeile, feld, 'unplausibel groß: ${wert.mm} mm');
    }
  }
  // Schrauben: „5,5 x 60 mm“ im Titel nennt die Länge.
  final titel = RegExp(r'(\d+(?:[,.]\d+)?)\s*x\s*(\d+)\s*mm')
      .firstMatch(a.titel);
  final laenge = m.laengste;
  if (a.art == Artikelart.schraube &&
      titel != null &&
      laenge != null &&
      int.parse(titel.group(2)!) != laenge.mm) {
    yield Befund(
      zeile,
      'Laenge_cm',
      'Länge ${laenge.mm} mm passt nicht zum Titel (${titel.group(0)})',
      kritisch: false,
    );
  }
}

Iterable<Befund> _holz(int zeile, Artikeleintrag e) sync* {
  final a = e.artikel;
  final holzart = a.holzart;
  final serie = a.serie;
  if (holzart == null || serie == null) return;
  final regeln = holzart.serie(serie);
  final (breite, staerke) = (a.abmessungen.breite, a.abmessungen.staerke);
  final profil = a.profil;
  if (profil != null) {
    if (breite == null ||
        staerke == null ||
        !regeln.dielenformatGueltig(profil, breite, staerke)) {
      yield Befund(
        zeile,
        'Breite_cm',
        '${serie.name} ${profil.name} ${breite?.mm} x ${staerke?.mm} mm '
            'nicht im Sortiment (B-030)',
      );
    }
  } else if (breite != null && staerke != null) {
    switch (regeln.ukFormat(breite, staerke)) {
      case UkFormat.gueltig:
        break;
      case UkFormat.ungetrocknet:
        yield Befund(
          zeile,
          'Breite_cm',
          'UK ${breite.mm} x ${staerke.mm} mm nur ungetrocknet (B-212)',
          kritisch: false,
        );
      case UkFormat.ungueltig:
        yield Befund(
          zeile,
          'Breite_cm',
          'UK ${breite.mm} x ${staerke.mm} mm nicht im Sortiment (B-034)',
        );
    }
  }
  for (final laenge in a.abmessungen.laengen) {
    if (!regeln.lieferlaengen.contains(laenge)) {
      yield Befund(
        zeile,
        'Laenge_cm',
        '${laenge.mm} mm ist keine Lieferlänge von ${serie.name} (B-035)',
      );
    }
  }
}

Iterable<Befund> _angaben(int zeile, Artikeleintrag e) sync* {
  final g = e.angaben;
  final (min, max) = (g['MinHoehe'], g['MaxHoehe']);
  if (min != null && max != null && min > max) {
    yield Befund(zeile, 'MinHoehe', 'größer als MaxHoehe ($min > $max)');
  }
  final abstand = g['Abstand_UK'];
  final holzart = e.artikel.holzart;
  if (abstand != null &&
      holzart != null &&
      abstand > holzart.ukAchsabstandMax.mm) {
    yield Befund(
      zeile,
      'Abstand_UK',
      '$abstand mm über dem höchsten UK-Achsabstand '
          '${holzart.ukAchsabstandMax.mm} mm (R-C01)',
      kritisch: false,
    );
  }
}

Iterable<Befund> _anzeige(int zeile, Artikel a) sync* {
  final preis = a.preisBrutto;
  if (preis == null || preis.cent <= 0) {
    yield Befund(
      zeile,
      'Preis_pro_Einheit',
      'kein Preis – Anzeige ohne Preis (B-055)',
      kritisch: false,
    );
  }
  if (a.bilder.isEmpty) {
    yield Befund(
      zeile,
      'Abbildung_1',
      'keine Abbildung – Platzhalter (M2-07)',
      kritisch: false,
    );
  }
}
