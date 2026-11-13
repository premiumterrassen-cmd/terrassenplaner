import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/artikel/artikelbild_widget.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/belag.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

Artikel _diele(
  String nummer,
  String titel, {
  Serie serie = premiumSelect,
  Profil profil = Profil.genutet,
  Oberseite oberseite = Oberseite.bombiert,
  int breite = 60,
  int staerke = 22,
  List<int> laengen = const [3000, 4000],
  List<String> bilder = const [],
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: titel,
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: Millimeter(breite),
    staerke: Millimeter(staerke),
    laengen: [for (final l in laengen) Millimeter(l)],
  ),
  holzart: robinie,
  serie: serie,
  profil: profil,
  oberseite: oberseite,
  bilder: bilder,
);

final _vorgabe = Belagangebot(
  _diele('10-10-060-R', 'Diele genutet 60', bilder: ['a.jpg', 'b.jpg']),
  preisJeLfm: const Cent(1250),
  preisJeM2: const Cent(19231),
);
final _glattkant = Belagangebot(
  _diele(
    '10-20-100',
    'Diele glattkant 100',
    serie: basic,
    profil: Profil.glattkant,
    oberseite: Oberseite.glatt,
    breite: 100,
    staerke: 26,
    laengen: [5000],
  ),
);
final _fliese = Belagangebot(
  Artikel(
    nummer: const Artikelnummer('70-10-001'),
    titel: 'Terrassenfliese',
    art: Artikelart.holzfliese,
    einheit: Verkaufseinheit(Mengeneinheit.stueck),
  ),
  preisJeM2: const Cent(5446),
);
final _auswahl = Belagauswahl('v1', [_vorgabe, _glattkant, _fliese]);

