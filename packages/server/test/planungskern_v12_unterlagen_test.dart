import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

/// Planungsunterlagen mit einer Bogenfläche (Planungsregeln Alexander
/// (Planungskern v12, 12.11.2026), Abschnitt 14): Rechteck 5,00 × 3,50 m,
/// Seite B — C als Bogen R 3,00 m, Bogen und C — D verblendet, Aufbauhöhe
/// 15 cm. Mit `PLANER_PDF_AUSGABE` (Ordner) wird das PDF zum Ansehen
/// abgelegt.
void main() {
  Artikel diele(String nummer, int breite, Profil profil) => Artikel(
    nummer: Artikelnummer(nummer),
    titel: 'Terrassendiele Robinie $breite x 22 mm, ${profil.name}',
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
    profil: profil,
  );
  final belag = diele('10-10-080', 80, Profil.genutet);
  final brett = diele('10-10-100', 100, Profil.glattkant);
  final schmal = diele('10-10-060', 60, Profil.glattkant);
  final schraube = Artikel(
    nummer: const Artikelnummer('50-10-050'),
    titel: 'Terrassenschraube 5 x 50 mm',
    art: Artikelart.schraube,
    einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: 200),
    abmessungen: Abmessungen(laengen: const [Millimeter(50)]),
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
  final fuss = Artikel(
    nummer: const Artikelnummer('60-55-136'),
    titel: 'Stelzfuß 55–95 mm',
    art: Artikelart.stellfuss,
    einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: 20),
  );
  final regelwerk = Regelwerk(
    Artikeldatei(
      quelle: 'test',
      version: '1',
      eintraege: [
        Artikeleintrag(artikel: belag, angaben: const {'Abstand_UK': 400}),
        for (final b in [brett, schmal])
          Artikeleintrag(
            artikel: b,
            verweise: {
              Beziehung.befestigung.spalte: [schraube.nummer],
            },
          ),
        Artikeleintrag(artikel: schraube),
        Artikeleintrag(
          artikel: uk,
          verweise: {
            Beziehung.stellfussPrivat.spalte: [fuss.nummer],
          },
          angaben: const {'Abstand_Stelzfuesse': 600},
        ),
        Artikeleintrag(
          artikel: fuss,
          angaben: const {'MinHoehe': 55, 'MaxHoehe': 95},
        ),
      ],
    ),
  );
  final stand =
      Planungsstand(
            grundriss: RechteckGrundriss(
              const Millimeter(5000),
              const Millimeter(3500),
            ),
            rundungen: Rundungen.keine.mitRadius(1, const Millimeter(3000)),
          )
          .mitBelag(belag.nummer)
          .mitHoehe(const Millimeter(150))
          .mitVerblendet(1, an: true)
          .mitVerblendet(2, an: true);

  test('Bogen im Plan, Riegel, Blende am Bogen, PDF', () async {
    final unterlagen = UnterlagenDienst.unterlagen(
      Planung([Terrassenflaeche(stand)]),
      datum: DateTime(2026, 11, 12),
      belag: (_) => belag,
      regelwerk: regelwerk,
      unterkonstruktion: (_) => uk,
    );
    const t = Unterlagentexte.deutsch;
    final ukKapitel = unterlagen.kapitel.singleWhere(
      (k) => k.titel == 'Ihre Terrasse – Unterkonstruktion',
    );
    final plan = ukKapitel.inhalt.whereType<Plan>().single;
    expect([
      for (final x in plan.nebentexte) x.text,
    ], contains(startsWith('Bogen ')));
    expect([
      for (final x in plan.nebentexte) x.text,
    ], contains(endsWith(' · R 3,00 m')));
    // die Platzsuche setzt das Bogenmaß (Planungskern v10, Regel 12.1)
    expect([
      for (final (n, _) in nebentextFelder(plan, Planmassstab.fuer(plan)))
        n.text,
    ], contains(startsWith('Bogen ')));
    expect(
      ukKapitel.inhalt.whereType<Absatz>().map((a) => a.text),
      contains(t.riegelHinweis),
    );
    final hinweise = unterlagen.kapitel.singleWhere(
      (k) => k.titel == 'Hinweise zur Planung',
    );
    expect(
      hinweise.inhalt.whereType<Absatz>().map((a) => a.text),
      contains('• ${t.anschlusshinweis(Anschlussmeldung.bogenblende)}'),
    );
    final pdf = await planungsunterlagenPdf(unterlagen);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    if (Platform.environment['PLANER_PDF_AUSGABE'] case final ordner?) {
      File('$ordner/bogenflaeche.pdf').writeAsBytesSync(pdf);
    }
  });

  test('weit hinausragender Nebentext ganz auf der Seite', () {
    Nebentext n(String text, Punkt richtung) => (
      ort: const Punkt(10000, 0),
      richtung: richtung,
      abstand: 100,
      text: text,
    );
    const lang = 'Bogen 3,74 m · R 3,00 m';
    expect(
      nebentextReichweite(n(lang, const Punkt(1, 0))),
      nebentextAbstand + lang.length * nebentextGroesse * 0.55 + 1,
    );
    expect(
      nebentextReichweite(n(lang, const Punkt(0, -1))),
      nebentextAbstand + nebentextGroesse + 2,
    );
    final linie = Planlinie(const [
      Punkt(0, 0),
      Punkt(10000, 0),
    ], argb: 0xFF000000);
    final kurz = Planmassstab.fuer(
      Plan([linie], const [], [n('4,4', const Punkt(1, 0))]),
    );
    final f = (satzbreite - 2 * planrand) / 10000;
    // kurze Texte bleiben im Rand, der Plan reicht nur bis zum Anker
    expect(kurz.faktor, closeTo(f, 1e-12));
    final breit = Planmassstab.fuer(
      Plan([linie], const [], [n(lang, const Punkt(1, 0))]),
    );
    final ueber =
        (nebentextReichweite(n(lang, const Punkt(1, 0))) - planrand) / f;
    // bis zum Anker (100 mm) plus dem Überstand
    expect(breit.faktor, closeTo(f * 10000 / (10000 + 100 + ueber), 1e-12));
    expect(breit.abbild(Punkt.ursprung).x, 0);
    // nach oben: die halbe Zeile reicht nicht über den Rand
    expect(
      Planmassstab.fuer(Plan([linie], const [], [n(lang, const Punkt(0, -1))]))
          .faktor,
      closeTo(f, 1e-12),
    );
  });
}
