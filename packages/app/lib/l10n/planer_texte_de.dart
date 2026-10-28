// coverage:ignore-file
// Von `flutter gen-l10n` erzeugt – nicht von Hand ändern.

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'planer_texte.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class PlanerTexteDe extends PlanerTexte {
  PlanerTexteDe([String locale = 'de']) : super(locale);

  @override
  String get sprachname => 'Deutsch';

  @override
  String get sprache => 'Sprache';

  @override
  String get darstellung => 'Darstellung';

  @override
  String get darstellungHell => 'Hell';

  @override
  String get darstellungDunkel => 'Dunkel';

  @override
  String get darstellungSystem => 'Wie System';

  @override
  String get planerTitel => 'TERRASSENKONFIGURATOR';

  @override
  String get logoBeschreibung => 'RobinienWelt';

  @override
  String get folgt => 'Diese Funktion folgt in Kürze.';

  @override
  String get verbinde => 'Verbinde mit dem Server …';

  @override
  String get keineVerbindung => 'Keine Verbindung zum Server';

  @override
  String get zuruecksetzen => 'ZURÜCKSETZEN';

  @override
  String get videoberatung => 'Video-Beratung buchen';

  @override
  String get pdf => 'PDF';

  @override
  String get anfordern => 'KONFIGURATION ANFORDERN';

  @override
  String get anfordernKurz => 'ANFORDERN';

  @override
  String get fortschritt => 'Fortschritt';

  @override
  String get menuEinklappen => 'Menü einklappen';

  @override
  String get menuAusklappen => 'Menü ausklappen';

  @override
  String flaeche(String wert) {
    return 'Fläche: $wert';
  }

  @override
  String volumen(String wert) {
    return 'Volumen: $wert';
  }

  @override
  String massPlatzhalter(String kante) {
    return '$kante: cm';
  }

  @override
  String get formRechteck => 'Rechteck';

  @override
  String get formLForm => 'L-Form';

  @override
  String get formTForm => 'T-Form';

  @override
  String get formUForm => 'U-Form';

  @override
  String get formOForm => 'O-Form';

  @override
  String get formKreis => 'Kreis';

  @override
  String get formFreiform => 'Freiform';

  @override
  String get freiformHinweis => 'Punkte setzen – [x] zum Schließen der Form';

  @override
  String get einrastfunktion => 'Einrastfunktion';

  @override
  String get zeichnungshilfe => 'Zeichnungshilfe';

  @override
  String get eingabeStrecke => 'Strecke';

  @override
  String get eingabeKoordinaten => 'Koordinaten';

  @override
  String get feldWinkel => 'Winkel';

  @override
  String winkelPlatzhalter(String feld) {
    return '$feld: °';
  }

  @override
  String get letztenPunktEntfernen => 'Letzten Punkt entfernen';

  @override
  String get formSchliessen => 'Form schließen';

  @override
  String get formGeschlossen => 'Form geschlossen';

  @override
  String punktAusgewaehlt(String name) {
    return 'Punkt $name';
  }

  @override
  String get eckeAntippen =>
      'Ecke antippen, um sie zu bearbeiten; an der Kantenmitte ziehen verschiebt die Kante, antippen fügt einen Punkt ein.';

  @override
  String get punktEntfernen => 'Punkt entfernen';

  @override
  String get freiformMindestens3 => 'Die Form braucht mindestens 3 Punkte.';

  @override
  String get freiformKreuzt => 'Die Kanten dürfen sich nicht kreuzen.';

  @override
  String freiformKante(int min, int max) {
    return 'Kanten müssen $min bis $max cm lang sein.';
  }

  @override
  String ausschnittTitel(String bezeichnung) {
    return 'Ausschnitt $bezeichnung';
  }

  @override
  String get feldLaenge => 'Länge';

  @override
  String get feldBreite => 'Breite';

  @override
  String massUngueltig(int min, int max) {
    return 'Bitte $min bis $max cm eingeben';
  }

  @override
  String get berechnungFehler =>
      'Berechnung nicht möglich – bitte Verbindung prüfen';

  @override
  String get agb => 'AGB';

  @override
  String get datenschutz => 'Datenschutz';

  @override
  String get impressum => 'Impressum';

  @override
  String get zuruecksetzenTitel => 'Planung zurücksetzen?';

  @override
  String get zuruecksetzenText =>
      'Sind Sie sicher, dass Sie die Planung zurücksetzen möchten? Dadurch geht Ihr Fortschritt verloren. Stellen Sie sicher, dass Sie die Konfiguration gespeichert und die Konfigurationsnummer notiert haben.';

  @override
  String get zuruecksetzenZurueck => 'Zurück zur Konfiguration';

  @override
  String get zuruecksetzenBestaetigen => 'Konfiguration zurücksetzen';

  @override
  String get standardwertTitel => 'Standardwerte beibehalten';

  @override
  String get standardwertText =>
      'In diesen Schritten haben Sie nichts verändert – dort gelten die Standardwerte des Planers:';

  @override
  String get standardwertFrage => 'Möchten Sie trotzdem fortfahren?';

  @override
  String get zurueck => 'Zurück';

  @override
  String get fortfahren => 'Fortfahren';

  @override
  String get rueckgaengig => 'Rückgängig';

  @override
  String get wiederherstellen => 'Wiederherstellen';

  @override
  String get zentrieren => 'Zentrieren';

  @override
  String get verkleinern => 'Verkleinern';

  @override
  String get vergroessern => 'Vergrößern';

  @override
  String get zoom => 'Zoom';

  @override
  String get bedienHinweis => 'Mausrad: Zoom · Ziehen: Verschieben';

  @override
  String get beschriftungen => 'Beschriftungen';

  @override
  String get ebeneBelag => 'Belag';

  @override
  String get ebeneUnterkonstruktion => 'UK';

  @override
  String get ebeneMasse => 'Maße';

  @override
  String get ebeneBelagLang => 'Belag';

  @override
  String get ebeneUnterkonstruktionLang => 'Unterkonstruktion';

  @override
  String get ebeneMasseLang => 'Maße';

  @override
  String get beschriftungSeitenlaengen => 'Seitenlängen';

  @override
  String get beschriftungWinkel => 'Winkel';

  @override
  String get beschriftungPunkte => 'Punkte';

  @override
  String get beschriftungAblaeufe => 'Abläufe';

  @override
  String get ablauf => 'Ablauf';

  @override
  String get willkommenTitel =>
      'Willkommen beim RobinienWelt Terrassenkonfigurator!';

  @override
  String get willkommenText =>
      'Planen Sie Ihre Wunschterrasse aus Robinie mit wenigen Klicks: Dielen, Verlegung und Unterkonstruktion wählen Sie selbst. Danach bestellen Sie direkt oder fordern ein Angebot an. Persönliche Hilfe bekommen Sie in der Video-Beratung.';

  @override
  String get konfigurationLadenKnopf => 'KONFIGURATION LADEN';

  @override
  String get neuKnopf => 'WUNSCHTERRASSE KONFIGURIEREN';

  @override
  String gefunden(String nummer, int version) {
    return 'Wir haben eine Konfiguration gefunden. Möchten Sie mit dieser weiterplanen? ($nummer, Version $version)';
  }

  @override
  String get weiterplanen => 'WEITERPLANEN';

  @override
  String get ladenTitel => 'Konfiguration laden';

  @override
  String get nummerFeld => 'Konfigurationsnummer';

  @override
  String get nummerHinweis => 'z. B. 2026-10-08-1511';

  @override
  String get nummerFehler => 'Bitte im Format JJJJ-MM-TT-NNNN eingeben';

  @override
  String get version => 'Version';

  @override
  String get ladeFehler => 'Die Konfiguration konnte nicht geladen werden.';

  @override
  String get modell3dTitel => '3D-Vorschau (Prototyp): Terrasse 4 x 3 m';

  @override
  String get modell3dLaedt => 'Lade 3D-Modell …';

  @override
  String get modell3dFehler => '3D-Modell konnte nicht geladen werden';

  @override
  String get nurImBrowser => 'Die 3D-Ansicht gibt es nur im Browser.';

  @override
  String get keinBild => 'Kein Bild';

  @override
  String get schrittGrundriss => 'GRUNDRISS';

  @override
  String get schrittTerrassenbelag => 'TERRASSENBELAG';

  @override
  String get schrittTerrassenbelagGetrennt => 'TERRASSEN-\nBELAG';

  @override
  String get schrittUnterkonstruktion => 'UNTERKONSTRUKTION';

  @override
  String get schrittUnterkonstruktionGetrennt => 'UNTER-\nKONSTRUKTION';

  @override
  String get schrittTerrassenanschluss => 'TERRASSENANSCHLUSS';

  @override
  String get schrittTerrassenanschlussGetrennt => 'TERRASSEN-\nANSCHLUSS';

  @override
  String get schrittTreppen => 'TREPPEN';

  @override
  String get schrittZubehoer => 'ZUBEHÖR';

  @override
  String get schrittVerschnittoptimierung => 'VERSCHNITTOPTIMIERUNG';

  @override
  String get schrittVerschnittoptimierungGetrennt => 'VERSCHNITT-\nOPTIMIERUNG';

  @override
  String get grundriss1 => 'Terrassenform auswählen';

  @override
  String get grundriss2 => 'Terrassenmaße';

  @override
  String get grundriss3 => 'Ecken und Seiten abrunden';

  @override
  String get grundriss4 => 'Ausschnitte und Teilflächen';

  @override
  String get terrassenbelag1 => 'Terrassenbelag auswählen';

  @override
  String get terrassenbelag2 => 'Dielenlänge automatisch ermitteln';

  @override
  String get terrassenbelag3 => 'Verlegearten';

  @override
  String get terrassenbelag4 => 'Verlegerichtungen';

  @override
  String get terrassenbelag5 => 'Ausgangspunkt des Belags';

  @override
  String get unterkonstruktion1 => 'Art der Terrasse';

  @override
  String get unterkonstruktion2 => 'Höhenpunkte';

  @override
  String get unterkonstruktion3 => 'Unterkonstruktion auswählen';

  @override
  String get unterkonstruktion4 => 'Länge der Unterkonstruktion';

  @override
  String get unterkonstruktion5 => 'Untergrund';

  @override
  String get unterkonstruktion6 => 'Art der Terrassennutzung';

  @override
  String get unterkonstruktion7 => 'Querstreben';

  @override
  String get unterkonstruktion8 => 'Nutzung privat oder gewerblich';

  @override
  String get terrassenanschluss1 => 'Angrenzende Bauelemente';

  @override
  String get terrassenanschluss2 => 'Verblendung';

  @override
  String get terrassenanschluss3 => 'Entwässerungsrinnen';

  @override
  String get treppen1 => 'Treppen';

  @override
  String get zubehoer1 => 'Allgemein';

  @override
  String get zubehoer2 => 'Anlieferung';

  @override
  String get zubehoer3 => 'Clips & Schrauben';

  @override
  String get zubehoer4 => 'Höhenausgleich';

  @override
  String get zubehoer5 => 'Pads & EPDM-Bänder';

  @override
  String get zubehoer6 => 'Rhombusleisten';

  @override
  String get zubehoer7 => 'Terrassenfliesen';

  @override
  String get zubehoer8 => 'Terrassenöl RIBOL';

  @override
  String get verschnittoptimierung1 => 'Verschnittvariante auswählen';
}
