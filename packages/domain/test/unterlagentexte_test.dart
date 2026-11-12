import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  const de = Unterlagentexte.deutsch;
  const en = Unterlagentexte.englisch;

  test('Sprache aus dem Code, unbekannt Deutsch', () {
    expect(Unterlagensprache.ausCode('de'), Unterlagensprache.deutsch);
    expect(Unterlagensprache.ausCode('en'), Unterlagensprache.englisch);
    expect(Unterlagensprache.ausCode('fr'), Unterlagensprache.deutsch);
    expect(Unterlagentexte.fuer(Unterlagensprache.deutsch), same(de));
    expect(Unterlagentexte.fuer(Unterlagensprache.englisch), same(en));
  });

  test('Zahlen, Längen, Preise und Seiten je Sprache', () {
    expect(de.seitenangabe(2, 7), 'Seite 2 von 7');
    expect(en.seitenangabe(2, 7), 'Page 2 of 7');
    expect(de.zahl(12.3456, 3), '12,346');
    expect(en.zahl(12.3456, 3), '12.346');
    expect(de.cm(const Millimeter(4800)), '480');
    expect(de.cm(const Millimeter(435)), '43,5');
    expect(en.cm(const Millimeter(435)), '43.5');
    expect(de.preis(const Cent(206657)), '2.066,57 €');
    expect(en.preis(const Cent(206657)), '2,066.57 €');
    expect(en.preis(const Cent(5)), '0.05 €');
  });

  test('Farben und Einheiten', () {
    expect(
      [for (final f in Stueckfarbe.values) de.stueckfarbe(f)],
      ['rot', 'blau', 'grün'],
    );
    expect(
      [for (final f in Stueckfarbe.values) en.stueckfarbe(f)],
      ['red', 'blue', 'green'],
    );
    expect(
      [for (final e in Mengeneinheit.values) de.einheit(e)],
      [for (final e in Mengeneinheit.values) e.anzeige],
    );
    expect(
      [for (final e in Mengeneinheit.values) en.einheit(e)],
      ['pcs', 'm', 'm²', 'pack', 'box', 'set', 'crate', 'l'],
    );
  });

  test('Wahlen der Planung je Sprache', () {
    expect(de.richtung(Verlegerichtung.waagrecht, 0), 'waagrecht');
    expect(de.richtung(Verlegerichtung.senkrecht, 90), 'senkrecht');
    expect(en.richtung(Verlegerichtung.waagrecht, 0), 'horizontal');
    expect(en.richtung(Verlegerichtung.senkrecht, 90), 'vertical');
    expect(de.richtung(Verlegerichtung.diagonal45, 45), '45°');
    expect(en.richtung(Verlegerichtung.individuell, 30), '30°');
    for (final t in [de, en]) {
      for (final texte in [
        [for (final a in Verlegeart.values) t.art(a)],
        [for (final b in Befestigungsart.values) t.befestigungsart(b)],
        [for (final a in Terrassenart.values) t.terrassenartText(a)],
        [for (final u in Untergrund.values) t.untergrundText(u)],
        [for (final n in Nutzungsart.values) t.nutzungsartText(n)],
        [for (final a in Auflagen.values) t.auflagenText(a)],
      ]) {
        expect(texte.toSet(), hasLength(texte.length), reason: '$texte');
      }
    }
    expect(de.art(Verlegeart.halbverband), 'Halbverband');
    expect(en.art(Verlegeart.halbverband), 'Half bond');
    expect(de.befestigungsart(Befestigungsart.clips), 'mit Clips');
    expect(en.befestigungsart(Befestigungsart.clips), 'with clips');
    expect(de.terrassenartText(Terrassenart.hochterrasse), 'Hochterrasse');
    expect(en.terrassenartText(Terrassenart.hochterrasse), 'raised terrace');
    expect(de.untergrundText(Untergrund.beton), 'Beton');
    expect(en.untergrundText(Untergrund.beton), 'concrete');
    expect(de.nutzungsartText(Nutzungsart.rahmen), 'Rahmen');
    expect(en.nutzungsartText(Nutzungsart.rahmen), 'frame');
    expect(de.auflagenText(Auflagen.stelzfuesse), 'mit Stelzfüßen');
    expect(en.auflagenText(Auflagen.stelzfuesse), 'with adjustable feet');
  });

  test('Meldungen wie in der App, mit Längen in cm', () {
    for (final t in [de, en]) {
      expect({
        for (final m in Flaechenmeldung.values) t.flaechenmeldung(m),
      }, hasLength(Flaechenmeldung.values.length));
      final texte = [
        for (final m in Belagmeldung.values)
          t.belagmeldung(m, const Millimeter(7000)),
      ];
      expect(texte.toSet(), hasLength(Belagmeldung.values.length));
      expect({
        for (final m in Kantenmeldung.values)
          t.kantenwarnung((kante: 'A–B', laenge: const Millimeter(55), art: m)),
      }, hasLength(Kantenmeldung.values.length));
      expect({
        for (final m in Treppenmeldung.values) t.treppenmeldung(2, m),
      }, hasLength(Treppenmeldung.values.length));
      expect(t.nichtImAngebot('X'), endsWith(': X'));
    }
    expect(
      de.kantenwarnung((
        kante: 'A–B',
        laenge: const Millimeter(55),
        art: Kantenmeldung.zuKurz,
      )),
      'Kante A–B ist nur 5,5 cm lang (unter 10 cm) – bitte die Maße prüfen.',
    );
    expect(
      en.kantenwarnung((
        kante: 'A–B',
        laenge: const Millimeter(31000),
        art: Kantenmeldung.zuLang,
      )),
      contains('3100 cm'),
    );
    expect(
      de.treppenmeldung(2, Treppenmeldung.ueberSeite),
      startsWith('Treppe 2: '),
    );
    expect(
      en.treppenmeldung(2, Treppenmeldung.zuSchmal),
      startsWith('Stairs 2'),
    );
    // Rinne (Planungskern v11, Regel 13.1)
    for (final t in [de, en]) {
      final rinne = [
        Anschlussmeldung.rinneNichtMoeglich,
        Anschlussmeldung.rinnenfarbeFehlt,
        Anschlussmeldung.rinnenmontage,
        Anschlussmeldung.eckwinkelFehlt,
      ];
      expect({for (final m in rinne) t.rinnenmeldung(m)}, hasLength(4));
      expect(t.rinnenmeldung(Anschlussmeldung.unterlueftung), isNull);
      expect(t.rinneEtikett, 'Rinne RELO V');
    }
    expect(
      de.rinnenmeldung(Anschlussmeldung.rinnenmontage),
      contains('UNIA 4,2 × 22 mm'),
    );
    expect(
      en.rinnenmeldung(Anschlussmeldung.rinnenmontage),
      contains('UNIA 4.2 × 22 mm'),
    );
    expect(
      de.rinnenmeldung(Anschlussmeldung.rinneNichtMoeglich),
      startsWith('Rinne nicht geplant'),
    );
    expect(
      en.rinnenmeldung(Anschlussmeldung.eckwinkelFehlt),
      startsWith('Corner brackets'),
    );
    expect(
      de.rinnenmeldung(Anschlussmeldung.rinnenfarbeFehlt),
      startsWith('Rinne in Anthrazit'),
    );
    expect(de.rinnenBelagHinweis, contains('15,7 cm'));
    expect(en.rinnenBelagHinweis, contains('15.7 cm'));
    expect(de.rinnenUkHinweis, startsWith('Rinne RELO V: 2 Auflagerprofile'));
    expect(en.rinnenUkHinweis, startsWith('Channel RELO V'));
    expect(de.nichtImAngebot('X'), 'Nicht im Angebot: X');
    expect(en.nichtImAngebot('X'), 'Not in the offer: X');
    expect(
      de.belagmeldung(
        Belagmeldung.laengeNichtLieferbar,
        const Millimeter(7000),
      ),
      contains('700 cm gibt es'),
    );
    expect(
      en.belagmeldung(
        Belagmeldung.laengeNichtLieferbar,
        const Millimeter(7000),
      ),
      contains('700 cm is not'),
    );
    expect(
      de.belagmeldung(Belagmeldung.bombierungEmpfohlen, null),
      startsWith('Ab 8 cm'),
    );
    expect(
      de.flaechenmeldung(Flaechenmeldung.masseFalsch),
      startsWith('Maße fehlen oder sind falsch'),
    );
    expect(
      [
        for (final t in [de, en])
          for (final m in Flaechenmeldung.values) t.flaechenmeldung(m),
      ],
      [
        contains('höchstens 0,05 m²'),
        contains('über 1.000 m²'),
        contains('1 bis 300 m²'),
        contains('at most 0.05 m²'),
        contains('implausibly large (over 1,000 m²)'),
        contains('1 to 300 m²'),
      ],
    );
    expect(
      en.belagmeldung(Belagmeldung.bombierungEmpfohlen, null),
      startsWith('From 8 cm'),
    );
    expect(
      de.auflagermeldung(
        Auflagermeldung.unterMindesthoehe,
        const Millimeter(55),
      ),
      contains('Mindesthöhe von 5,5 cm'),
    );
    expect(
      de.auflagermeldung(
        Auflagermeldung.ueberHoechsthoehe,
        const Millimeter(950),
      ),
      contains('Höchsthöhe von 95 cm'),
    );
    expect(
      en.auflagermeldung(
        Auflagermeldung.unterMindesthoehe,
        const Millimeter(55),
      ),
      contains('minimum height of 5.5 cm'),
    );
    expect(
      en.auflagermeldung(
        Auflagermeldung.ueberHoechsthoehe,
        const Millimeter(950),
      ),
      contains('maximum height of 95 cm'),
    );
    expect(de.ukGedreht, startsWith('Die Unterkonstruktion wird gedreht'));
    expect(en.ukGedreht, startsWith('The substructure is turned'));
    expect(
      de.hoeheKorrigiert(const Millimeter(63)),
      contains('6,3 cm und wurde korrigiert'),
    );
    expect(
      en.hoeheKorrigiert(const Millimeter(63)),
      contains('6.3 cm and has been corrected'),
    );
    // Planungskern v6 Regel 3a.5: Höhe ungültig, Rückfrage
    expect(
      de.hoeheUngueltig(const Millimeter(524), const Millimeter(113)),
      'Höhe ungültig: höchstens 52,4 cm mit Stellfüßen. Gerechnet wird mit '
      'dem Standardaufbau. Meintest du 11,3 cm?',
    );
    expect(
      de.hoeheUngueltig(const Millimeter(524), null),
      'Höhe ungültig: höchstens 52,4 cm mit Stellfüßen. Gerechnet wird mit '
      'dem Standardaufbau.',
    );
    expect(
      en.hoeheUngueltig(const Millimeter(524), const Millimeter(113)),
      'Invalid height: at most 52.4 cm with adjustable feet. The standard '
      'build-up is used. Did you mean 11.3 cm?',
    );
    expect(
      en.hoeheUngueltig(const Millimeter(524), null),
      'Invalid height: at most 52.4 cm with adjustable feet. The standard '
      'build-up is used.',
    );
    // Planungsregeln 3.4: Selbstkontrolle der Rand-UK
    expect(
      de.randUkErgaenzt(const Millimeter(2570)),
      'Rand-UK 257 cm ergänzt: An einer Kante endeten Dielen ohne UK '
      'darunter.',
    );
    expect(
      en.randUkErgaenzt(const Millimeter(2575)),
      'Edge substructure of 257.5 cm added: boards ended at an edge '
      'without substructure underneath.',
    );
  });

  test('rechtliche Hinweise und Grußtext wie in den Planungsunterlagen', () {
    expect(de.rechtlicheHinweise, hasLength(3));
    expect(en.rechtlicheHinweise, hasLength(3));
    expect(
      de.rechtlicheHinweise.first,
      startsWith('Ihre Konfiguration ist ein unverbindlicher Entwurf'),
    );
    expect(de.gruss, 'Es grüßt Sie das');
    expect(de.absender.first, 'RobinienWelt TEAM');
    expect(de.mehrwertsteuer, 'enthaltene 19 % MwSt.');
    expect(en.mehrwertsteuer, 'incl. 19 % VAT');
  });

  // Wortlaut genau – Bindestriche und Schrägstriche gehören zum Text
  // (Mutationen „-“ → „+“, „/“ → „*“).
  test('Wortlaut von Kopf, Tabellen und Absender', () {
    expect(de.kundenfelder, ['Name', 'Adresse', 'Ort', 'Telefon', 'E-Mail']);
    expect(en.kundenfelder, ['Name', 'Address', 'Town', 'Phone', 'Email']);
    expect(
      de.dielenHinweis,
      'Hinweis: Die Zahl in den Dielen/Platten ist die Nummer in der '
      'nachstehenden Tabelle.',
    );
    expect(
      en.dielenHinweis,
      'Note: the number in the boards/tiles is the number in the table below.',
    );
    expect(de.dielenNachNummer, 'Dielen/Platten nach Nummer');
    expect(en.dielenNachNummer, 'Boards/tiles by number');
    expect([de.jeLfm, de.jeStueck], ['€/lfm', '€/Stück']);
    expect([en.jeLfm, en.jeStueck], ['€/m', '€/piece']);
    for (final t in [de, en]) {
      expect(t.absender, [
        'RobinienWelt TEAM',
        'anfrage@robinienwelt.de',
        'shop.robinienwelt.de',
      ]);
    }
  });

  test('Wortlaut der rechtlichen Hinweise', () {
    expect(de.rechtlicheHinweise, [
      'Ihre Konfiguration ist ein unverbindlicher Entwurf und ersetzt eine '
          'ausgiebige Beratung durch Handwerk oder Handel nicht. Alle Angaben '
          'beziehen sich auf die Nutzung ausschließlich von unseren Produkten '
          'und verstehen sich als Richtwerte ohne Anspruch auf Richtigkeit/ '
          'Vollständigkeit. Bei dem Austausch einzelner Produkte durch '
          'Fremdware ist jegliche Gewährleistung ausgeschlossen.',
      'Halten Sie sich bei der Planung und Verwirklichung Ihres Projekts '
          'zwingend an alle rechtlichen Vorschriften, unsere Montageanleitung '
          'sowie die entsprechenden Fachregeln. Bei abweichender Montage '
          'erlischt die Gewährleistung seitens uns.',
      'Alle Produkte können fertigungs- und materialbedingte Maßtoleranzen '
          'aufweisen. Beginnen Sie deshalb mit Fundament- oder '
          'Zuschnittarbeiten immer erst, wenn die Ware vor Ort und in einem '
          'verarbeitungsbereiten Zustand ist.',
    ]);
    expect(en.rechtlicheHinweise, [
      'Your configuration is a non-binding draft and does not replace '
          'thorough advice from a tradesman or dealer. All information '
          'refers exclusively to the use of our products and is meant as a '
          'guide without any claim to correctness or completeness. Any '
          'warranty is excluded if individual products are replaced by '
          'third-party goods.',
      'When planning and carrying out your project, strictly follow all '
          'legal regulations, our installation instructions and the relevant '
          'technical rules. Our warranty expires if the installation '
          'deviates from them.',
      'All products may have manufacturing- and material-related '
          'dimensional tolerances. Therefore, only start foundation or '
          'cutting work once the goods are on site and ready to be worked.',
    ]);
  });

  test('Wortlaut der Meldungen mit Zahlen und Bindestrichen', () {
    expect(
      de.belagmeldung(Belagmeldung.fliesenSpitzeWinkel, null),
      'Die Fläche hat Ecken unter 90°. Holzfliesen müssen dort schräg '
      'zugeschnitten werden.',
    );
    expect(
      en.belagmeldung(Belagmeldung.fliesenSpitzeWinkel, null),
      'The area has corners below 90°. Wooden tiles must be cut at an '
      'angle there.',
    );
    expect(
      en.belagmeldung(Belagmeldung.befestigungsartNichtMoeglich, null),
      'Grooved boards are fixed invisibly with clips. The selected screw '
      'fixing only applies to smooth-edged boards.',
    );
  });
}
