import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

/// Abnahme M9-06: Planungsunterlagen für die Referenzfälle (M1-02) – alle
/// Rechtecke, L- und T-Formen mit vollständigen Kantenmaßen, mit Belag,
/// Holz-UK, Auflagern und Höhen der Unterlage. Die Fläche selbst prüfen
/// M4-02 bis M4-14 (L-/T-Formen mit anderer Lage der Aussparung weichen
/// ab). Mit `PLANER_PDF_AUSGABE`
/// (Ordner) werden die PDFs zum Ansehen abgelegt.
void main() {
  Artikel diele(int breite) => Artikel(
    nummer: Artikelnummer('10-10-0$breite'),
    titel: 'Terrassendiele Robinie $breite x 22 mm, genutet',
    art: Artikelart.diele,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    preisBrutto: const Cent(449),
    abmessungen: Abmessungen(
      breite: Millimeter(breite),
      staerke: const Millimeter(22),
      laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
    ),
    holzart: robinie,
    serie: basic,
    profil: Profil.genutet,
  );
  final uk = Artikel(
    nummer: const Artikelnummer('10-10-031'),
    titel: 'Unterkonstruktionsholz Robinie 40 x 60 mm',
    art: Artikelart.unterkonstruktion,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    preisBrutto: const Cent(979),
    abmessungen: Abmessungen(
      breite: const Millimeter(40),
      staerke: const Millimeter(60),
    ),
    holzart: robinie,
    serie: basic,
  );
  final pad = Artikel(
    nummer: const Artikelnummer('50-60-005'),
    titel: 'Unterlegpad 5 mm',
    art: Artikelart.pad,
    einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: 70),
  );
  final fuss = Artikel(
    nummer: const Artikelnummer('60-55-136'),
    titel: 'Stelzfuß 55–95 mm',
    art: Artikelart.stellfuss,
    einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: 20),
  );
  final belaege = {
    for (final b in [50, 60, 80, 100]) b: diele(b),
  };
  final regelwerk = Regelwerk(
    Artikeldatei(
      quelle: 'test',
      version: '1',
      eintraege: [
        for (final b in belaege.values)
          Artikeleintrag(artikel: b, angaben: const {'Abstand_UK': 400}),
        Artikeleintrag(
          artikel: uk,
          verweise: {
            Beziehung.stellfussPrivat.spalte: [fuss.nummer],
            Beziehung.unterlegpads.spalte: [pad.nummer],
          },
          angaben: const {'Abstand_Stelzfuesse': 600},
        ),
        Artikeleintrag(
          artikel: pad,
          angaben: const {'MinHoehe': 5, 'MaxHoehe': 5},
        ),
        Artikeleintrag(
          artikel: fuss,
          angaben: const {'MinHoehe': 55, 'MaxHoehe': 95},
        ),
      ],
    ),
  );
  final ausgabe = Platform.environment['PLANER_PDF_AUSGABE'];

  final faelle = [
    for (final f in Directory(
      '../domain/test/referenzfaelle',
    ).listSync()..sort((a, b) => a.path.compareTo(b.path)))
      Referenzfall.ausJson(
        jsonDecode((f as File).readAsStringSync()) as Map<String, Object?>,
      ),
  ];

  Grundriss? grundriss(ReferenzGrundriss r) {
    final k = r.kantenCm;
    Millimeter? mm(String kante) => switch (k[kante]) {
      final cm? => Millimeter((cm * 10).round()),
      null => null,
    };
    try {
      return switch (r.form) {
        'Rechteck' => RechteckGrundriss(mm('A-B')!, mm('B-C')!),
        'L-Form' => LGrundriss(mm('A-B')!, mm('B-C')!, mm('C-D')!, mm('D-E')!),
        'T-Form' => TGrundriss(
          mm('B-C')!,
          mm('C-D')!,
          mm('D-E')!,
          mm('E-F')!,
          mm('G-H')!,
          mm('H-A')!,
        ),
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  var erzeugt = 0;
  for (final fall in faelle) {
    final form = grundriss(fall.grundriss);
    final breite = int.tryParse(
      RegExp(r'(\d+) x').firstMatch(fall.belag ?? '')?.group(1) ?? '',
    );
    if (form == null || !belaege.containsKey(breite)) continue;
    erzeugt++;
    test('${fall.id}: alle Kapitel, PDF erzeugt', () async {
      final belag = belaege[breite]!;
      var stand = Planungsstand(grundriss: form)
          .mitBelag(belag.nummer)
          .mitVerlegerichtung(
            fall.verlegerichtung == 'Senkrecht'
                ? Verlegerichtung.senkrecht
                : Verlegerichtung.waagrecht,
          );
      final hoehen = fall.aufbauhoehenCm;
      if (hoehen != null && hoehen.length == form.ecken.length) {
        stand = stand.mitGefaelle(true);
        for (final (i, h) in hoehen.values.indexed) {
          stand = stand.mitEckhoehe(i, Millimeter.ausCm(h));
        }
      }
      final unterlagen = UnterlagenDienst.unterlagen(
        Planung([Terrassenflaeche(stand)]),
        datum: fall.datum,
        belag: (_) => belag,
        regelwerk: regelwerk,
        unterkonstruktion: (_) => uk,
      );
      final titel = [for (final k in unterlagen.kapitel) k.titel];
      // Höhenzuordnung fehlt, wenn kein Auflager passt (dann Hinweise)
      expect(titel, [
        'Planungsunterlagen',
        'Ihre Terrasse',
        'Ihre Terrasse – Unterkonstruktion',
        if (titel.contains('Ihre Terrasse – Höhenzuordnung der Auflager'))
          'Ihre Terrasse – Höhenzuordnung der Auflager',
        // Planungskern v7, Regel 9.2: Seite „Bemaßung und Höhen“
        'Ihre Terrasse – Bemaßung und Höhen',
        'Ihre Terrasse – Terrassenbelag',
        'Ihre Terrasse – Zuschnittsplan Belag',
        'Materialliste',
        if (titel.contains('Hinweise zur Planung')) 'Hinweise zur Planung',
        'Rechtliche Hinweise',
      ]);
      final pdf = await planungsunterlagenPdf(unterlagen);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      if (ausgabe != null) {
        File('$ausgabe/${fall.id}.pdf').writeAsBytesSync(pdf);
      }
    });
  }

  test('genug Referenzfälle', () {
    expect(erzeugt, greaterThanOrEqualTo(25));
  });
}
