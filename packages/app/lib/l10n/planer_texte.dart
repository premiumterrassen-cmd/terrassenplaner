// coverage:ignore-file
// Von `flutter gen-l10n` erzeugt – nicht von Hand ändern.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'planer_texte_de.dart';
import 'planer_texte_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of PlanerTexte
/// returned by `PlanerTexte.of(context)`.
///
/// Applications need to include `PlanerTexte.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/planer_texte.dart';
///
/// return MaterialApp(
///   localizationsDelegates: PlanerTexte.localizationsDelegates,
///   supportedLocales: PlanerTexte.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the PlanerTexte.supportedLocales
/// property.
abstract class PlanerTexte {
  PlanerTexte(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static PlanerTexte of(BuildContext context) {
    return Localizations.of<PlanerTexte>(context, PlanerTexte)!;
  }

  static const LocalizationsDelegate<PlanerTexte> delegate =
      _PlanerTexteDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// Name der Sprache in der Sprachauswahl, in der Sprache selbst
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get sprachname;

  /// No description provided for @sprache.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get sprache;

  /// Auswahl hell/dunkel/wie System in der Kopfzeile (M3-09)
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get darstellung;

  /// No description provided for @darstellungHell.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get darstellungHell;

  /// No description provided for @darstellungDunkel.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get darstellungDunkel;

  /// No description provided for @darstellungSystem.
  ///
  /// In de, this message translates to:
  /// **'Wie System'**
  String get darstellungSystem;

  /// No description provided for @planerTitel.
  ///
  /// In de, this message translates to:
  /// **'TERRASSENKONFIGURATOR'**
  String get planerTitel;

  /// No description provided for @logoBeschreibung.
  ///
  /// In de, this message translates to:
  /// **'RobinienWelt'**
  String get logoBeschreibung;

  /// No description provided for @folgt.
  ///
  /// In de, this message translates to:
  /// **'Diese Funktion folgt in Kürze.'**
  String get folgt;

  /// No description provided for @verbinde.
  ///
  /// In de, this message translates to:
  /// **'Verbinde mit dem Server …'**
  String get verbinde;

  /// No description provided for @keineVerbindung.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung zum Server'**
  String get keineVerbindung;

  /// No description provided for @zuruecksetzen.
  ///
  /// In de, this message translates to:
  /// **'ZURÜCKSETZEN'**
  String get zuruecksetzen;

  /// No description provided for @videoberatung.
  ///
  /// In de, this message translates to:
  /// **'Video-Beratung buchen'**
  String get videoberatung;

  /// No description provided for @pdf.
  ///
  /// In de, this message translates to:
  /// **'PDF'**
  String get pdf;

  /// No description provided for @anfordern.
  ///
  /// In de, this message translates to:
  /// **'KONFIGURATION ANFORDERN'**
  String get anfordern;

  /// No description provided for @anfordernKurz.
  ///
  /// In de, this message translates to:
  /// **'ANFORDERN'**
  String get anfordernKurz;

  /// No description provided for @fortschritt.
  ///
  /// In de, this message translates to:
  /// **'Fortschritt'**
  String get fortschritt;

  /// No description provided for @menuEinklappen.
  ///
  /// In de, this message translates to:
  /// **'Menü einklappen'**
  String get menuEinklappen;

  /// No description provided for @menuAusklappen.
  ///
  /// In de, this message translates to:
  /// **'Menü ausklappen'**
  String get menuAusklappen;

  /// No description provided for @flaeche.
  ///
  /// In de, this message translates to:
  /// **'Fläche: {wert}'**
  String flaeche(String wert);

  /// No description provided for @volumen.
  ///
  /// In de, this message translates to:
  /// **'Volumen: {wert}'**
  String volumen(String wert);

  /// No description provided for @massPlatzhalter.
  ///
  /// In de, this message translates to:
  /// **'{kante}: cm'**
  String massPlatzhalter(String kante);

  /// No description provided for @formRechteck.
  ///
  /// In de, this message translates to:
  /// **'Rechteck'**
  String get formRechteck;

  /// No description provided for @formLForm.
  ///
  /// In de, this message translates to:
  /// **'L-Form'**
  String get formLForm;

  /// No description provided for @formTForm.
  ///
  /// In de, this message translates to:
  /// **'T-Form'**
  String get formTForm;

  /// No description provided for @formUForm.
  ///
  /// In de, this message translates to:
  /// **'U-Form'**
  String get formUForm;

  /// No description provided for @formOForm.
  ///
  /// In de, this message translates to:
  /// **'O-Form'**
  String get formOForm;

  /// No description provided for @formKreis.
  ///
  /// In de, this message translates to:
  /// **'Kreis'**
  String get formKreis;

  /// No description provided for @formFreiform.
  ///
  /// In de, this message translates to:
  /// **'Freiform'**
  String get formFreiform;

  /// No description provided for @freiformHinweis.
  ///
  /// In de, this message translates to:
  /// **'Punkte setzen – [x] zum Schließen der Form'**
  String get freiformHinweis;

  /// No description provided for @einrastfunktion.
  ///
  /// In de, this message translates to:
  /// **'Einrastfunktion'**
  String get einrastfunktion;

  /// No description provided for @zeichnungshilfe.
  ///
  /// In de, this message translates to:
  /// **'Zeichnungshilfe'**
  String get zeichnungshilfe;

  /// No description provided for @eingabeStrecke.
  ///
  /// In de, this message translates to:
  /// **'Strecke'**
  String get eingabeStrecke;

  /// No description provided for @eingabeKoordinaten.
  ///
  /// In de, this message translates to:
  /// **'Koordinaten'**
  String get eingabeKoordinaten;

  /// No description provided for @feldWinkel.
  ///
  /// In de, this message translates to:
  /// **'Winkel'**
  String get feldWinkel;

  /// No description provided for @winkelPlatzhalter.
  ///
  /// In de, this message translates to:
  /// **'{feld}: °'**
  String winkelPlatzhalter(String feld);

  /// No description provided for @letztenPunktEntfernen.
  ///
  /// In de, this message translates to:
  /// **'Letzten Punkt entfernen'**
  String get letztenPunktEntfernen;

  /// No description provided for @formSchliessen.
  ///
  /// In de, this message translates to:
  /// **'Form schließen'**
  String get formSchliessen;

  /// No description provided for @formGeschlossen.
  ///
  /// In de, this message translates to:
  /// **'Form geschlossen'**
  String get formGeschlossen;

  /// No description provided for @punktAusgewaehlt.
  ///
  /// In de, this message translates to:
  /// **'Punkt {name}'**
  String punktAusgewaehlt(String name);

  /// No description provided for @eckeAntippen.
  ///
  /// In de, this message translates to:
  /// **'Ecke antippen, um sie zu bearbeiten; an der Kantenmitte ziehen verschiebt die Kante, antippen fügt einen Punkt ein.'**
  String get eckeAntippen;

  /// No description provided for @punktEntfernen.
  ///
  /// In de, this message translates to:
  /// **'Punkt entfernen'**
  String get punktEntfernen;

  /// No description provided for @freiformMindestens3.
  ///
  /// In de, this message translates to:
  /// **'Die Form braucht mindestens 3 Punkte.'**
  String get freiformMindestens3;

  /// No description provided for @freiformKreuzt.
  ///
  /// In de, this message translates to:
  /// **'Die Kanten dürfen sich nicht kreuzen.'**
  String get freiformKreuzt;

  /// No description provided for @freiformKante.
  ///
  /// In de, this message translates to:
  /// **'Kanten müssen {min} bis {max} cm lang sein.'**
  String freiformKante(int min, int max);

  /// No description provided for @ausschnittTitel.
  ///
  /// In de, this message translates to:
  /// **'Ausschnitt {bezeichnung}'**
  String ausschnittTitel(String bezeichnung);

  /// No description provided for @feldLaenge.
  ///
  /// In de, this message translates to:
  /// **'Länge'**
  String get feldLaenge;

  /// No description provided for @feldBreite.
  ///
  /// In de, this message translates to:
  /// **'Breite'**
  String get feldBreite;

  /// No description provided for @massUngueltig.
  ///
  /// In de, this message translates to:
  /// **'Bitte {min} bis {max} cm eingeben'**
  String massUngueltig(int min, int max);

  /// No description provided for @berechnungFehler.
  ///
  /// In de, this message translates to:
  /// **'Berechnung nicht möglich – bitte Verbindung prüfen'**
  String get berechnungFehler;

  /// No description provided for @agb.
  ///
  /// In de, this message translates to:
  /// **'AGB'**
  String get agb;

  /// No description provided for @datenschutz.
  ///
  /// In de, this message translates to:
  /// **'Datenschutz'**
  String get datenschutz;

  /// No description provided for @impressum.
  ///
  /// In de, this message translates to:
  /// **'Impressum'**
  String get impressum;

  /// No description provided for @zuruecksetzenTitel.
  ///
  /// In de, this message translates to:
  /// **'Planung zurücksetzen?'**
  String get zuruecksetzenTitel;

  /// No description provided for @zuruecksetzenText.
  ///
  /// In de, this message translates to:
  /// **'Sind Sie sicher, dass Sie die Planung zurücksetzen möchten? Dadurch geht Ihr Fortschritt verloren. Stellen Sie sicher, dass Sie die Konfiguration gespeichert und die Konfigurationsnummer notiert haben.'**
  String get zuruecksetzenText;

  /// No description provided for @zuruecksetzenZurueck.
  ///
  /// In de, this message translates to:
  /// **'Zurück zur Konfiguration'**
  String get zuruecksetzenZurueck;

  /// No description provided for @zuruecksetzenBestaetigen.
  ///
  /// In de, this message translates to:
  /// **'Konfiguration zurücksetzen'**
  String get zuruecksetzenBestaetigen;

  /// No description provided for @standardwertTitel.
  ///
  /// In de, this message translates to:
  /// **'Standardwerte beibehalten'**
  String get standardwertTitel;

  /// No description provided for @standardwertText.
  ///
  /// In de, this message translates to:
  /// **'In diesen Schritten haben Sie nichts verändert – dort gelten die Standardwerte des Planers:'**
  String get standardwertText;

  /// No description provided for @standardwertFrage.
  ///
  /// In de, this message translates to:
  /// **'Möchten Sie trotzdem fortfahren?'**
  String get standardwertFrage;

  /// No description provided for @zurueck.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get zurueck;

  /// No description provided for @fortfahren.
  ///
  /// In de, this message translates to:
  /// **'Fortfahren'**
  String get fortfahren;

  /// No description provided for @rueckgaengig.
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get rueckgaengig;

  /// No description provided for @wiederherstellen.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellen'**
  String get wiederherstellen;

  /// No description provided for @zentrieren.
  ///
  /// In de, this message translates to:
  /// **'Zentrieren'**
  String get zentrieren;

  /// No description provided for @rundungenHinzufuegen.
  ///
  /// In de, this message translates to:
  /// **'Rundungen hinzufügen'**
  String get rundungenHinzufuegen;

  /// No description provided for @rundungenUebernehmen.
  ///
  /// In de, this message translates to:
  /// **'Rundungen übernehmen'**
  String get rundungenUebernehmen;

  /// No description provided for @rundungenZuruecksetzen.
  ///
  /// In de, this message translates to:
  /// **'Rundungen zurücksetzen'**
  String get rundungenZuruecksetzen;

  /// No description provided for @rundungHinweis.
  ///
  /// In de, this message translates to:
  /// **'Griff an einer Ecke nach innen ziehen rundet die Ecke ab, Griff auf einer Seite zieht sie zum Bogen. Änderungen übernehmen (ESC).'**
  String get rundungHinweis;

  /// No description provided for @rundungEcke.
  ///
  /// In de, this message translates to:
  /// **'Ecke {name}'**
  String rundungEcke(String name);

  /// No description provided for @rundungSeite.
  ///
  /// In de, this message translates to:
  /// **'Seite ab {name}'**
  String rundungSeite(String name);

  /// No description provided for @feldRadius.
  ///
  /// In de, this message translates to:
  /// **'Radius'**
  String get feldRadius;

  /// No description provided for @feldStich.
  ///
  /// In de, this message translates to:
  /// **'Stich'**
  String get feldStich;

  /// No description provided for @rundungEntfernen.
  ///
  /// In de, this message translates to:
  /// **'Rundung entfernen'**
  String get rundungEntfernen;

  /// No description provided for @rundungUnzulaessig.
  ///
  /// In de, this message translates to:
  /// **'Diese Rundung ist nicht möglich.'**
  String get rundungUnzulaessig;

  /// No description provided for @rundungVerlassenTitel.
  ///
  /// In de, this message translates to:
  /// **'Rundungen übernehmen?'**
  String get rundungVerlassenTitel;

  /// No description provided for @rundungVerlassenText.
  ///
  /// In de, this message translates to:
  /// **'Sie verlassen das Abrunden von Ecken und Seiten.'**
  String get rundungVerlassenText;

  /// No description provided for @formDrehen.
  ///
  /// In de, this message translates to:
  /// **'Form drehen'**
  String get formDrehen;

  /// No description provided for @drehenTitel.
  ///
  /// In de, this message translates to:
  /// **'Form drehen?'**
  String get drehenTitel;

  /// No description provided for @drehenText.
  ///
  /// In de, this message translates to:
  /// **'Beim Drehen werden alle Ausschnitte zurückgesetzt.'**
  String get drehenText;

  /// No description provided for @drehenBestaetigen.
  ///
  /// In de, this message translates to:
  /// **'Drehen'**
  String get drehenBestaetigen;

  /// No description provided for @abbrechen.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get abbrechen;

  /// No description provided for @verkleinern.
  ///
  /// In de, this message translates to:
  /// **'Verkleinern'**
  String get verkleinern;

  /// No description provided for @vergroessern.
  ///
  /// In de, this message translates to:
  /// **'Vergrößern'**
  String get vergroessern;

  /// No description provided for @zoom.
  ///
  /// In de, this message translates to:
  /// **'Zoom'**
  String get zoom;

  /// No description provided for @bedienHinweis.
  ///
  /// In de, this message translates to:
  /// **'Mausrad: Zoom · Ziehen: Verschieben'**
  String get bedienHinweis;

  /// No description provided for @beschriftungen.
  ///
  /// In de, this message translates to:
  /// **'Beschriftungen'**
  String get beschriftungen;

  /// Kurz – die drei Ebenen-Knöpfe sind so breit wie der längste
  ///
  /// In de, this message translates to:
  /// **'Belag'**
  String get ebeneBelag;

  /// No description provided for @ebeneUnterkonstruktion.
  ///
  /// In de, this message translates to:
  /// **'UK'**
  String get ebeneUnterkonstruktion;

  /// No description provided for @ebeneMasse.
  ///
  /// In de, this message translates to:
  /// **'Maße'**
  String get ebeneMasse;

  /// No description provided for @ebeneBelagLang.
  ///
  /// In de, this message translates to:
  /// **'Belag'**
  String get ebeneBelagLang;

  /// No description provided for @ebeneUnterkonstruktionLang.
  ///
  /// In de, this message translates to:
  /// **'Unterkonstruktion'**
  String get ebeneUnterkonstruktionLang;

  /// No description provided for @ebeneMasseLang.
  ///
  /// In de, this message translates to:
  /// **'Maße'**
  String get ebeneMasseLang;

  /// No description provided for @beschriftungSeitenlaengen.
  ///
  /// In de, this message translates to:
  /// **'Seitenlängen'**
  String get beschriftungSeitenlaengen;

  /// No description provided for @beschriftungWinkel.
  ///
  /// In de, this message translates to:
  /// **'Winkel'**
  String get beschriftungWinkel;

  /// No description provided for @beschriftungPunkte.
  ///
  /// In de, this message translates to:
  /// **'Punkte'**
  String get beschriftungPunkte;

  /// No description provided for @beschriftungAblaeufe.
  ///
  /// In de, this message translates to:
  /// **'Abläufe'**
  String get beschriftungAblaeufe;

  /// No description provided for @ablauf.
  ///
  /// In de, this message translates to:
  /// **'Ablauf'**
  String get ablauf;

  /// No description provided for @willkommenTitel.
  ///
  /// In de, this message translates to:
  /// **'Willkommen beim RobinienWelt Terrassenkonfigurator!'**
  String get willkommenTitel;

  /// No description provided for @willkommenText.
  ///
  /// In de, this message translates to:
  /// **'Planen Sie Ihre Wunschterrasse aus Robinie mit wenigen Klicks: Dielen, Verlegung und Unterkonstruktion wählen Sie selbst. Danach bestellen Sie direkt oder fordern ein Angebot an. Persönliche Hilfe bekommen Sie in der Video-Beratung.'**
  String get willkommenText;

  /// No description provided for @konfigurationLadenKnopf.
  ///
  /// In de, this message translates to:
  /// **'KONFIGURATION LADEN'**
  String get konfigurationLadenKnopf;

  /// No description provided for @neuKnopf.
  ///
  /// In de, this message translates to:
  /// **'WUNSCHTERRASSE KONFIGURIEREN'**
  String get neuKnopf;

  /// No description provided for @gefunden.
  ///
  /// In de, this message translates to:
  /// **'Wir haben eine Konfiguration gefunden. Möchten Sie mit dieser weiterplanen? ({nummer}, Version {version})'**
  String gefunden(String nummer, int version);

  /// No description provided for @weiterplanen.
  ///
  /// In de, this message translates to:
  /// **'WEITERPLANEN'**
  String get weiterplanen;

  /// No description provided for @ladenTitel.
  ///
  /// In de, this message translates to:
  /// **'Konfiguration laden'**
  String get ladenTitel;

  /// No description provided for @nummerFeld.
  ///
  /// In de, this message translates to:
  /// **'Konfigurationsnummer'**
  String get nummerFeld;

  /// No description provided for @nummerHinweis.
  ///
  /// In de, this message translates to:
  /// **'z. B. 2026-10-08-1511'**
  String get nummerHinweis;

  /// No description provided for @nummerFehler.
  ///
  /// In de, this message translates to:
  /// **'Bitte im Format JJJJ-MM-TT-NNNN eingeben'**
  String get nummerFehler;

  /// No description provided for @version.
  ///
  /// In de, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @ladeFehler.
  ///
  /// In de, this message translates to:
  /// **'Die Konfiguration konnte nicht geladen werden.'**
  String get ladeFehler;

  /// No description provided for @modell3dTitel.
  ///
  /// In de, this message translates to:
  /// **'3D-Vorschau (Prototyp): Terrasse 4 x 3 m'**
  String get modell3dTitel;

  /// No description provided for @modell3dLaedt.
  ///
  /// In de, this message translates to:
  /// **'Lade 3D-Modell …'**
  String get modell3dLaedt;

  /// No description provided for @modell3dFehler.
  ///
  /// In de, this message translates to:
  /// **'3D-Modell konnte nicht geladen werden'**
  String get modell3dFehler;

  /// No description provided for @nurImBrowser.
  ///
  /// In de, this message translates to:
  /// **'Die 3D-Ansicht gibt es nur im Browser.'**
  String get nurImBrowser;

  /// No description provided for @keinBild.
  ///
  /// In de, this message translates to:
  /// **'Kein Bild'**
  String get keinBild;

  /// No description provided for @schrittGrundriss.
  ///
  /// In de, this message translates to:
  /// **'GRUNDRISS'**
  String get schrittGrundriss;

  /// No description provided for @schrittTerrassenbelag.
  ///
  /// In de, this message translates to:
  /// **'TERRASSENBELAG'**
  String get schrittTerrassenbelag;

  /// Für schmale Stationen auf zwei Zeilen getrennt
  ///
  /// In de, this message translates to:
  /// **'TERRASSEN-\nBELAG'**
  String get schrittTerrassenbelagGetrennt;

  /// No description provided for @schrittUnterkonstruktion.
  ///
  /// In de, this message translates to:
  /// **'UNTERKONSTRUKTION'**
  String get schrittUnterkonstruktion;

  /// No description provided for @schrittUnterkonstruktionGetrennt.
  ///
  /// In de, this message translates to:
  /// **'UNTER-\nKONSTRUKTION'**
  String get schrittUnterkonstruktionGetrennt;

  /// No description provided for @schrittTerrassenanschluss.
  ///
  /// In de, this message translates to:
  /// **'TERRASSENANSCHLUSS'**
  String get schrittTerrassenanschluss;

  /// No description provided for @schrittTerrassenanschlussGetrennt.
  ///
  /// In de, this message translates to:
  /// **'TERRASSEN-\nANSCHLUSS'**
  String get schrittTerrassenanschlussGetrennt;

  /// No description provided for @schrittTreppen.
  ///
  /// In de, this message translates to:
  /// **'TREPPEN'**
  String get schrittTreppen;

  /// No description provided for @schrittZubehoer.
  ///
  /// In de, this message translates to:
  /// **'ZUBEHÖR'**
  String get schrittZubehoer;

  /// No description provided for @schrittVerschnittoptimierung.
  ///
  /// In de, this message translates to:
  /// **'VERSCHNITTOPTIMIERUNG'**
  String get schrittVerschnittoptimierung;

  /// No description provided for @schrittVerschnittoptimierungGetrennt.
  ///
  /// In de, this message translates to:
  /// **'VERSCHNITT-\nOPTIMIERUNG'**
  String get schrittVerschnittoptimierungGetrennt;

  /// No description provided for @grundriss1.
  ///
  /// In de, this message translates to:
  /// **'Terrassenform auswählen'**
  String get grundriss1;

  /// No description provided for @grundriss2.
  ///
  /// In de, this message translates to:
  /// **'Terrassenmaße'**
  String get grundriss2;

  /// No description provided for @grundriss3.
  ///
  /// In de, this message translates to:
  /// **'Ecken und Seiten abrunden'**
  String get grundriss3;

  /// No description provided for @grundriss4.
  ///
  /// In de, this message translates to:
  /// **'Ausschnitte und Teilflächen'**
  String get grundriss4;

  /// No description provided for @terrassenbelag1.
  ///
  /// In de, this message translates to:
  /// **'Terrassenbelag auswählen'**
  String get terrassenbelag1;

  /// No description provided for @terrassenbelag2.
  ///
  /// In de, this message translates to:
  /// **'Dielenlänge automatisch ermitteln'**
  String get terrassenbelag2;

  /// No description provided for @terrassenbelag3.
  ///
  /// In de, this message translates to:
  /// **'Verlegearten'**
  String get terrassenbelag3;

  /// No description provided for @terrassenbelag4.
  ///
  /// In de, this message translates to:
  /// **'Verlegerichtungen'**
  String get terrassenbelag4;

  /// No description provided for @terrassenbelag5.
  ///
  /// In de, this message translates to:
  /// **'Ausgangspunkt des Belags'**
  String get terrassenbelag5;

  /// No description provided for @unterkonstruktion1.
  ///
  /// In de, this message translates to:
  /// **'Art der Terrasse'**
  String get unterkonstruktion1;

  /// No description provided for @unterkonstruktion2.
  ///
  /// In de, this message translates to:
  /// **'Höhenpunkte'**
  String get unterkonstruktion2;

  /// No description provided for @unterkonstruktion3.
  ///
  /// In de, this message translates to:
  /// **'Unterkonstruktion auswählen'**
  String get unterkonstruktion3;

  /// No description provided for @unterkonstruktion4.
  ///
  /// In de, this message translates to:
  /// **'Länge der Unterkonstruktion'**
  String get unterkonstruktion4;

  /// No description provided for @unterkonstruktion5.
  ///
  /// In de, this message translates to:
  /// **'Untergrund'**
  String get unterkonstruktion5;

  /// No description provided for @unterkonstruktion6.
  ///
  /// In de, this message translates to:
  /// **'Art der Terrassennutzung'**
  String get unterkonstruktion6;

  /// No description provided for @unterkonstruktion7.
  ///
  /// In de, this message translates to:
  /// **'Querstreben'**
  String get unterkonstruktion7;

  /// No description provided for @unterkonstruktion8.
  ///
  /// In de, this message translates to:
  /// **'Nutzung privat oder gewerblich'**
  String get unterkonstruktion8;

  /// No description provided for @terrassenanschluss1.
  ///
  /// In de, this message translates to:
  /// **'Angrenzende Bauelemente'**
  String get terrassenanschluss1;

  /// No description provided for @terrassenanschluss2.
  ///
  /// In de, this message translates to:
  /// **'Verblendung'**
  String get terrassenanschluss2;

  /// No description provided for @terrassenanschluss3.
  ///
  /// In de, this message translates to:
  /// **'Entwässerungsrinnen'**
  String get terrassenanschluss3;

  /// No description provided for @treppen1.
  ///
  /// In de, this message translates to:
  /// **'Treppen'**
  String get treppen1;

  /// No description provided for @zubehoer1.
  ///
  /// In de, this message translates to:
  /// **'Allgemein'**
  String get zubehoer1;

  /// No description provided for @zubehoer2.
  ///
  /// In de, this message translates to:
  /// **'Anlieferung'**
  String get zubehoer2;

  /// No description provided for @zubehoer3.
  ///
  /// In de, this message translates to:
  /// **'Clips & Schrauben'**
  String get zubehoer3;

  /// No description provided for @zubehoer4.
  ///
  /// In de, this message translates to:
  /// **'Höhenausgleich'**
  String get zubehoer4;

  /// No description provided for @zubehoer5.
  ///
  /// In de, this message translates to:
  /// **'Pads & EPDM-Bänder'**
  String get zubehoer5;

  /// No description provided for @zubehoer6.
  ///
  /// In de, this message translates to:
  /// **'Rhombusleisten'**
  String get zubehoer6;

  /// No description provided for @zubehoer7.
  ///
  /// In de, this message translates to:
  /// **'Terrassenfliesen'**
  String get zubehoer7;

  /// No description provided for @zubehoer8.
  ///
  /// In de, this message translates to:
  /// **'Terrassenöl RIBOL'**
  String get zubehoer8;

  /// No description provided for @verschnittoptimierung1.
  ///
  /// In de, this message translates to:
  /// **'Verschnittvariante auswählen'**
  String get verschnittoptimierung1;
}

class _PlanerTexteDelegate extends LocalizationsDelegate<PlanerTexte> {
  const _PlanerTexteDelegate();

  @override
  Future<PlanerTexte> load(Locale locale) {
    return SynchronousFuture<PlanerTexte>(lookupPlanerTexte(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_PlanerTexteDelegate old) => false;
}

PlanerTexte lookupPlanerTexte(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return PlanerTexteDe();
    case 'en':
      return PlanerTexteEn();
  }

  throw FlutterError(
    'PlanerTexte.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
