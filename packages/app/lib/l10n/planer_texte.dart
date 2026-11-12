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

  /// No description provided for @speichern.
  ///
  /// In de, this message translates to:
  /// **'SPEICHERN'**
  String get speichern;

  /// No description provided for @laden.
  ///
  /// In de, this message translates to:
  /// **'LADEN'**
  String get laden;

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

  /// No description provided for @gesamtflaeche.
  ///
  /// In de, this message translates to:
  /// **'Gesamtfläche: {wert}'**
  String gesamtflaeche(String wert);

  /// No description provided for @flaecheReiter.
  ///
  /// In de, this message translates to:
  /// **'Fläche {nummer}'**
  String flaecheReiter(int nummer);

  /// No description provided for @flaecheHinzufuegen.
  ///
  /// In de, this message translates to:
  /// **'Fläche hinzufügen'**
  String get flaecheHinzufuegen;

  /// No description provided for @flaecheLoeschen.
  ///
  /// In de, this message translates to:
  /// **'Fläche löschen'**
  String get flaecheLoeschen;

  /// No description provided for @haeufigkeit.
  ///
  /// In de, this message translates to:
  /// **'Häufigkeit der Fläche'**
  String get haeufigkeit;

  /// No description provided for @haeufigkeitHinweis.
  ///
  /// In de, this message translates to:
  /// **'Wie oft diese Fläche gebaut wird. Die Materialmengen werden entsprechend vervielfacht.'**
  String get haeufigkeitHinweis;

  /// No description provided for @haeufigkeitWeniger.
  ///
  /// In de, this message translates to:
  /// **'Seltener'**
  String get haeufigkeitWeniger;

  /// No description provided for @haeufigkeitMehr.
  ///
  /// In de, this message translates to:
  /// **'Öfter'**
  String get haeufigkeitMehr;

  /// No description provided for @volumen.
  ///
  /// In de, this message translates to:
  /// **'Volumen: {wert}'**
  String volumen(String wert);

  /// No description provided for @verschnitt.
  ///
  /// In de, this message translates to:
  /// **'Verschnitt: {wert}'**
  String verschnitt(String wert);

  /// No description provided for @benoetigteDielen.
  ///
  /// In de, this message translates to:
  /// **'Benötigte Dielen:'**
  String get benoetigteDielen;

  /// No description provided for @keineDielen.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Dielen verlegt.'**
  String get keineDielen;

  /// No description provided for @verschnittNichtOptimiert.
  ///
  /// In de, this message translates to:
  /// **'Der Verschnitt ist noch nicht optimiert – die Optimierung verteilt die Stücke über alle Flächen und verringert oft den Bedarf an Dielen.'**
  String get verschnittNichtOptimiert;

  /// No description provided for @optimierungErstellen.
  ///
  /// In de, this message translates to:
  /// **'OPTIMIERUNG ERSTELLEN'**
  String get optimierungErstellen;

  /// No description provided for @optimierungZuruecksetzen.
  ///
  /// In de, this message translates to:
  /// **'OPTIMIERUNG ZURÜCKSETZEN'**
  String get optimierungZuruecksetzen;

  /// No description provided for @verschnittauswahlGeaendert.
  ///
  /// In de, this message translates to:
  /// **'Die Verschnittauswahl wurde geändert!'**
  String get verschnittauswahlGeaendert;

  /// No description provided for @materialNichtOptimiert.
  ///
  /// In de, this message translates to:
  /// **'Hinweis: Der Verschnitt ist noch nicht optimiert. Unter „7. Verschnittoptimierung“ lässt sich der Bedarf an Dielen oft verringern.'**
  String get materialNichtOptimiert;

  /// No description provided for @verschnittvariante.
  ///
  /// In de, this message translates to:
  /// **'Variante {nummer}'**
  String verschnittvariante(int nummer);

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

  /// No description provided for @massInCm.
  ///
  /// In de, this message translates to:
  /// **'Über 50 m – bitte das Maß in cm angeben'**
  String get massInCm;

  /// No description provided for @berechnungFehler.
  ///
  /// In de, this message translates to:
  /// **'Berechnung nicht möglich – bitte Verbindung prüfen'**
  String get berechnungFehler;

  /// No description provided for @planungZuAufwendig.
  ///
  /// In de, this message translates to:
  /// **'Die Planung ist zu umfangreich für die Berechnung – bitte weniger oder kleinere Flächen planen oder die Verschnittoptimierung ausschalten'**
  String get planungZuAufwendig;

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

  /// No description provided for @weitereFlaeche.
  ///
  /// In de, this message translates to:
  /// **'Weitere Flächen hinzufügen'**
  String get weitereFlaeche;

  /// No description provided for @ausschnittEntfernen.
  ///
  /// In de, this message translates to:
  /// **'Fläche entfernen'**
  String get ausschnittEntfernen;

  /// No description provided for @formDreieck.
  ///
  /// In de, this message translates to:
  /// **'Dreieck'**
  String get formDreieck;

  /// No description provided for @formSechseck.
  ///
  /// In de, this message translates to:
  /// **'Sechseck'**
  String get formSechseck;

  /// No description provided for @funktionLeer.
  ///
  /// In de, this message translates to:
  /// **'leere Fläche'**
  String get funktionLeer;

  /// No description provided for @funktionBelag.
  ///
  /// In de, this message translates to:
  /// **'anderer Terrassenbelag'**
  String get funktionBelag;

  /// No description provided for @inhaltLeer.
  ///
  /// In de, this message translates to:
  /// **'leer/weiß'**
  String get inhaltLeer;

  /// No description provided for @inhaltKies.
  ///
  /// In de, this message translates to:
  /// **'Kies hell'**
  String get inhaltKies;

  /// No description provided for @inhaltStein.
  ///
  /// In de, this message translates to:
  /// **'Stein dunkel'**
  String get inhaltStein;

  /// No description provided for @inhaltPool.
  ///
  /// In de, this message translates to:
  /// **'Pool'**
  String get inhaltPool;

  /// No description provided for @inhaltRasen.
  ///
  /// In de, this message translates to:
  /// **'Rasen'**
  String get inhaltRasen;

  /// No description provided for @inhaltErde.
  ///
  /// In de, this message translates to:
  /// **'Erde'**
  String get inhaltErde;

  /// No description provided for @feldBezeichnung.
  ///
  /// In de, this message translates to:
  /// **'Flächenbezeichnung'**
  String get feldBezeichnung;

  /// No description provided for @meldungAusserhalb.
  ///
  /// In de, this message translates to:
  /// **'Der Ausschnitt darf nicht außerhalb der Terrasse sein!'**
  String get meldungAusserhalb;

  /// No description provided for @meldungKollision.
  ///
  /// In de, this message translates to:
  /// **'{a} und {b} dürfen sich nicht überschneiden.'**
  String meldungKollision(String a, String b);

  /// No description provided for @meldungTeilung.
  ///
  /// In de, this message translates to:
  /// **'{a} darf die Terrasse nicht teilen.'**
  String meldungTeilung(String a);

  /// No description provided for @schliessen.
  ///
  /// In de, this message translates to:
  /// **'SCHLIESSEN'**
  String get schliessen;

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
  /// **'Konfigurationsnummer mit Prüfcode'**
  String get nummerFeld;

  /// No description provided for @nummerHinweis.
  ///
  /// In de, this message translates to:
  /// **'z. B. 2026-10-08-1511-K7QXM'**
  String get nummerHinweis;

  /// No description provided for @nummerFehler.
  ///
  /// In de, this message translates to:
  /// **'Bitte im Format JJJJ-MM-TT-NNNN-XXXXX eingeben'**
  String get nummerFehler;

  /// No description provided for @version.
  ///
  /// In de, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @ladeFehler.
  ///
  /// In de, this message translates to:
  /// **'Die Konfiguration konnte nicht geladen werden – der Server ist nicht erreichbar.'**
  String get ladeFehler;

  /// No description provided for @konfigurationUnbekannt.
  ///
  /// In de, this message translates to:
  /// **'Diese Konfiguration gibt es nicht. Bitte prüfen Sie Konfigurationsnummer, Prüfcode und Version.'**
  String get konfigurationUnbekannt;

  /// No description provided for @konfigurationSpeichernKnopf.
  ///
  /// In de, this message translates to:
  /// **'Konfiguration Speichern'**
  String get konfigurationSpeichernKnopf;

  /// No description provided for @gefundenEntwurf.
  ///
  /// In de, this message translates to:
  /// **'Wir haben eine ungespeicherte Konfiguration gefunden. Möchten Sie mit dieser weiterplanen?'**
  String get gefundenEntwurf;

  /// No description provided for @gespeichertMeldung.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert: Konfigurationsnummer {nummer}, Version {version}. Bitte notieren Sie die Nummer samt Prüfcode (die letzten fünf Zeichen) – nur damit lässt sich die Konfiguration wieder laden.'**
  String gespeichertMeldung(String nummer, int version);

  /// No description provided for @speichernFehler.
  ///
  /// In de, this message translates to:
  /// **'Speichern nicht möglich – der Server ist nicht erreichbar. Ihre Planung bleibt erhalten, bitte später erneut speichern.'**
  String get speichernFehler;

  /// No description provided for @pdfErstellt.
  ///
  /// In de, this message translates to:
  /// **'Planungsunterlagen zu Konfigurationsnummer {nummer}, Version {version} erstellt.'**
  String pdfErstellt(String nummer, int version);

  /// No description provided for @pdfFehler.
  ///
  /// In de, this message translates to:
  /// **'PDF nicht möglich – der Server ist nicht erreichbar. Ihre Planung bleibt erhalten, bitte später erneut versuchen.'**
  String get pdfFehler;

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

  /// No description provided for @terrassenbelag6.
  ///
  /// In de, this message translates to:
  /// **'Befestigungsart'**
  String get terrassenbelag6;

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

  /// No description provided for @unterkonstruktion9.
  ///
  /// In de, this message translates to:
  /// **'Auflagen'**
  String get unterkonstruktion9;

  /// No description provided for @unterkonstruktion10.
  ///
  /// In de, this message translates to:
  /// **'Maximale Feldbreite'**
  String get unterkonstruktion10;

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

  /// No description provided for @produktauswahl.
  ///
  /// In de, this message translates to:
  /// **'Produktauswahl'**
  String get produktauswahl;

  /// No description provided for @belagMasse.
  ///
  /// In de, this message translates to:
  /// **'Maße: {masse}'**
  String belagMasse(String masse);

  /// No description provided for @belagFuge.
  ///
  /// In de, this message translates to:
  /// **'Fuge: {mm} mm'**
  String belagFuge(int mm);

  /// No description provided for @belagLaedt.
  ///
  /// In de, this message translates to:
  /// **'Beläge werden geladen …'**
  String get belagLaedt;

  /// No description provided for @belagFehler.
  ///
  /// In de, this message translates to:
  /// **'Die Beläge konnten nicht geladen werden.'**
  String get belagFehler;

  /// No description provided for @belagKeine.
  ///
  /// In de, this message translates to:
  /// **'Keine Beläge in den Artikeldaten.'**
  String get belagKeine;

  /// No description provided for @erneutVersuchen.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get erneutVersuchen;

  /// No description provided for @belagDialogTitel.
  ///
  /// In de, this message translates to:
  /// **'Terrassenbelag auswählen'**
  String get belagDialogTitel;

  /// No description provided for @belagUnsichtbar.
  ///
  /// In de, this message translates to:
  /// **'Unsichtbar befestigt'**
  String get belagUnsichtbar;

  /// No description provided for @belagSichtbar.
  ///
  /// In de, this message translates to:
  /// **'Sichtbar befestigt'**
  String get belagSichtbar;

  /// No description provided for @belagHolzfliese.
  ///
  /// In de, this message translates to:
  /// **'Holzfliese'**
  String get belagHolzfliese;

  /// No description provided for @belagSuche.
  ///
  /// In de, this message translates to:
  /// **'Suche nach Titel oder Artikelnummer'**
  String get belagSuche;

  /// No description provided for @filterMaterial.
  ///
  /// In de, this message translates to:
  /// **'Material'**
  String get filterMaterial;

  /// No description provided for @filterOberseite.
  ///
  /// In de, this message translates to:
  /// **'Oberseite'**
  String get filterOberseite;

  /// No description provided for @filterBreite.
  ///
  /// In de, this message translates to:
  /// **'Breite'**
  String get filterBreite;

  /// No description provided for @filterStaerke.
  ///
  /// In de, this message translates to:
  /// **'Stärke'**
  String get filterStaerke;

  /// No description provided for @filterLaenge.
  ///
  /// In de, this message translates to:
  /// **'Länge'**
  String get filterLaenge;

  /// No description provided for @filterZuruecksetzen.
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen'**
  String get filterZuruecksetzen;

  /// No description provided for @oberseiteGlatt.
  ///
  /// In de, this message translates to:
  /// **'glatt'**
  String get oberseiteGlatt;

  /// No description provided for @oberseiteBombiert.
  ///
  /// In de, this message translates to:
  /// **'bombiert'**
  String get oberseiteBombiert;

  /// No description provided for @profilGenutet.
  ///
  /// In de, this message translates to:
  /// **'genutet'**
  String get profilGenutet;

  /// No description provided for @profilGlattkant.
  ///
  /// In de, this message translates to:
  /// **'glattkant'**
  String get profilGlattkant;

  /// No description provided for @abmessungen.
  ///
  /// In de, this message translates to:
  /// **'Abmessungen: {masse}'**
  String abmessungen(String masse);

  /// No description provided for @preisJeLfm.
  ///
  /// In de, this message translates to:
  /// **'Preis je lfm: {preis} inkl. MwSt.'**
  String preisJeLfm(String preis);

  /// No description provided for @preisJeM2.
  ///
  /// In de, this message translates to:
  /// **'Preis je m²: {preis} inkl. MwSt.'**
  String preisJeM2(String preis);

  /// No description provided for @artikelnummer.
  ///
  /// In de, this message translates to:
  /// **'Artikelnummer: {nummer}'**
  String artikelnummer(String nummer);

  /// No description provided for @materialAngabe.
  ///
  /// In de, this message translates to:
  /// **'Material: {material}'**
  String materialAngabe(String material);

  /// No description provided for @profilAngabe.
  ///
  /// In de, this message translates to:
  /// **'Profil: {profil}'**
  String profilAngabe(String profil);

  /// No description provided for @oberseiteAngabe.
  ///
  /// In de, this message translates to:
  /// **'Oberseite: {oberseite}'**
  String oberseiteAngabe(String oberseite);

  /// No description provided for @artikelinfo.
  ///
  /// In de, this message translates to:
  /// **'Artikelinfo'**
  String get artikelinfo;

  /// No description provided for @ja.
  ///
  /// In de, this message translates to:
  /// **'Ja'**
  String get ja;

  /// No description provided for @nein.
  ///
  /// In de, this message translates to:
  /// **'Nein'**
  String get nein;

  /// No description provided for @dielenlaengeOriginal.
  ///
  /// In de, this message translates to:
  /// **'Mögliche Originallängen (in cm):'**
  String get dielenlaengeOriginal;

  /// No description provided for @dielenlaengeCm.
  ///
  /// In de, this message translates to:
  /// **'{cm} cm'**
  String dielenlaengeCm(int cm);

  /// No description provided for @verlegeartFugenschnitt.
  ///
  /// In de, this message translates to:
  /// **'Fugenschnitt'**
  String get verlegeartFugenschnitt;

  /// No description provided for @verlegeartFugenschnittHinweis.
  ///
  /// In de, this message translates to:
  /// **'Auf Fuge geschnitten: alle Stöße in einer Linie'**
  String get verlegeartFugenschnittHinweis;

  /// No description provided for @verlegeartHalbverband.
  ///
  /// In de, this message translates to:
  /// **'Halbverband'**
  String get verlegeartHalbverband;

  /// No description provided for @verlegeartHalbverbandHinweis.
  ///
  /// In de, this message translates to:
  /// **'Jede zweite Reihe um eine halbe Diele versetzt'**
  String get verlegeartHalbverbandHinweis;

  /// No description provided for @verlegeartDrittelverband.
  ///
  /// In de, this message translates to:
  /// **'Drittelverband'**
  String get verlegeartDrittelverband;

  /// No description provided for @verlegeartDrittelverbandHinweis.
  ///
  /// In de, this message translates to:
  /// **'Jede Reihe um ein Drittel der Diele versetzt'**
  String get verlegeartDrittelverbandHinweis;

  /// No description provided for @verlegeartWechselverband.
  ///
  /// In de, this message translates to:
  /// **'Wechselverband'**
  String get verlegeartWechselverband;

  /// No description provided for @verlegeartWechselverbandHinweis.
  ///
  /// In de, this message translates to:
  /// **'Jede zweite Reihe beginnt an der Gegenseite'**
  String get verlegeartWechselverbandHinweis;

  /// No description provided for @verlegerichtungWaagrecht.
  ///
  /// In de, this message translates to:
  /// **'waagrecht'**
  String get verlegerichtungWaagrecht;

  /// No description provided for @verlegerichtungSenkrecht.
  ///
  /// In de, this message translates to:
  /// **'senkrecht'**
  String get verlegerichtungSenkrecht;

  /// No description provided for @verlegerichtungDiagonal45.
  ///
  /// In de, this message translates to:
  /// **'45 Grad'**
  String get verlegerichtungDiagonal45;

  /// No description provided for @verlegerichtungDiagonal135.
  ///
  /// In de, this message translates to:
  /// **'135 Grad'**
  String get verlegerichtungDiagonal135;

  /// No description provided for @verlegerichtungIndividuell.
  ///
  /// In de, this message translates to:
  /// **'Individueller Verlegewinkel'**
  String get verlegerichtungIndividuell;

  /// No description provided for @verlegewinkel.
  ///
  /// In de, this message translates to:
  /// **'Winkel in Grad'**
  String get verlegewinkel;

  /// No description provided for @verlegewinkelUngueltig.
  ///
  /// In de, this message translates to:
  /// **'Bitte ganze Grad von 0 bis 179 eingeben'**
  String get verlegewinkelUngueltig;

  /// No description provided for @ausgangspunktFrage.
  ///
  /// In de, this message translates to:
  /// **'Welcher Punkt soll der Ausgangspunkt des Terrassenbelages sein?'**
  String get ausgangspunktFrage;

  /// No description provided for @ausgangspunktVerschieben.
  ///
  /// In de, this message translates to:
  /// **'Verschieben Sie die erste ganze Diele mit dem Mauszeiger oder dem Eingabefeld nach:'**
  String get ausgangspunktVerschieben;

  /// No description provided for @verschiebungLinksRechts.
  ///
  /// In de, this message translates to:
  /// **'links/rechts um'**
  String get verschiebungLinksRechts;

  /// No description provided for @verschiebungObenUnten.
  ///
  /// In de, this message translates to:
  /// **'oben/unten um'**
  String get verschiebungObenUnten;

  /// No description provided for @verschiebungHilfeLinksRechts.
  ///
  /// In de, this message translates to:
  /// **'in cm, negativ = links'**
  String get verschiebungHilfeLinksRechts;

  /// No description provided for @verschiebungHilfeObenUnten.
  ///
  /// In de, this message translates to:
  /// **'in cm, negativ = oben'**
  String get verschiebungHilfeObenUnten;

  /// No description provided for @verschiebungCm.
  ///
  /// In de, this message translates to:
  /// **'{cm} cm'**
  String verschiebungCm(String cm);

  /// No description provided for @verschiebungUngueltig.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine Zahl von −{grenze} bis {grenze} cm eingeben'**
  String verschiebungUngueltig(String grenze);

  /// No description provided for @verschiebungOhneDielen.
  ///
  /// In de, this message translates to:
  /// **'Verschieben lässt sich die erste Diele, sobald ein Belag aus Dielen verlegt ist.'**
  String get verschiebungOhneDielen;

  /// No description provided for @zuschnittWarnung.
  ///
  /// In de, this message translates to:
  /// **'Achtung: Es entstehen Zuschnitte unter 5 cm. Verschieben Sie die erste ganze Diele, damit keine so schmalen oder kurzen Stücke entstehen.'**
  String get zuschnittWarnung;

  /// No description provided for @befestigungsartClips.
  ///
  /// In de, this message translates to:
  /// **'Mit Clips'**
  String get befestigungsartClips;

  /// No description provided for @befestigungsartVerschraubt.
  ///
  /// In de, this message translates to:
  /// **'Direkt verschraubt'**
  String get befestigungsartVerschraubt;

  /// No description provided for @befestigungsartAbstandshalter.
  ///
  /// In de, this message translates to:
  /// **'Verschraubt mit Abstandshaltern'**
  String get befestigungsartAbstandshalter;

  /// No description provided for @befestigungOhneDielen.
  ///
  /// In de, this message translates to:
  /// **'Die Befestigung ergibt sich, sobald ein Belag aus Dielen verlegt ist.'**
  String get befestigungOhneDielen;

  /// No description provided for @befestigungspunkte.
  ///
  /// In de, this message translates to:
  /// **'Befestigungspunkte: {anzahl}'**
  String befestigungspunkte(int anzahl);

  /// No description provided for @befestigungsmittel.
  ///
  /// In de, this message translates to:
  /// **'{anzahl} × {titel}'**
  String befestigungsmittel(int anzahl, String titel);

  /// No description provided for @kurzeStueckeVerbinden.
  ///
  /// In de, this message translates to:
  /// **'Sollen kurze Dielenstücke miteinander verbunden werden?'**
  String get kurzeStueckeVerbinden;

  /// No description provided for @dielenlaengeNichtWaehlbar.
  ///
  /// In de, this message translates to:
  /// **'Für diesen Belag gibt es keine Längenauswahl.'**
  String get dielenlaengeNichtWaehlbar;

  /// No description provided for @belagKeinTreffer.
  ///
  /// In de, this message translates to:
  /// **'Kein Belag passt zu den Filtern.'**
  String get belagKeinTreffer;

  /// No description provided for @zurueckZurKonfiguration.
  ///
  /// In de, this message translates to:
  /// **'Zurück zur Konfiguration'**
  String get zurueckZurKonfiguration;

  /// No description provided for @gewaehlt.
  ///
  /// In de, this message translates to:
  /// **'Gewählt'**
  String get gewaehlt;

  /// No description provided for @anmelden.
  ///
  /// In de, this message translates to:
  /// **'ANMELDEN'**
  String get anmelden;

  /// No description provided for @abmelden.
  ///
  /// In de, this message translates to:
  /// **'ABMELDEN'**
  String get abmelden;

  /// No description provided for @angemeldetAls.
  ///
  /// In de, this message translates to:
  /// **'Angemeldet als {email}'**
  String angemeldetAls(String email);

  /// No description provided for @anmeldenTitel.
  ///
  /// In de, this message translates to:
  /// **'Login'**
  String get anmeldenTitel;

  /// No description provided for @anmeldenHinweis.
  ///
  /// In de, this message translates to:
  /// **'Nur für Mitarbeiter von ALTO HOLZ.'**
  String get anmeldenHinweis;

  /// No description provided for @emailFeld.
  ///
  /// In de, this message translates to:
  /// **'E-Mail-Adresse'**
  String get emailFeld;

  /// No description provided for @passwortFeld.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get passwortFeld;

  /// No description provided for @anmeldenKnopf.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get anmeldenKnopf;

  /// No description provided for @anmeldungAbgelehnt.
  ///
  /// In de, this message translates to:
  /// **'Anmeldung nicht möglich. Bitte prüfen Sie E-Mail-Adresse und Passwort – nach mehreren Fehlversuchen ist das Konto für 15 Minuten gesperrt.'**
  String get anmeldungAbgelehnt;

  /// No description provided for @anmeldungFehler.
  ///
  /// In de, this message translates to:
  /// **'Die Anmeldung ist nicht möglich – der Server ist nicht erreichbar.'**
  String get anmeldungFehler;

  /// No description provided for @abgemeldetMeldung.
  ///
  /// In de, this message translates to:
  /// **'Sie sind abgemeldet.'**
  String get abgemeldetMeldung;

  /// No description provided for @nummerHinweisMitarbeiter.
  ///
  /// In de, this message translates to:
  /// **'Als Mitarbeiter genügt die Konfigurationsnummer – der Prüfcode darf fehlen.'**
  String get nummerHinweisMitarbeiter;

  /// No description provided for @terrassenartNormal.
  ///
  /// In de, this message translates to:
  /// **'Normale Terrasse'**
  String get terrassenartNormal;

  /// No description provided for @terrassenartHochterrasse.
  ///
  /// In de, this message translates to:
  /// **'Hochterrasse'**
  String get terrassenartHochterrasse;

  /// No description provided for @terrassenartVorhandeneUk.
  ///
  /// In de, this message translates to:
  /// **'Vorhandene UK'**
  String get terrassenartVorhandeneUk;

  /// No description provided for @vorgabehoehe.
  ///
  /// In de, this message translates to:
  /// **'Vorgabehöhe: {cm} cm'**
  String vorgabehoehe(String cm);

  /// No description provided for @spannweiteFrage.
  ///
  /// In de, this message translates to:
  /// **'Spannweite der Unterkonstruktion (Abstand der vorhandenen Träger)'**
  String get spannweiteFrage;

  /// No description provided for @spannweite.
  ///
  /// In de, this message translates to:
  /// **'Spannweite'**
  String get spannweite;

  /// No description provided for @spannweiteUngueltig.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine Zahl von 10 bis 300 cm eingeben'**
  String get spannweiteUngueltig;

  /// No description provided for @hoehenpunkteHilfe.
  ///
  /// In de, this message translates to:
  /// **'Gemessen von Oberkante Belag bis Boden.'**
  String get hoehenpunkteHilfe;

  /// No description provided for @ohneGefaelle.
  ///
  /// In de, this message translates to:
  /// **'ohne Gefälle'**
  String get ohneGefaelle;

  /// No description provided for @mitGefaelle.
  ///
  /// In de, this message translates to:
  /// **'mit Gefälle'**
  String get mitGefaelle;

  /// No description provided for @hoeheAlle.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get hoeheAlle;

  /// No description provided for @hoeheUngueltig.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine Zahl über 0 bis 300 cm eingeben'**
  String get hoeheUngueltig;

  /// No description provided for @aufbauhoehe.
  ///
  /// In de, this message translates to:
  /// **'Aufbauhöhe (Belag und Unterkonstruktion): {cm} cm'**
  String aufbauhoehe(String cm);

  /// No description provided for @ukGedreht.
  ///
  /// In de, this message translates to:
  /// **'Die Unterkonstruktion wird gedreht (Breite und Stärke getauscht), damit die Aufbauhöhe eingehalten wird.'**
  String get ukGedreht;

  /// No description provided for @hoeheKorrigiert.
  ///
  /// In de, this message translates to:
  /// **'Der Höhenreferenzpunkt unterschreitet die minimale Höhe von {cm} cm. Er wurde korrigiert.'**
  String hoeheKorrigiert(String cm);

  /// No description provided for @hoeheUeberHoechsthoehe.
  ///
  /// In de, this message translates to:
  /// **'Höhe ungültig: höchstens {cm} cm mit Stellfüßen. Gerechnet wird mit dem Standardaufbau.'**
  String hoeheUeberHoechsthoehe(String cm);

  /// No description provided for @hoeheVorschlag.
  ///
  /// In de, this message translates to:
  /// **'Meintest du {cm} cm?'**
  String hoeheVorschlag(String cm);

  /// No description provided for @belagmeldungBelagErsetzt.
  ///
  /// In de, this message translates to:
  /// **'Der gewählte Belag ist nicht mehr im Sortiment. Geplant wird mit dem Vorgabebelag – wählen Sie bei Bedarf über „Produktauswahl“ einen anderen.'**
  String get belagmeldungBelagErsetzt;

  /// No description provided for @belagmeldungOhneMasse.
  ///
  /// In de, this message translates to:
  /// **'Für diesen Belag fehlen Breite oder Lieferlängen, er kann nicht verlegt werden. Bitte wählen Sie einen anderen Belag.'**
  String get belagmeldungOhneMasse;

  /// No description provided for @belagmeldungSystemdiele.
  ///
  /// In de, this message translates to:
  /// **'Systemdielen werden im Längenmix endlos verlegt – das zeichnet der Planer noch nicht.'**
  String get belagmeldungSystemdiele;

  /// No description provided for @belagmeldungFlaecheKleiner.
  ///
  /// In de, this message translates to:
  /// **'Die Fläche oder eine Teilfläche ist kleiner als eine Diele bzw. Fliese: Es passt keine ganze Belagbreite hinein, nur ein Zuschnitt.'**
  String get belagmeldungFlaecheKleiner;

  /// No description provided for @belagmeldungFliesenSpitzeWinkel.
  ///
  /// In de, this message translates to:
  /// **'Die Fläche hat Ecken unter 90°. Holzfliesen müssen dort schräg zugeschnitten werden – für solche Formen eignen sich Dielen besser.'**
  String get belagmeldungFliesenSpitzeWinkel;

  /// No description provided for @flaechenmeldungMasseFalsch.
  ///
  /// In de, this message translates to:
  /// **'Maße fehlen oder sind falsch: Die Fläche ist höchstens 0,05 m² groß. Bitte prüfen Sie die Maße.'**
  String get flaechenmeldungMasseFalsch;

  /// No description provided for @flaechenmeldungUnplausibelGross.
  ///
  /// In de, this message translates to:
  /// **'Die Fläche ist unplausibel groß (über 1.000 m²). Bitte prüfen Sie die Maße.'**
  String get flaechenmeldungUnplausibelGross;

  /// No description provided for @flaechenmeldungUngewoehnlich.
  ///
  /// In de, this message translates to:
  /// **'Hinweis: Die Fläche liegt außerhalb der üblichen 1 bis 300 m² – bitte prüfen Sie die Maße.'**
  String get flaechenmeldungUngewoehnlich;

  /// No description provided for @kantenwarnungZuKurz.
  ///
  /// In de, this message translates to:
  /// **'Hinweis: Kante {kante} ist nur {cm} cm lang (unter 10 cm) – bitte prüfen Sie die Maße.'**
  String kantenwarnungZuKurz(String kante, String cm);

  /// No description provided for @kantenwarnungZuLang.
  ///
  /// In de, this message translates to:
  /// **'Hinweis: Kante {kante} ist {cm} cm lang (über 30 m) – bitte prüfen Sie die Maße.'**
  String kantenwarnungZuLang(String kante, String cm);

  /// No description provided for @belagmeldungBombierung.
  ///
  /// In de, this message translates to:
  /// **'Ab 8 cm Breite empfehlen wir bombierte (leicht gewölbte) Dielen.'**
  String get belagmeldungBombierung;

  /// No description provided for @belagmeldungLaengeNichtLieferbar.
  ///
  /// In de, this message translates to:
  /// **'Die gewählte Länge von {cm} cm gibt es für diesen Belag nicht. Die Dielenlänge wird automatisch ermittelt.'**
  String belagmeldungLaengeNichtLieferbar(int cm);

  /// No description provided for @belagmeldungBefestigungsart.
  ///
  /// In de, this message translates to:
  /// **'Genutete Dielen werden verdeckt mit Clips befestigt. Die gewählte Verschraubung gilt nur für glattkante Dielen.'**
  String get belagmeldungBefestigungsart;

  /// No description provided for @belagmeldungOhneBefestigung.
  ///
  /// In de, this message translates to:
  /// **'Für diesen Belag sind keine passenden Clips oder Schrauben hinterlegt – die Befestigung fehlt in der Materialliste. Bitte sprechen Sie uns an.'**
  String get belagmeldungOhneBefestigung;

  /// No description provided for @belagmeldungSchraubeZuKurz.
  ///
  /// In de, this message translates to:
  /// **'Keine hinterlegte Schraube ist mindestens doppelt so lang, wie die Diele stark ist. Gerechnet wird mit der längsten – bitte prüfen Sie die Schraubenlänge.'**
  String get belagmeldungSchraubeZuKurz;

  /// No description provided for @belagmeldungLaengenvorgabe.
  ///
  /// In de, this message translates to:
  /// **'Keine Lieferlänge dieses Belags erfüllt die Vorgabe Dielenlänge. Geplant wird mit allen Lagerlängen.'**
  String get belagmeldungLaengenvorgabe;

  /// No description provided for @dielenlaengeHoechstens.
  ///
  /// In de, this message translates to:
  /// **'Dielen höchstens (in cm):'**
  String get dielenlaengeHoechstens;

  /// No description provided for @dielenlaengeMindestens.
  ///
  /// In de, this message translates to:
  /// **'Dielen mindestens (in cm):'**
  String get dielenlaengeMindestens;

  /// No description provided for @dielenlaengeBeliebig.
  ///
  /// In de, this message translates to:
  /// **'beliebig'**
  String get dielenlaengeBeliebig;

  /// No description provided for @zubehoerLaedt.
  ///
  /// In de, this message translates to:
  /// **'Zubehör wird geladen …'**
  String get zubehoerLaedt;

  /// No description provided for @zubehoerFehler.
  ///
  /// In de, this message translates to:
  /// **'Das Zubehör konnte nicht geladen werden.'**
  String get zubehoerFehler;

  /// No description provided for @zubehoerKeine.
  ///
  /// In de, this message translates to:
  /// **'In dieser Gruppe gibt es keine Artikel.'**
  String get zubehoerKeine;

  /// No description provided for @zubehoerBezeichnung.
  ///
  /// In de, this message translates to:
  /// **'Bezeichnung'**
  String get zubehoerBezeichnung;

  /// No description provided for @zubehoerTatsaechlich.
  ///
  /// In de, this message translates to:
  /// **'Tatsächlich'**
  String get zubehoerTatsaechlich;

  /// No description provided for @zubehoerMengeUngueltig.
  ///
  /// In de, this message translates to:
  /// **'Bitte 0 bis {max} eingeben'**
  String zubehoerMengeUngueltig(int max);

  /// No description provided for @zubehoerBerechnet.
  ///
  /// In de, this message translates to:
  /// **'berechnet: {anzahl}'**
  String zubehoerBerechnet(int anzahl);

  /// No description provided for @zubehoerPflicht.
  ///
  /// In de, this message translates to:
  /// **'Pflichtzubehör, mindestens {anzahl}'**
  String zubehoerPflicht(int anzahl);

  /// No description provided for @zubehoerPflichtMindestens.
  ///
  /// In de, this message translates to:
  /// **'Pflichtzubehör: mindestens {anzahl}'**
  String zubehoerPflichtMindestens(int anzahl);

  /// No description provided for @ukLaedt.
  ///
  /// In de, this message translates to:
  /// **'Unterkonstruktionen werden geladen …'**
  String get ukLaedt;

  /// No description provided for @ukFehler.
  ///
  /// In de, this message translates to:
  /// **'Die Unterkonstruktionen konnten nicht geladen werden.'**
  String get ukFehler;

  /// No description provided for @ukKeine.
  ///
  /// In de, this message translates to:
  /// **'Zum gewählten Belag passt keine Unterkonstruktion aus dem Sortiment.'**
  String get ukKeine;

  /// No description provided for @ukDialogTitel.
  ///
  /// In de, this message translates to:
  /// **'Unterkonstruktion auswählen'**
  String get ukDialogTitel;

  /// No description provided for @ukLaengeOhneUk.
  ///
  /// In de, this message translates to:
  /// **'Die Länge ergibt sich, sobald eine Unterkonstruktion gewählt ist.'**
  String get ukLaengeOhneUk;

  /// No description provided for @untergrundFrage.
  ///
  /// In de, this message translates to:
  /// **'Auf welchem Untergrund wird die Terrasse aufgebaut?'**
  String get untergrundFrage;

  /// No description provided for @untergrundSchotter.
  ///
  /// In de, this message translates to:
  /// **'Schotter (verdichtet)'**
  String get untergrundSchotter;

  /// No description provided for @untergrundBeton.
  ///
  /// In de, this message translates to:
  /// **'Beton'**
  String get untergrundBeton;

  /// No description provided for @untergrundBitumen.
  ///
  /// In de, this message translates to:
  /// **'Bitumenabdichtung'**
  String get untergrundBitumen;

  /// No description provided for @untergrundHinweis.
  ///
  /// In de, this message translates to:
  /// **'Der Untergrund hilft uns bei den Hinweisen zum Unterbau; die Materialliste ändert er nicht.'**
  String get untergrundHinweis;

  /// No description provided for @nutzungsartSchwimmend.
  ///
  /// In de, this message translates to:
  /// **'schwimmende Verlegung'**
  String get nutzungsartSchwimmend;

  /// No description provided for @nutzungsartVersteifungOhneRahmen.
  ///
  /// In de, this message translates to:
  /// **'Versteifung ohne Rahmen'**
  String get nutzungsartVersteifungOhneRahmen;

  /// No description provided for @nutzungsartRahmen.
  ///
  /// In de, this message translates to:
  /// **'Rahmen'**
  String get nutzungsartRahmen;

  /// No description provided for @nutzungsartVersteifungMitRahmen.
  ///
  /// In de, this message translates to:
  /// **'Versteifung mit Rahmen'**
  String get nutzungsartVersteifungMitRahmen;

  /// No description provided for @nutzungsartDoppelteUk.
  ///
  /// In de, this message translates to:
  /// **'doppelte Unterkonstruktion'**
  String get nutzungsartDoppelteUk;

  /// No description provided for @nutzungsartVerwindung.
  ///
  /// In de, this message translates to:
  /// **'Achtung: Ohne Bodenbefestigung kann sich eine schwimmend verlegte Unterkonstruktion verwinden. Eine Versteifung oder ein Rahmen hält sie in Form.'**
  String get nutzungsartVerwindung;

  /// No description provided for @querstrebenFrage.
  ///
  /// In de, this message translates to:
  /// **'Möchten Sie zusätzliche Querstreben hinzufügen?'**
  String get querstrebenFrage;

  /// No description provided for @querstrebenAbstand.
  ///
  /// In de, this message translates to:
  /// **'Querstreben kommen als Leiterverband zwischen die UK-Hölzer; automatisch im 75-cm-Raster, von Feld zu Feld versetzt.'**
  String get querstrebenAbstand;

  /// No description provided for @querstrebenAnzahl.
  ///
  /// In de, this message translates to:
  /// **'Anzahl der Quertraversen'**
  String get querstrebenAnzahl;

  /// No description provided for @querstrebenAnzahlUngueltig.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine ganze Zahl von 1 bis 99 eingeben'**
  String get querstrebenAnzahlUngueltig;

  /// No description provided for @nutzungPrivat.
  ///
  /// In de, this message translates to:
  /// **'private Nutzung'**
  String get nutzungPrivat;

  /// No description provided for @nutzungGewerblich.
  ///
  /// In de, this message translates to:
  /// **'gewerbliche Nutzung'**
  String get nutzungGewerblich;

  /// No description provided for @stellfuesse.
  ///
  /// In de, this message translates to:
  /// **'Passende Stellfüße:'**
  String get stellfuesse;

  /// No description provided for @stellfuesseKeine.
  ///
  /// In de, this message translates to:
  /// **'Für die gewählte Unterkonstruktion sind keine Stellfüße hinterlegt.'**
  String get stellfuesseKeine;

  /// No description provided for @auflagenStelzfuesse.
  ///
  /// In de, this message translates to:
  /// **'Mit Stelzfüßen'**
  String get auflagenStelzfuesse;

  /// No description provided for @auflagenStelzfuesseUndPads.
  ///
  /// In de, this message translates to:
  /// **'Mit Stelzfüßen und Pads'**
  String get auflagenStelzfuesseUndPads;

  /// No description provided for @auflagerAbstand.
  ///
  /// In de, this message translates to:
  /// **'Abstand der Auflager längs der Unterkonstruktion: höchstens {cm} cm'**
  String auflagerAbstand(String cm);

  /// No description provided for @auflagerListe.
  ///
  /// In de, this message translates to:
  /// **'Auflager laut Artikeldaten:'**
  String get auflagerListe;

  /// No description provided for @auflagerBereich.
  ///
  /// In de, this message translates to:
  /// **'{titel}: {von} bis {bis} mm'**
  String auflagerBereich(String titel, int von, int bis);

  /// No description provided for @auflagerPad.
  ///
  /// In de, this message translates to:
  /// **'{titel}: {dicke} mm'**
  String auflagerPad(String titel, int dicke);

  /// No description provided for @auflagerHoehen.
  ///
  /// In de, this message translates to:
  /// **'Mögliche Höhe (Oberkante Belag bis Boden): {von} bis {bis} cm'**
  String auflagerHoehen(String von, String bis);

  /// No description provided for @auflagerUnter.
  ///
  /// In de, this message translates to:
  /// **'Ein Höhenpunkt liegt unter der Mindesthöhe von {cm} cm mit Stelzfüßen. Wählen Sie Stelzfüße und Pads oder einen höheren Höhenpunkt.'**
  String auflagerUnter(String cm);

  /// No description provided for @auflagerUeber.
  ///
  /// In de, this message translates to:
  /// **'Ein Höhenpunkt liegt über der Höchsthöhe von {cm} cm mit Stelzfüßen. Wählen Sie die Hochterrasse oder einen niedrigeren Höhenpunkt.'**
  String auflagerUeber(String cm);

  /// No description provided for @auflagerKeine.
  ///
  /// In de, this message translates to:
  /// **'Für die gewählte Unterkonstruktion sind keine Auflager mit Höhenangaben hinterlegt.'**
  String get auflagerKeine;

  /// No description provided for @auflagerHochterrasse.
  ///
  /// In de, this message translates to:
  /// **'Bei der Hochterrasse steht die Unterkonstruktion auf Stützen aus UK-Holz mit Bodenankern.'**
  String get auflagerHochterrasse;

  /// No description provided for @auflagerVorhandeneUk.
  ///
  /// In de, this message translates to:
  /// **'Bei vorhandener Unterkonstruktion wird die neue UK mit Bodenankern auf den vorhandenen Trägern befestigt; der Abstand ist die Spannweite.'**
  String get auflagerVorhandeneUk;

  /// No description provided for @hoehenzuordnung.
  ///
  /// In de, this message translates to:
  /// **'Höhenzuordnung der Auflager (Spalt unter der UK):'**
  String get hoehenzuordnung;

  /// No description provided for @hoehenzuordnungZeile.
  ///
  /// In de, this message translates to:
  /// **'{titel}: {anzahl} Stück für {von} bis {bis} mm'**
  String hoehenzuordnungZeile(String titel, int anzahl, int von, int bis);

  /// No description provided for @auflagerOhneHoehe.
  ///
  /// In de, this message translates to:
  /// **'{anzahl} Auflager ohne passendes Höhenmaß'**
  String auflagerOhneHoehe(int anzahl);

  /// No description provided for @feldbreiteHinweis.
  ///
  /// In de, this message translates to:
  /// **'Höchster Abstand der UK-Hölzer (Achsabstand). Firmenregel: höchstens 40 cm, sicherer unter 35 cm.'**
  String get feldbreiteHinweis;

  /// No description provided for @feldbreiteCm.
  ///
  /// In de, this message translates to:
  /// **'{cm} cm'**
  String feldbreiteCm(String cm);

  /// No description provided for @feldbreiteBegrenzt.
  ///
  /// In de, this message translates to:
  /// **'Die gewählte Feldbreite überschreitet die Firmenregel; gerechnet wird mit {cm} cm.'**
  String feldbreiteBegrenzt(String cm);

  /// No description provided for @randUkErgaenzt.
  ///
  /// In de, this message translates to:
  /// **'Rand-UK {cm} cm ergänzt: An einer Kante endeten Dielen ohne UK darunter (Selbstkontrolle).'**
  String randUkErgaenzt(String cm);

  /// No description provided for @feldbreiteOhneBelag.
  ///
  /// In de, this message translates to:
  /// **'Die Feldbreite hängt vom Belag ab: Wählen Sie zuerst einen Belag aus Holz.'**
  String get feldbreiteOhneBelag;

  /// No description provided for @automatisch.
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get automatisch;

  /// No description provided for @materialliste.
  ///
  /// In de, this message translates to:
  /// **'Materialliste'**
  String get materialliste;

  /// No description provided for @materiallisteLeer.
  ///
  /// In de, this message translates to:
  /// **'Die Materialliste entsteht, sobald ein Belag verlegt ist.'**
  String get materiallisteLeer;

  /// No description provided for @materialSpaltePosition.
  ///
  /// In de, this message translates to:
  /// **'Pos.'**
  String get materialSpaltePosition;

  /// No description provided for @materialSpalteBild.
  ///
  /// In de, this message translates to:
  /// **'Bild'**
  String get materialSpalteBild;

  /// No description provided for @materialSpalteArtikel.
  ///
  /// In de, this message translates to:
  /// **'Artikel'**
  String get materialSpalteArtikel;

  /// No description provided for @materialSpalteMenge.
  ///
  /// In de, this message translates to:
  /// **'Menge'**
  String get materialSpalteMenge;

  /// No description provided for @materialSpalteEinzelpreis.
  ///
  /// In de, this message translates to:
  /// **'Einzelpreis'**
  String get materialSpalteEinzelpreis;

  /// No description provided for @materialSpaltePreisJeLfm.
  ///
  /// In de, this message translates to:
  /// **'Preis je lfm'**
  String get materialSpaltePreisJeLfm;

  /// No description provided for @materialSpalteGesamtLfm.
  ///
  /// In de, this message translates to:
  /// **'Gesamt-lfm'**
  String get materialSpalteGesamtLfm;

  /// No description provided for @materialSpaltePositionspreis.
  ///
  /// In de, this message translates to:
  /// **'Positionspreis'**
  String get materialSpaltePositionspreis;

  /// No description provided for @materialLaenge.
  ///
  /// In de, this message translates to:
  /// **'Länge: {laenge} mm'**
  String materialLaenge(int laenge);

  /// No description provided for @materialFreidiele.
  ///
  /// In de, this message translates to:
  /// **'Freidiele'**
  String get materialFreidiele;

  /// No description provided for @materialOptional.
  ///
  /// In de, this message translates to:
  /// **'Optional – nicht in der Summe'**
  String get materialOptional;

  /// No description provided for @materialNichtImAngebot.
  ///
  /// In de, this message translates to:
  /// **'Nicht im Angebot: {titel}'**
  String materialNichtImAngebot(String titel);

  /// No description provided for @materialImAngebot.
  ///
  /// In de, this message translates to:
  /// **'Im Angebot'**
  String get materialImAngebot;

  /// No description provided for @materialBerechnet.
  ///
  /// In de, this message translates to:
  /// **'berechnet: {anzahl}'**
  String materialBerechnet(int anzahl);

  /// No description provided for @materialSumme.
  ///
  /// In de, this message translates to:
  /// **'Summe gesamt: {betrag}'**
  String materialSumme(String betrag);

  /// No description provided for @materialMehrwertsteuer.
  ///
  /// In de, this message translates to:
  /// **'enthaltene {satz} % MwSt.: {betrag}'**
  String materialMehrwertsteuer(int satz, String betrag);

  /// No description provided for @materialPreishinweis.
  ///
  /// In de, this message translates to:
  /// **'Alle Preise inkl. MwSt. und nur zur Information – verbindlich ist unser Angebot.'**
  String get materialPreishinweis;

  /// No description provided for @materialOhnePreis.
  ///
  /// In de, this message translates to:
  /// **'Für einzelne Artikel liegt kein Preis vor; sie fehlen in der Summe.'**
  String get materialOhnePreis;

  /// No description provided for @materialMengeUebernehmen.
  ///
  /// In de, this message translates to:
  /// **'Menge übernehmen'**
  String get materialMengeUebernehmen;

  /// No description provided for @materialMengeBerechnet.
  ///
  /// In de, this message translates to:
  /// **'Berechnete Menge verwenden'**
  String get materialMengeBerechnet;

  /// No description provided for @materialMitarbeiter.
  ///
  /// In de, this message translates to:
  /// **'Mitarbeiter-Ansicht: Mengen änderbar'**
  String get materialMitarbeiter;

  /// No description provided for @exportGrandTotal.
  ///
  /// In de, this message translates to:
  /// **'Export für GrandTotal'**
  String get exportGrandTotal;

  /// No description provided for @exportGrandTotalFertig.
  ///
  /// In de, this message translates to:
  /// **'Importdatei {datei} erstellt.'**
  String exportGrandTotalFertig(String datei);

  /// No description provided for @exportGrandTotalFehler.
  ///
  /// In de, this message translates to:
  /// **'Der Export für GrandTotal ist fehlgeschlagen. Bitte versuchen Sie es erneut.'**
  String get exportGrandTotalFehler;

  /// No description provided for @einheitStueck.
  ///
  /// In de, this message translates to:
  /// **'Stück'**
  String get einheitStueck;

  /// No description provided for @einheitLaufmeter.
  ///
  /// In de, this message translates to:
  /// **'lfm'**
  String get einheitLaufmeter;

  /// No description provided for @einheitQuadratmeter.
  ///
  /// In de, this message translates to:
  /// **'m²'**
  String get einheitQuadratmeter;

  /// No description provided for @einheitVerpackungseinheit.
  ///
  /// In de, this message translates to:
  /// **'VPE'**
  String get einheitVerpackungseinheit;

  /// No description provided for @einheitKarton.
  ///
  /// In de, this message translates to:
  /// **'Karton'**
  String get einheitKarton;

  /// No description provided for @einheitSet.
  ///
  /// In de, this message translates to:
  /// **'Set'**
  String get einheitSet;

  /// No description provided for @einheitKiste.
  ///
  /// In de, this message translates to:
  /// **'Kiste'**
  String get einheitKiste;

  /// No description provided for @einheitLiter.
  ///
  /// In de, this message translates to:
  /// **'l'**
  String get einheitLiter;

  /// No description provided for @stueckliste.
  ///
  /// In de, this message translates to:
  /// **'Stückliste'**
  String get stueckliste;

  /// No description provided for @stuecklisteLeer.
  ///
  /// In de, this message translates to:
  /// **'Die Stückliste entsteht, sobald ein Belag verlegt ist.'**
  String get stuecklisteLeer;

  /// No description provided for @stueckSpalteArtikel.
  ///
  /// In de, this message translates to:
  /// **'Artikel'**
  String get stueckSpalteArtikel;

  /// No description provided for @stueckSpalteLaenge.
  ///
  /// In de, this message translates to:
  /// **'Länge (cm)'**
  String get stueckSpalteLaenge;

  /// No description provided for @stueckSpalteStueck.
  ///
  /// In de, this message translates to:
  /// **'Stück'**
  String get stueckSpalteStueck;

  /// No description provided for @stueckSpalteFarbe.
  ///
  /// In de, this message translates to:
  /// **'Farbe im Plan'**
  String get stueckSpalteFarbe;

  /// No description provided for @stueckfarbeRot.
  ///
  /// In de, this message translates to:
  /// **'rot – ganze Länge'**
  String get stueckfarbeRot;

  /// No description provided for @stueckfarbeBlau.
  ///
  /// In de, this message translates to:
  /// **'blau – zugeschnitten'**
  String get stueckfarbeBlau;

  /// No description provided for @stueckfarbeGruen.
  ///
  /// In de, this message translates to:
  /// **'grün – Querstück'**
  String get stueckfarbeGruen;

  /// No description provided for @stuecklisteHinweis.
  ///
  /// In de, this message translates to:
  /// **'Stücke der bearbeiteten Fläche; die Farbe zeigt das Stück in der Zeichnung.'**
  String get stuecklisteHinweis;

  /// No description provided for @zuschnitt.
  ///
  /// In de, this message translates to:
  /// **'Zuschnitt'**
  String get zuschnitt;

  /// No description provided for @zuschnittLeer.
  ///
  /// In de, this message translates to:
  /// **'Der Zuschnittplan entsteht, sobald ein Belag verlegt ist.'**
  String get zuschnittLeer;

  /// No description provided for @zuschnittBelag.
  ///
  /// In de, this message translates to:
  /// **'Zuschnitt Belag'**
  String get zuschnittBelag;

  /// No description provided for @zuschnittUk.
  ///
  /// In de, this message translates to:
  /// **'Zuschnitt Unterkonstruktion'**
  String get zuschnittUk;

  /// No description provided for @zuschnittSpalteAusgangslaenge.
  ///
  /// In de, this message translates to:
  /// **'Ausgangslänge (cm)'**
  String get zuschnittSpalteAusgangslaenge;

  /// No description provided for @zuschnittSpalteMenge.
  ///
  /// In de, this message translates to:
  /// **'Menge'**
  String get zuschnittSpalteMenge;

  /// No description provided for @zuschnittSpalteSchnitte.
  ///
  /// In de, this message translates to:
  /// **'Schnittmaße (cm)'**
  String get zuschnittSpalteSchnitte;

  /// No description provided for @zuschnittHinweis.
  ///
  /// In de, this message translates to:
  /// **'Alle Flächen mal Häufigkeit; je Zeile werden aus jedem Stück der Ausgangslänge die Schnittmaße gesägt, ohne Zugabe.'**
  String get zuschnittHinweis;

  /// No description provided for @angrenzendFrage.
  ///
  /// In de, this message translates to:
  /// **'Welche Seiten grenzen an bestehende Bauelemente? (wird in der Konfiguration grau dargestellt)'**
  String get angrenzendFrage;

  /// No description provided for @ohneSeiten.
  ///
  /// In de, this message translates to:
  /// **'Diese Form hat keine Seiten zur Auswahl.'**
  String get ohneSeiten;

  /// No description provided for @verblendungFrage.
  ///
  /// In de, this message translates to:
  /// **'Welche Seiten sollen verblendet werden? (wird in der Konfiguration gelb dargestellt)'**
  String get verblendungFrage;

  /// No description provided for @flaecheVerblenden.
  ///
  /// In de, this message translates to:
  /// **'Fläche verblenden'**
  String get flaecheVerblenden;

  /// No description provided for @verblendungHinweis.
  ///
  /// In de, this message translates to:
  /// **'Die Blende ist aus der Serie des Belags, glattkant und so stark wie die Diele. Ihre Breite richtet sich nach der Höhe (höchstens 100 mm, über ca. 13 cm zwei Blenden à 60 mm); die Ecken werden auf Gehrung geschnitten.'**
  String get verblendungHinweis;

  /// No description provided for @blendeSeite.
  ///
  /// In de, this message translates to:
  /// **'Blende {seite}'**
  String blendeSeite(String seite);

  /// No description provided for @blendenhoehe.
  ///
  /// In de, this message translates to:
  /// **'Blendenhöhe'**
  String get blendenhoehe;

  /// No description provided for @blendenhoeheAutomatisch.
  ///
  /// In de, this message translates to:
  /// **'automatisch'**
  String get blendenhoeheAutomatisch;

  /// No description provided for @blendenhoeheZuruecksetzen.
  ///
  /// In de, this message translates to:
  /// **'Blendenhöhe automatisch (niedrigste Stelle der Seite)'**
  String get blendenhoeheZuruecksetzen;

  /// No description provided for @blendenteil.
  ///
  /// In de, this message translates to:
  /// **'Teilstück {nummer}'**
  String blendenteil(int nummer);

  /// No description provided for @blendenteilVon.
  ///
  /// In de, this message translates to:
  /// **'Von (ab {ecke})'**
  String blendenteilVon(String ecke);

  /// No description provided for @blendenteilBis.
  ///
  /// In de, this message translates to:
  /// **'Bis (ab {ecke})'**
  String blendenteilBis(String ecke);

  /// No description provided for @blendenteilHinzufuegen.
  ///
  /// In de, this message translates to:
  /// **'Nur einen Teil der Seite verblenden'**
  String get blendenteilHinzufuegen;

  /// No description provided for @blendenteilEntfernen.
  ///
  /// In de, this message translates to:
  /// **'Teilstück entfernen'**
  String get blendenteilEntfernen;

  /// No description provided for @blendenteilUngueltig.
  ///
  /// In de, this message translates to:
  /// **'Bitte von 0 bis 5000 cm eingeben, der Anfang vor dem Ende'**
  String get blendenteilUngueltig;

  /// No description provided for @blendeJeSeiteHilfe.
  ///
  /// In de, this message translates to:
  /// **'Ohne Angabe gilt die niedrigste Stelle der Seite – die Blende steht nirgends auf, an höheren Stellen bleibt unten Luft. Ohne Teilstück wird die ganze Seite verblendet.'**
  String get blendeJeSeiteHilfe;

  /// No description provided for @meldungUnterlueftung.
  ///
  /// In de, this message translates to:
  /// **'Achtung: Bitte beachten Sie, dass eine Unterlüftung der Terrasse gewährleistet sein muss!'**
  String get meldungUnterlueftung;

  /// No description provided for @meldungKeinHoehenunterschied.
  ///
  /// In de, this message translates to:
  /// **'Ohne Höhenunterschied zum Boden ist an dieser Seite keine Verblendung möglich.'**
  String get meldungKeinHoehenunterschied;

  /// No description provided for @meldungBlendeFehlt.
  ///
  /// In de, this message translates to:
  /// **'Für die Höhe an einer verblendeten Seite gibt es in der Serie keine passende glattkante Blende – dort wird keine Blende gerechnet. Bitte sprechen Sie uns an.'**
  String get meldungBlendeFehlt;

  /// No description provided for @materialVerblendung.
  ///
  /// In de, this message translates to:
  /// **'Verblendung'**
  String get materialVerblendung;

  /// No description provided for @rinnenFrage.
  ///
  /// In de, this message translates to:
  /// **'An welchen Seiten sollen Entwässerungsrinnen geplant werden?'**
  String get rinnenFrage;

  /// No description provided for @rinnenLage.
  ///
  /// In de, this message translates to:
  /// **'Lage der Rinne an {seite}'**
  String rinnenLage(String seite);

  /// No description provided for @rinnenlageGesamteSeite.
  ///
  /// In de, this message translates to:
  /// **'Gesamte Seite (innen)'**
  String get rinnenlageGesamteSeite;

  /// No description provided for @rinnenlageImElement.
  ///
  /// In de, this message translates to:
  /// **'Im bodentiefen Element'**
  String get rinnenlageImElement;

  /// No description provided for @rinnenlageAusserhalbElement.
  ///
  /// In de, this message translates to:
  /// **'Außerhalb des bodentiefen Elements'**
  String get rinnenlageAusserhalbElement;

  /// No description provided for @rinnenlageVorElement.
  ///
  /// In de, this message translates to:
  /// **'Nur vor dem bodentiefen Element'**
  String get rinnenlageVorElement;

  /// No description provided for @rinnenHinweis.
  ///
  /// In de, this message translates to:
  /// **'Lage und bodentiefes Element sind im Artikel festgelegt; die Lage wählt die Rinne. Die Unterkonstruktion reicht bis an die Seite.'**
  String get rinnenHinweis;

  /// No description provided for @meldungOhneRinnenartikel.
  ///
  /// In de, this message translates to:
  /// **'Zu diesem Belag ist keine Entwässerungsrinne hinterlegt.'**
  String get meldungOhneRinnenartikel;

  /// No description provided for @hoehenpunktName.
  ///
  /// In de, this message translates to:
  /// **'Höhenreferenzpunkt {nummer}'**
  String hoehenpunktName(int nummer);

  /// No description provided for @hoehenpunktHinzufuegen.
  ///
  /// In de, this message translates to:
  /// **'Weiteren Höhenreferenzpunkt einplanen'**
  String get hoehenpunktHinzufuegen;

  /// No description provided for @hoehenpunktEntfernen.
  ///
  /// In de, this message translates to:
  /// **'Höhenreferenzpunkt entfernen'**
  String get hoehenpunktEntfernen;

  /// No description provided for @hoehenpunktWaagerecht.
  ///
  /// In de, this message translates to:
  /// **'Waagerecht ab A'**
  String get hoehenpunktWaagerecht;

  /// No description provided for @hoehenpunktSenkrecht.
  ///
  /// In de, this message translates to:
  /// **'Senkrecht ab A'**
  String get hoehenpunktSenkrecht;

  /// No description provided for @hoehenpunktHoehe.
  ///
  /// In de, this message translates to:
  /// **'Höhe'**
  String get hoehenpunktHoehe;

  /// No description provided for @hoehenpunktLageUngueltig.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine Zahl von −30000 bis 30000 cm eingeben'**
  String get hoehenpunktLageUngueltig;

  /// No description provided for @hoehenpunktHilfe.
  ///
  /// In de, this message translates to:
  /// **'Zum Beispiel ein Ablauf: Lage ab Punkt A (nach rechts und nach unten, auch negativ), in der Zeichnung verschiebbar.'**
  String get hoehenpunktHilfe;

  /// No description provided for @treppenFrage.
  ///
  /// In de, this message translates to:
  /// **'An welchen Seiten sollen Treppen geplant werden?'**
  String get treppenFrage;

  /// No description provided for @treppeHinzufuegen.
  ///
  /// In de, this message translates to:
  /// **'Treppe hinzufügen'**
  String get treppeHinzufuegen;

  /// No description provided for @treppeName.
  ///
  /// In de, this message translates to:
  /// **'Treppe {nummer}'**
  String treppeName(int nummer);

  /// No description provided for @treppeEntfernen.
  ///
  /// In de, this message translates to:
  /// **'Treppe entfernen'**
  String get treppeEntfernen;

  /// No description provided for @treppeStart.
  ///
  /// In de, this message translates to:
  /// **'Start'**
  String get treppeStart;

  /// No description provided for @treppeAbstand.
  ///
  /// In de, this message translates to:
  /// **'Seite (Abstand vom Startpunkt)'**
  String get treppeAbstand;

  /// No description provided for @treppeBreite.
  ///
  /// In de, this message translates to:
  /// **'Breite'**
  String get treppeBreite;

  /// No description provided for @treppeKonstruktionsart.
  ///
  /// In de, this message translates to:
  /// **'Konstruktionsart'**
  String get treppeKonstruktionsart;

  /// No description provided for @treppeKonstruktion.
  ///
  /// In de, this message translates to:
  /// **'Konstruktion'**
  String get treppeKonstruktion;

  /// No description provided for @treppeFundament.
  ///
  /// In de, this message translates to:
  /// **'Fundament'**
  String get treppeFundament;

  /// No description provided for @treppeArt.
  ///
  /// In de, this message translates to:
  /// **'Treppenart'**
  String get treppeArt;

  /// No description provided for @treppeRegulaer.
  ///
  /// In de, this message translates to:
  /// **'Reguläre Treppe'**
  String get treppeRegulaer;

  /// No description provided for @treppeZweiteilig.
  ///
  /// In de, this message translates to:
  /// **'2-teilige Fächertreppe'**
  String get treppeZweiteilig;

  /// No description provided for @treppeDreiteilig.
  ///
  /// In de, this message translates to:
  /// **'3-teilige Fächertreppe'**
  String get treppeDreiteilig;

  /// No description provided for @treppeIndividuell.
  ///
  /// In de, this message translates to:
  /// **'Individuelle Stufenmaße?'**
  String get treppeIndividuell;

  /// No description provided for @treppeAnzahl.
  ///
  /// In de, this message translates to:
  /// **'Anzahl der Stufen'**
  String get treppeAnzahl;

  /// No description provided for @treppeStufenmasse.
  ///
  /// In de, this message translates to:
  /// **'Stufenmaße'**
  String get treppeStufenmasse;

  /// No description provided for @treppeStufe.
  ///
  /// In de, this message translates to:
  /// **'Stufe {nummer}'**
  String treppeStufe(int nummer);

  /// No description provided for @treppeTiefe.
  ///
  /// In de, this message translates to:
  /// **'Tiefe'**
  String get treppeTiefe;

  /// No description provided for @treppeHoehe.
  ///
  /// In de, this message translates to:
  /// **'Höhe'**
  String get treppeHoehe;

  /// No description provided for @treppePodest.
  ///
  /// In de, this message translates to:
  /// **'Podestmaße'**
  String get treppePodest;

  /// No description provided for @treppeMasse.
  ///
  /// In de, this message translates to:
  /// **'Treppenmaße in cm (L x B x H): {laenge} x {breite} x {hoehe}'**
  String treppeMasse(String laenge, String breite, String hoehe);

  /// No description provided for @treppeUngueltig.
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Wert im erlaubten Bereich eingeben'**
  String get treppeUngueltig;

  /// No description provided for @meldungTreppeNichtFrei.
  ///
  /// In de, this message translates to:
  /// **'Eine Treppe liegt an einer Seite am Bauelement oder mit Rinne – sie wird nicht gerechnet.'**
  String get meldungTreppeNichtFrei;

  /// No description provided for @treppeMeldungSteigung.
  ///
  /// In de, this message translates to:
  /// **'Prüfliste: Eine Steigung liegt außerhalb von 15–19 cm.'**
  String get treppeMeldungSteigung;

  /// No description provided for @treppeMeldungSchrittmass.
  ///
  /// In de, this message translates to:
  /// **'Prüfliste: Das Schrittmaß (2 × Steigung + Auftritt) liegt außerhalb von 59–67 cm.'**
  String get treppeMeldungSchrittmass;

  /// No description provided for @treppeMeldungZuSchmal.
  ///
  /// In de, this message translates to:
  /// **'Prüfliste: Die Treppe ist schmaler als 50 cm.'**
  String get treppeMeldungZuSchmal;

  /// No description provided for @treppeMeldungUeberSeite.
  ///
  /// In de, this message translates to:
  /// **'Prüfliste: Die Treppe reicht über das Ende der Seite hinaus.'**
  String get treppeMeldungUeberSeite;
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