void main() {
  group('BelagQuelle', () {
    test('lädt beim Anlegen, Fehler und erneutes Laden', () async {
      var versuche = 0;
      final quelle = BelagQuelle(() async {
        versuche++;
        if (versuche == 1) throw StateError('weg');
        return _auswahl;
      });
      addTearDown(quelle.dispose);
      var meldungen = 0;
      quelle.addListener(() => meldungen++);
      expect(quelle.auswahl, isNull);
      await pumpEventQueue();
      expect(quelle.fehler, isA<StateError>());
      expect(quelle.auswahl, isNull);
      expect(meldungen, 1);
      final laden = quelle.ladeNeu();
      expect(quelle.fehler, isNull);
      expect(meldungen, 2);
      await laden;
      expect(quelle.auswahl, _auswahl);
      expect(meldungen, 3);
    });
  });

  test('Maße: Längen × Breite × Stärke in mm', () {
    expect(belagMasse(_vorgabe.artikel), '3000/4000 × 60 × 22 mm');
    expect(belagMasse(_fliese.artikel), ' mm');
    expect(
      belagMasse(
        Artikel(
          nummer: const Artikelnummer('1'),
          titel: 'x',
          art: Artikelart.holzfliese,
          einheit: Verkaufseinheit(Mengeneinheit.stueck),
          abmessungen: Abmessungen(
            breite: const Millimeter(606),
            laengen: [const Millimeter(606)],
          ),
        ),
      ),
      '606 × 606 mm',
    );
  });

  group('Belaganzeige', () {
    Future<({PlanungsSteuerung planung, List<int> geaendert})> zeige(
      WidgetTester tester,
      BelagQuelle quelle,
    ) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      addTearDown(quelle.dispose);
      final geaendert = <int>[];
      await tester.pumpWidget(
        testApp(
          theme: planerThema(),
          home: Scaffold(
            body: BelagAnzeige(
              quelle: quelle,
              planung: planung,
              onGeaendert: () => geaendert.add(1),
            ),
          ),
        ),
      );
      return (planung: planung, geaendert: geaendert);
    }

    testWidgets('lädt, dann Vorgabe mit Maßen und Fuge', (tester) async {
      final fertig = Completer<Belagauswahl>();
      await zeige(tester, BelagQuelle(() => fertig.future));
      expect(find.text(de.belagLaedt), findsOneWidget);
      fertig.complete(_auswahl);
      await tester.pumpAndSettle();
      expect(find.text('Diele genutet 60'), findsOneWidget);
      expect(find.text('Maße: 3000/4000 × 60 × 22 mm'), findsOneWidget);
      expect(find.text('Fuge: 6 mm'), findsOneWidget);
      expect(find.text('Produktauswahl'), findsOneWidget);
      expect(tester.widget<Artikelbild>(find.byType(Artikelbild)).groesse, 64);
    });

    testWidgets('keine Beläge in den Artikeldaten', (tester) async {
      await zeige(tester, BelagQuelle(() async => Belagauswahl('v0', [])));
      await tester.pumpAndSettle();
      expect(find.text(de.belagKeine), findsOneWidget);
    });

    testWidgets('Fehler mit „Erneut versuchen“', (tester) async {
      var versuche = 0;
      await zeige(
        tester,
        BelagQuelle(() async {
          if (versuche++ == 0) throw StateError('weg');
          return _auswahl;
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text(de.belagFehler), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('belag-neu-laden')));
      await tester.pumpAndSettle();
      expect(find.text('Diele genutet 60'), findsOneWidget);
    });

    testWidgets('Produktauswahl: Karte wählt den Belag', (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await zeige(tester, BelagQuelle(() async => _auswahl));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('produktauswahl')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('belag-dialog')), findsOneWidget);
      expect(find.text(de.belagDialogTitel), findsOneWidget);
      // die Vorgabe ist markiert
      expect(find.text(de.gewaehlt), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('belag-10-20-100')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('belag-dialog')), findsNothing);
      expect(s.planung.aktuell.belag, const Artikelnummer('10-20-100'));
      expect(s.planung.kannRueckgaengig, isTrue);
      expect(s.geaendert, [1]);
      expect(find.text('Diele glattkant 100'), findsOneWidget);
      expect(find.text('Maße: 5000 × 100 × 26 mm'), findsOneWidget);

      // „Zurück zur Konfiguration“ ändert nichts
      await tester.tap(find.byKey(const ValueKey('produktauswahl')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zurueck-zur-konfiguration')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('belag-dialog')), findsNothing);
      expect(s.planung.aktuell.belag, const Artikelnummer('10-20-100'));
      expect(s.geaendert, [1]);
    });
  });

  group('Dialog „Terrassenbelag auswählen“', () {
    Future<void> zeige(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1440, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          theme: planerThema(),
          home: Scaffold(body: BelagDialog(auswahl: _auswahl)),
        ),
      );
    }

    bool sichtbar(String nummer) =>
        find.byKey(ValueKey('belag-$nummer')).evaluate().isNotEmpty;

    List<bool> karten() => [
      sichtbar('10-10-060-R'),
      sichtbar('10-20-100'),
      sichtbar('70-10-001'),
    ];

    testWidgets('Karten mit Abmessungen und Preisen', (tester) async {
      await zeige(tester);
      expect(karten(), [true, true, true]);
      expect(find.text(de.gewaehlt), findsNothing);
      expect(find.text('Abmessungen: 3000/4000 × 60 × 22 mm'), findsOneWidget);
      expect(find.text('Preis je lfm: 12,50 € inkl. MwSt.'), findsOneWidget);
      expect(find.text('Preis je m²: 192,31 € inkl. MwSt.'), findsOneWidget);
      expect(find.text('Preis je m²: 54,46 € inkl. MwSt.'), findsOneWidget);
      expect(find.textContaining('Preis je lfm'), findsOneWidget);
    });

    testWidgets('Kategorien: wählen und wieder abwählen', (tester) async {
      await zeige(tester);
      for (final (k, text) in [
        ('unsichtbar', 'Unsichtbar befestigt'),
        ('sichtbar', 'Sichtbar befestigt'),
        ('holzfliese', 'Holzfliese'),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('kategorie-$k')),
            matching: find.text(text),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('kategorie-sichtbar')));
      await tester.pump();
      expect(karten(), [false, true, false]);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('kategorie-sichtbar')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('kategorie-holzfliese')));
      await tester.pump();
      expect(karten(), [false, false, true]);
      await tester.tap(find.byKey(const ValueKey('kategorie-holzfliese')));
      await tester.pump();
      expect(karten(), [true, true, true]);
    });

    testWidgets('Filter mit Mehrfachauswahl', (tester) async {
      await zeige(tester);
      Future<void> tippe(String schluessel) async {
        await tester.tap(find.byKey(ValueKey('filter-$schluessel')));
        await tester.pump();
      }

      expect(find.text(de.filterMaterial), findsOneWidget);
      await tippe('material-BASIC');
      expect(karten(), [false, true, false]);
      await tippe('material-PREMIUM SELECT');
      expect(karten(), [true, true, false]);
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey('filter-material-BASIC')),
            )
            .selected,
        isTrue,
      );
      await tippe('material-BASIC');
      expect(karten(), [true, false, false]);
      await tippe('material-PREMIUM SELECT');
      expect(karten(), [true, true, true]);

      await tippe('oberseite-glatt');
      expect(karten(), [false, true, false]);
      await tippe('oberseite-glatt');
      expect(find.byKey(const ValueKey('filter-oberseite-bombiert')), findsOne);

      await tippe('breite-60 mm');
      expect(karten(), [true, false, false]);
      await tippe('breite-60 mm');
      await tippe('staerke-26 mm');
      expect(karten(), [false, true, false]);
      await tippe('staerke-26 mm');
      await tippe('laenge-3000 mm');
      expect(karten(), [true, false, false]);
      await tippe('laenge-5000 mm');
      expect(karten(), [true, true, false]);
      await tippe('laenge-3000 mm');
      await tippe('laenge-5000 mm');
      expect(karten(), [true, true, true]);
    });

    testWidgets('Suche und „Filter zurücksetzen“', (tester) async {
      await zeige(tester);
      await tester.enterText(
        find.byKey(const ValueKey('belag-suche')),
        'fliese',
      );
      await tester.pump();
      expect(karten(), [false, false, true]);
      await tester.enterText(
        find.byKey(const ValueKey('belag-suche')),
        'gibt es nicht',
      );
      await tester.pump();
      expect(karten(), [false, false, false]);
      expect(find.text(de.belagKeinTreffer), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kategorie-sichtbar')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('filter-zuruecksetzen')));
      await tester.pump();
      // die Suche bleibt im Feld stehen, der Filter ist leer
      expect(karten(), [true, true, true]);
      expect(find.text(de.belagKeinTreffer), findsNothing);
    });

    testWidgets('Infobox mit allen Feldern', (tester) async {
      await zeige(tester);
      await tester.tap(find.byKey(const ValueKey('info-10-10-060-R')));
      await tester.pumpAndSettle();
      final info = find.byKey(const ValueKey('belag-info'));
      expect(info, findsOneWidget);
      Finder inInfo(String text) =>
          find.descendant(of: info, matching: find.text(text));
      for (final text in [
        'Diele genutet 60',
        'Material: Robinie PREMIUM SELECT',
        'Profil: genutet',
        'Oberseite: bombiert',
        'Abmessungen: 3000/4000 × 60 × 22 mm',
        'Preis je lfm: 12,50 € inkl. MwSt.',
        'Preis je m²: 192,31 € inkl. MwSt.',
        'Artikelnummer: 10-10-060-R',
      ]) {
        expect(inInfo(text), findsOneWidget, reason: text);
      }
      final bilder = tester
          .widgetList<Artikelbild>(
            find.descendant(of: info, matching: find.byType(Artikelbild)),
          )
          .map((b) => (b.bild, b.groesse));
      expect(bilder, [('a.jpg', 160), ('b.jpg', 160)]);
      await tester.tap(
        find.descendant(of: info, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();
      expect(info, findsNothing);
      // Info öffnen wählt nichts aus: der Dialog bleibt offen
      expect(karten(), [true, true, true]);
    });

    testWidgets('Infobox ohne Holzangaben und ohne Bild', (tester) async {
      await zeige(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('info-70-10-001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('info-70-10-001')));
      await tester.pumpAndSettle();
      final info = find.byKey(const ValueKey('belag-info'));
      expect(
        find.descendant(of: info, matching: find.textContaining('Material')),
        findsNothing,
      );
      expect(
        find.descendant(of: info, matching: find.textContaining('Profil')),
        findsNothing,
      );
      expect(
        find.descendant(of: info, matching: find.textContaining('Oberseite')),
        findsNothing,
      );
      expect(
        find.descendant(of: info, matching: find.byType(Artikelbild)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: info,
          matching: find.text('Artikelnummer: 70-10-001'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Texte auf Englisch', (tester) async {
      expect(en.produktauswahl, 'Product selection');
      expect(kategorieText(en, Belagkategorie.holzfliese), 'Wood tile');
      expect(oberseiteText(en, Oberseite.bombiert), 'convex');
      expect(profilText(en, Profil.glattkant), 'square edge');
    });
  });

  group('Dielenlänge automatisch ermitteln', () {
    late PlanungsSteuerung planung;
    late BelagQuelle quelle;
    late int aenderungen;

    Future<void> zeige(WidgetTester tester, Belagauswahl auswahl) async {
      planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      quelle = BelagQuelle(() async => auswahl);
      addTearDown(quelle.dispose);
      aenderungen = 0;
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: DielenlaengeWahl(
              quelle: quelle,
              planung: planung,
              onGeaendert: () => aenderungen++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool gewaehlt(WidgetTester tester, String key) =>
        tester.widget<ChoiceChip>(find.byKey(ValueKey(key))).selected;

    testWidgets('Vorgabe Ja ohne Längen', (tester) async {
      await zeige(tester, _auswahl);
      expect(find.text('Ja'), findsOneWidget);
      expect(find.text('Nein'), findsOneWidget);
      expect(gewaehlt(tester, 'dielenlaenge-automatisch'), isTrue);
      expect(gewaehlt(tester, 'dielenlaenge-fest'), isFalse);
      expect(find.text('Mögliche Originallängen (in cm):'), findsNothing);
      expect(planung.aktuell.dielenlaenge, isNull);
      expect(aenderungen, 0);
    });

    testWidgets('Nein beginnt mit der längsten Länge, Wahl und zurück', (
      tester,
    ) async {
      await zeige(tester, _auswahl);
      await tester.tap(find.byKey(const ValueKey('dielenlaenge-fest')));
      await tester.pumpAndSettle();
      expect(planung.aktuell.dielenlaenge, const Millimeter(4000));
      expect(aenderungen, 1);
      expect(find.text('Mögliche Originallängen (in cm):'), findsOneWidget);
      expect(find.text('300 cm'), findsOneWidget);
      expect(find.text('400 cm'), findsOneWidget);
      expect(gewaehlt(tester, 'dielenlaenge-fest'), isTrue);
      expect(gewaehlt(tester, 'dielenlaenge-automatisch'), isFalse);
      expect(gewaehlt(tester, 'dielenlaenge-4000'), isTrue);

      await tester.tap(find.byKey(const ValueKey('dielenlaenge-3000')));
      await tester.pumpAndSettle();
      expect(planung.aktuell.dielenlaenge, const Millimeter(3000));
      expect(aenderungen, 2);
      expect(gewaehlt(tester, 'dielenlaenge-3000'), isTrue);
      expect(gewaehlt(tester, 'dielenlaenge-4000'), isFalse);

      await tester.tap(find.byKey(const ValueKey('dielenlaenge-automatisch')));
      await tester.pumpAndSettle();
      expect(planung.aktuell.dielenlaenge, isNull);
      expect(aenderungen, 3);
      // automatisch: nur die Grenzen der Vorgabe Dielenlänge
      expect(find.text('Mögliche Originallängen (in cm):'), findsNothing);
      expect(find.text('300 cm'), findsNWidgets(2));
    });

    testWidgets('Vorgabe Dielenlänge höchstens/mindestens (Planungskern v9 '
        'Regel 11.1): beliebig oder eine Lieferlänge, nur automatisch', (
      tester,
    ) async {
      await zeige(tester, _auswahl);
      expect(find.text('Dielen höchstens (in cm):'), findsOneWidget);
      expect(find.text('Dielen mindestens (in cm):'), findsOneWidget);
      expect(find.text('beliebig'), findsNWidgets(2));
      expect(gewaehlt(tester, 'dielenlaenge-hoechstens-beliebig'), isTrue);
      expect(gewaehlt(tester, 'dielenlaenge-mindestens-beliebig'), isTrue);
      expect(gewaehlt(tester, 'dielenlaenge-hoechstens-3000'), isFalse);
      await tester.tap(
        find.byKey(const ValueKey('dielenlaenge-hoechstens-3000')),
      );
      await tester.pumpAndSettle();
      expect(planung.aktuell.dielenlaengeHoechstens, const Millimeter(3000));
      expect(planung.aktuell.dielenlaengeMindestens, isNull);
      expect(aenderungen, 1);
      expect(gewaehlt(tester, 'dielenlaenge-hoechstens-3000'), isTrue);
      expect(gewaehlt(tester, 'dielenlaenge-hoechstens-beliebig'), isFalse);
      // erneuter Klick ändert nichts
      await tester.tap(
        find.byKey(const ValueKey('dielenlaenge-hoechstens-3000')),
      );
      await tester.pumpAndSettle();
      expect(aenderungen, 1);
      await tester.tap(
        find.byKey(const ValueKey('dielenlaenge-mindestens-4000')),
      );
      await tester.pumpAndSettle();
      expect(planung.aktuell.dielenlaengeMindestens, const Millimeter(4000));
      expect(planung.aktuell.dielenlaengeHoechstens, const Millimeter(3000));
      expect(aenderungen, 2);
      await tester.tap(
        find.byKey(const ValueKey('dielenlaenge-hoechstens-beliebig')),
      );
      await tester.pumpAndSettle();
      expect(planung.aktuell.dielenlaengeHoechstens, isNull);
      expect(aenderungen, 3);
      await tester.tap(
        find.byKey(const ValueKey('dielenlaenge-hoechstens-beliebig')),
      );
      await tester.pumpAndSettle();
      expect(aenderungen, 3);
      await tester.tap(
        find.byKey(const ValueKey('dielenlaenge-mindestens-beliebig')),
      );
      await tester.pumpAndSettle();
      expect(planung.aktuell.dielenlaengeMindestens, isNull);
      // feste Länge: keine Grenzen
      await tester.tap(find.byKey(const ValueKey('dielenlaenge-fest')));
      await tester.pumpAndSettle();
      expect(find.text('Dielen höchstens (in cm):'), findsNothing);
    });

    testWidgets('erneuter Klick auf die Wahl ändert nichts', (tester) async {
      await zeige(tester, _auswahl);
      await tester.tap(find.byKey(const ValueKey('dielenlaenge-automatisch')));
      await tester.pumpAndSettle();
      expect(aenderungen, 0);
      await tester.tap(find.byKey(const ValueKey('dielenlaenge-fest')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dielenlaenge-fest')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dielenlaenge-4000')));
      await tester.pumpAndSettle();
      expect(aenderungen, 1);
    });

    testWidgets('Länge, die der neue Belag nicht liefert, gilt nicht', (
      tester,
    ) async {
      final zweite = Belagangebot(
        _diele('10-20-060', 'Diele zwei', laengen: [5000, 6000]),
      );
      await zeige(tester, Belagauswahl('v1', [_vorgabe, zweite]));
      planung.setze(
        planung.aktuell
            .mitDielenlaenge(const Millimeter(3000))
            .mitBelag(const Artikelnummer('10-20-060')),
      );
      await tester.pumpAndSettle();
      expect(gewaehlt(tester, 'dielenlaenge-automatisch'), isTrue);
      expect(find.text('Mögliche Originallängen (in cm):'), findsNothing);
    });

    testWidgets('nicht wählbar: Holzfliese, eine Länge, ohne Belag', (
      tester,
    ) async {
      const hinweis = 'Für diesen Belag gibt es keine Längenauswahl.';
      for (final auswahl in [
        Belagauswahl('v1', [_fliese]),
        Belagauswahl('v1', [_glattkant]),
        Belagauswahl('v1', const []),
      ]) {
        await zeige(tester, auswahl);
        expect(find.text(hinweis), findsOneWidget);
        expect(find.byKey(const ValueKey('dielenlaenge-wahl')), findsNothing);
      }
    });
  });

  group('Stoßlinie durch Eckpunkt (R-B20)', () {
    testWidgets('Ecken wählen und abwählen, Teilfläche wählen', (tester) async {
      final mitTeil = Planungsstand.start.mitNeuemAusschnitt();
      final planung = PlanungsSteuerung(
        mitTeil.mitAusschnitt(
          0,
          mitTeil.ausschnitte.first.mitFunktion(
            Ausschnittfunktion.andererBelag,
          ),
        ),
      );
      addTearDown(planung.dispose);
      var aenderungen = 0;
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: StosslinieWahl(
              planung: planung,
              onGeaendert: () => aenderungen++,
            ),
          ),
        ),
      );
      bool gewaehlt(int i) => tester
          .widget<FilterChip>(find.byKey(ValueKey('stosslinie-$i')))
          .selected;
      expect(find.text('Stoßlinie durch Eckpunkt (optional):'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(gewaehlt(2), isFalse);
      expect(find.byKey(const ValueKey('stosslinie-flaeche')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('stosslinie-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stosslinie-1')));
      await tester.pumpAndSettle();
      expect(planung.aktuell.stossecken, [1, 2]);
      expect(gewaehlt(2), isTrue);
      expect(aenderungen, 2);

      await tester.tap(find.byKey(const ValueKey('stosslinie-flaeche')));
      await tester.pumpAndSettle();
      expect(find.text('jede Teilfläche mit dieser Ecke'), findsWidgets);
      expect(find.text('Fläche ohne Ausschnitte'), findsOneWidget);
      await tester.tap(find.text('A1').last);
      await tester.pumpAndSettle();
      expect(planung.aktuell.stossflaeche, 1);
      expect(aenderungen, 3);

      await tester.tap(find.byKey(const ValueKey('stosslinie-1')));
      await tester.pumpAndSettle();
      expect(planung.aktuell.stossecken, [2]);
      expect(planung.aktuell.stossflaeche, 1);
    });
  });

  group('kurze Stücke verbinden', () {
    testWidgets('Vorgabe Nein, Ja und zurück', (tester) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      var aenderungen = 0;
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: KurzeStueckeWahl(
              planung: planung,
              onGeaendert: () => aenderungen++,
            ),
          ),
        ),
      );
      bool gewaehlt(String key) =>
          tester.widget<ChoiceChip>(find.byKey(ValueKey(key))).selected;
      expect(find.byKey(const ValueKey('kurze-stuecke')), findsOneWidget);
      expect(
        find.text('Sollen kurze Dielenstücke miteinander verbunden werden?'),
        findsOneWidget,
      );
      expect(gewaehlt('kurze-stuecke-nein'), isTrue);
      expect(gewaehlt('kurze-stuecke-ja'), isFalse);

      await tester.tap(find.byKey(const ValueKey('kurze-stuecke-nein')));
      await tester.pumpAndSettle();
      expect(aenderungen, 0);

      await tester.tap(find.byKey(const ValueKey('kurze-stuecke-ja')));
      await tester.pumpAndSettle();
      expect(planung.aktuell.kurzeStueckeVerbinden, isTrue);
      expect(aenderungen, 1);
      expect(gewaehlt('kurze-stuecke-ja'), isTrue);
      expect(gewaehlt('kurze-stuecke-nein'), isFalse);

      await tester.tap(find.byKey(const ValueKey('kurze-stuecke-ja')));
      await tester.pumpAndSettle();
      expect(aenderungen, 1);

      await tester.tap(find.byKey(const ValueKey('kurze-stuecke-nein')));
      await tester.pumpAndSettle();
      expect(planung.aktuell.kurzeStueckeVerbinden, isFalse);
      expect(aenderungen, 2);
    });

    testWidgets('Text auf Englisch', (tester) async {
      expect(
        en.kurzeStueckeVerbinden,
        'Should short board pieces be joined together?',
      );
    });
  });

  group('Verlegearten', () {
    testWidgets('Vorgabe Fugenschnitt, Wahl und Hinweise', (tester) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      var aenderungen = 0;
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: VerlegeartWahl(
              planung: planung,
              onGeaendert: () => aenderungen++,
            ),
          ),
        ),
      );
      bool gewaehlt(Verlegeart v) => tester
          .widget<ChoiceChip>(find.byKey(ValueKey('verlegeart-${v.name}')))
          .selected;
      expect(gewaehlt(Verlegeart.fugenschnitt), isTrue);
      for (final (text, hinweis) in [
        ('Fugenschnitt', 'Auf Fuge geschnitten: alle Stöße in einer Linie'),
        (
          'Halbverband',
          'Jede zweite Reihe um eine halbe Diele versetzt; jeder Stoß auf '
              'doppelter UK',
        ),
        (
          'Drittelverband',
          'Jede Reihe um ein Drittel der Diele versetzt; jeder Stoß auf '
              'doppelter UK',
        ),
        (
          'Viertelverband',
          'Jede Reihe um ein Viertel der Diele versetzt; jeder Stoß auf '
              'doppelter UK',
        ),
        (
          'Wechselverband',
          'Stöße unregelmäßig versetzt, nie wie in den beiden Reihen davor; '
              'jeder Stoß auf doppelter UK',
        ),
      ]) {
        expect(find.text(text), findsOneWidget);
        expect(find.byTooltip(hinweis), findsOneWidget);
      }

      await tester.tap(find.byKey(const ValueKey('verlegeart-fugenschnitt')));
      await tester.pumpAndSettle();
      expect(aenderungen, 0);

      for (final (i, art) in [
        Verlegeart.halbverband,
        Verlegeart.drittelverband,
        Verlegeart.viertelverband,
        Verlegeart.wechselverband,
        Verlegeart.fugenschnitt,
      ].indexed) {
        await tester.tap(find.byKey(ValueKey('verlegeart-${art.name}')));
        await tester.pumpAndSettle();
        expect(planung.aktuell.verlegeart, art);
        expect(aenderungen, i + 1);
        for (final v in Verlegeart.values) {
          expect(gewaehlt(v), v == art, reason: v.name);
        }
      }
    });

    testWidgets('Texte auf Englisch', (tester) async {
      expect(
        [for (final v in Verlegeart.values) verlegeartText(en, v)],
        [
          'Aligned joints',
          'Half bond',
          'Third bond',
          'Quarter bond',
          'Alternating bond',
        ],
      );
      expect(
        [for (final v in Verlegeart.values) verlegeartHinweis(en, v)],
        [
          'Cut on the joint: all butt joints in one line',
          'Every second row offset by half a board; each joint on a double '
              'joist',
          'Each row offset by a third of a board; each joint on a double '
              'joist',
          'Each row offset by a quarter of a board; each joint on a double '
              'joist',
          'Joints offset irregularly, never as in the two rows before; each '
              'joint on a double joist',
        ],
      );
    });
  });

  group('Verlegerichtungen', () {
    testWidgets('Vorgabe waagrecht, Wahl und Feld „Winkel“', (tester) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      var aenderungen = 0;
      await tester.pumpWidget(
        testApp(
          home: Scaffold(
            body: VerlegerichtungWahl(
              planung: planung,
              onGeaendert: () => aenderungen++,
            ),
          ),
        ),
      );
      bool gewaehlt(Verlegerichtung r) => tester
          .widget<ChoiceChip>(find.byKey(ValueKey('verlegerichtung-${r.name}')))
          .selected;
      expect(gewaehlt(Verlegerichtung.waagrecht), isTrue);
      for (final text in [
        'waagrecht',
        'senkrecht',
        '45 Grad',
        '135 Grad',
        'Individueller Verlegewinkel',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      final winkel = find.byKey(const ValueKey('verlegewinkel'));
      expect(winkel, findsNothing);
      await tester.tap(find.byKey(const ValueKey('verlegerichtung-waagrecht')));
      await tester.pumpAndSettle();
      expect(aenderungen, 0);

      for (final (i, richtung) in [
        Verlegerichtung.senkrecht,
        Verlegerichtung.diagonal45,
        Verlegerichtung.diagonal135,
        Verlegerichtung.individuell,
      ].indexed) {
        await tester.tap(
          find.byKey(ValueKey('verlegerichtung-${richtung.name}')),
        );
        await tester.pumpAndSettle();
        expect(planung.aktuell.verlegerichtung, richtung);
        expect(aenderungen, i + 1);
        for (final r in Verlegerichtung.values) {
          expect(gewaehlt(r), r == richtung, reason: r.name);
        }
      }

      // individuell: Feld mit dem Winkel, Enter übernimmt
      expect(find.text('Winkel in Grad'), findsOneWidget);
      expect(tester.widget<TextField>(winkel).controller!.text, '30');
      for (final falsch in ['180', '-1', 'x', '12.5']) {
        await tester.enterText(winkel, falsch);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(
          find.text('Bitte ganze Grad von 0 bis 179 eingeben'),
          findsOneWidget,
          reason: falsch,
        );
        expect(planung.aktuell.verlegewinkel, 30);
        expect(aenderungen, 4);
      }
      await tester.enterText(winkel, ' 60 ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(planung.aktuell.verlegewinkel, 60);
      expect(planung.aktuell.dielenwinkel, 60);
      expect(aenderungen, 5);
      expect(
        find.text('Bitte ganze Grad von 0 bis 179 eingeben'),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('verlegerichtung-waagrecht')));
      await tester.pumpAndSettle();
      expect(winkel, findsNothing);
      expect(planung.aktuell.verlegewinkel, 60);
    });

    test('Texte auf Englisch', () {
      expect(
        [for (final r in Verlegerichtung.values) verlegerichtungText(en, r)],
        [
          'Horizontal',
          'Vertical',
          '45 degrees',
          '135 degrees',
          'Custom laying angle',
        ],
      );
      expect(en.verlegewinkel, 'Angle in degrees');
      expect(
        en.verlegewinkelUngueltig,
        'Please enter whole degrees from 0 to 179',
      );
    });
  });

  testWidgets('im Rahmen: Unterpunkt „Terrassenbelag auswählen“', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand();
    await tester.pumpWidget(
      testApp(
        theme: planerThema(),
        home: PlanerRahmen(
          status: const Text('Status'),
          zustand: zustand,
          belaege: () async => _auswahl,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('belag-anzeige')), findsNothing);
    zustand.waehle(PlanerSchritt.terrassenbelag);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('belag-anzeige')), findsOneWidget);
    expect(find.byKey(const ValueKey('dielenlaenge-wahl')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dielenlaenge-fest')));
    await tester.pumpAndSettle();
    expect(zustand.unveraendert, isNot(contains(PlanerSchritt.terrassenbelag)));
    await tester.tap(find.byKey(const ValueKey('dielenlaenge-automatisch')));
    await tester.pumpAndSettle();
    // die Grenzen der Vorgabe Dielenlänge (Regel 11.1) machen den Schritt
    // länger: bis zur Verlegeart blättern
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('verlegeart-halbverband')),
      200,
      scrollable: find
          .ancestor(
            of: find.byKey(const ValueKey('dielenlaenge-wahl')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('verlegeart-halbverband')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('verlegeart-halbverband')),
          )
          .selected,
      isTrue,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('kurze-stuecke-ja')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kurze-stuecke-ja')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const ValueKey('kurze-stuecke-ja')))
          .selected,
      isTrue,
    );
    // Stoßlinie durch Eckpunkt (R-B20)
    final ecke = find.byKey(const ValueKey('stosslinie-2'));
    await tester.ensureVisible(ecke);
    await tester.pumpAndSettle();
    await tester.tap(ecke);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(ecke).selected, isTrue);
    // 2.4 Verlegerichtungen (M5-05)
    final senkrecht = find.byKey(const ValueKey('verlegerichtung-senkrecht'));
    await tester.ensureVisible(senkrecht);
    await tester.pumpAndSettle();
    await tester.tap(senkrecht);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(senkrecht).selected, isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('produktauswahl')),
      -200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('bearbeitungsmenue')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('produktauswahl')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('belag-70-10-001')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('belag-70-10-001')));
    await tester.pumpAndSettle();
    expect(find.text('Terrassenfliese'), findsOneWidget);
    expect(zustand.unveraendert, isNot(contains(PlanerSchritt.terrassenbelag)));
    // Unterpunkt 2.2 hört auf den gewählten Belag.
    expect(
      find.text('Für diesen Belag gibt es keine Längenauswahl.'),
      findsOneWidget,
    );
    // Ohne Belagquelle zeigt der Schritt nur seine Unterpunkte.
    await tester.pumpWidget(
      testApp(
        theme: planerThema(),
        home: PlanerRahmen(
          key: const ValueKey('ohne-belaege'),
          status: const Text('Status'),
          zustand: zustand,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('belag-anzeige')), findsNothing);
  });
}
