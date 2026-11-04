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
  String get speichern => 'SPEICHERN';

  @override
  String get laden => 'LADEN';

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
  String gesamtflaeche(String wert) {
    return 'Gesamtfläche: $wert';
  }

  @override
  String flaecheReiter(int nummer) {
    return 'Fläche $nummer';
  }

  @override
  String get flaecheHinzufuegen => 'Fläche hinzufügen';

  @override
  String get flaecheLoeschen => 'Fläche löschen';

  @override
  String get haeufigkeit => 'Häufigkeit der Fläche';

  @override
  String get haeufigkeitHinweis =>
      'Wie oft diese Fläche gebaut wird. Die Materialmengen werden entsprechend vervielfacht.';

  @override
  String get haeufigkeitWeniger => 'Seltener';

  @override
  String get haeufigkeitMehr => 'Öfter';

  @override
  String volumen(String wert) {
    return 'Volumen: $wert';
  }

  @override
  String verschnitt(String wert) {
    return 'Verschnitt: $wert';
  }

  @override
  String get benoetigteDielen => 'Benötigte Dielen:';

  @override
  String get keineDielen => 'Noch keine Dielen verlegt.';

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
  String get rundungenHinzufuegen => 'Rundungen hinzufügen';

  @override
  String get rundungenUebernehmen => 'Rundungen übernehmen';

  @override
  String get rundungenZuruecksetzen => 'Rundungen zurücksetzen';

  @override
  String get rundungHinweis =>
      'Griff an einer Ecke nach innen ziehen rundet die Ecke ab, Griff auf einer Seite zieht sie zum Bogen. Änderungen übernehmen (ESC).';

  @override
  String rundungEcke(String name) {
    return 'Ecke $name';
  }

  @override
  String rundungSeite(String name) {
    return 'Seite ab $name';
  }

  @override
  String get feldRadius => 'Radius';

  @override
  String get feldStich => 'Stich';

  @override
  String get rundungEntfernen => 'Rundung entfernen';

  @override
  String get rundungUnzulaessig => 'Diese Rundung ist nicht möglich.';

  @override
  String get rundungVerlassenTitel => 'Rundungen übernehmen?';

  @override
  String get rundungVerlassenText =>
      'Sie verlassen das Abrunden von Ecken und Seiten.';

  @override
  String get weitereFlaeche => 'Weitere Flächen hinzufügen';

  @override
  String get ausschnittEntfernen => 'Fläche entfernen';

  @override
  String get formDreieck => 'Dreieck';

  @override
  String get formSechseck => 'Sechseck';

  @override
  String get funktionLeer => 'leere Fläche';

  @override
  String get funktionBelag => 'anderer Terrassenbelag';

  @override
  String get inhaltLeer => 'leer/weiß';

  @override
  String get inhaltKies => 'Kies hell';

  @override
  String get inhaltStein => 'Stein dunkel';

  @override
  String get inhaltPool => 'Pool';

  @override
  String get inhaltRasen => 'Rasen';

  @override
  String get inhaltErde => 'Erde';

  @override
  String get feldBezeichnung => 'Flächenbezeichnung';

  @override
  String get meldungAusserhalb =>
      'Der Ausschnitt darf nicht außerhalb der Terrasse sein!';

  @override
  String meldungKollision(String a, String b) {
    return '$a und $b dürfen sich nicht überschneiden.';
  }

  @override
  String meldungTeilung(String a) {
    return '$a darf die Terrasse nicht teilen.';
  }

  @override
  String get schliessen => 'SCHLIESSEN';

  @override
  String get formDrehen => 'Form drehen';

  @override
  String get drehenTitel => 'Form drehen?';

  @override
  String get drehenText => 'Beim Drehen werden alle Ausschnitte zurückgesetzt.';

  @override
  String get drehenBestaetigen => 'Drehen';

  @override
  String get abbrechen => 'Abbrechen';

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
  String get nummerFeld => 'Konfigurationsnummer mit Prüfcode';

  @override
  String get nummerHinweis => 'z. B. 2026-10-08-1511-K7QXM';

  @override
  String get nummerFehler => 'Bitte im Format JJJJ-MM-TT-NNNN-XXXXX eingeben';

  @override
  String get version => 'Version';

  @override
  String get ladeFehler =>
      'Die Konfiguration konnte nicht geladen werden – der Server ist nicht erreichbar.';

  @override
  String get konfigurationUnbekannt =>
      'Diese Konfiguration gibt es nicht. Bitte prüfen Sie Konfigurationsnummer, Prüfcode und Version.';

  @override
  String get konfigurationSpeichernKnopf => 'Konfiguration Speichern';

  @override
  String get gefundenEntwurf =>
      'Wir haben eine ungespeicherte Konfiguration gefunden. Möchten Sie mit dieser weiterplanen?';

  @override
  String gespeichertMeldung(String nummer, int version) {
    return 'Gespeichert: Konfigurationsnummer $nummer, Version $version. Bitte notieren Sie die Nummer samt Prüfcode (die letzten fünf Zeichen) – nur damit lässt sich die Konfiguration wieder laden.';
  }

  @override
  String get speichernFehler =>
      'Speichern nicht möglich – der Server ist nicht erreichbar. Ihre Planung bleibt erhalten, bitte später erneut speichern.';

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
  String get terrassenbelag6 => 'Befestigungsart';

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

  @override
  String get produktauswahl => 'Produktauswahl';

  @override
  String belagMasse(String masse) {
    return 'Maße: $masse';
  }

  @override
  String belagFuge(int mm) {
    return 'Fuge: $mm mm';
  }

  @override
  String get belagLaedt => 'Beläge werden geladen …';

  @override
  String get belagFehler => 'Die Beläge konnten nicht geladen werden.';

  @override
  String get belagKeine => 'Keine Beläge in den Artikeldaten.';

  @override
  String get erneutVersuchen => 'Erneut versuchen';

  @override
  String get belagDialogTitel => 'Terrassenbelag auswählen';

  @override
  String get belagUnsichtbar => 'Unsichtbar befestigt';

  @override
  String get belagSichtbar => 'Sichtbar befestigt';

  @override
  String get belagHolzfliese => 'Holzfliese';

  @override
  String get belagSuche => 'Suche nach Titel oder Artikelnummer';

  @override
  String get filterMaterial => 'Material';

  @override
  String get filterOberseite => 'Oberseite';

  @override
  String get filterBreite => 'Breite';

  @override
  String get filterStaerke => 'Stärke';

  @override
  String get filterLaenge => 'Länge';

  @override
  String get filterZuruecksetzen => 'Filter zurücksetzen';

  @override
  String get oberseiteGlatt => 'glatt';

  @override
  String get oberseiteBombiert => 'bombiert';

  @override
  String get profilGenutet => 'genutet';

  @override
  String get profilGlattkant => 'glattkant';

  @override
  String abmessungen(String masse) {
    return 'Abmessungen: $masse';
  }

  @override
  String preisJeLfm(String preis) {
    return 'Preis je lfm: $preis inkl. MwSt.';
  }

  @override
  String preisJeM2(String preis) {
    return 'Preis je m²: $preis inkl. MwSt.';
  }

  @override
  String artikelnummer(String nummer) {
    return 'Artikelnummer: $nummer';
  }

  @override
  String materialAngabe(String material) {
    return 'Material: $material';
  }

  @override
  String profilAngabe(String profil) {
    return 'Profil: $profil';
  }

  @override
  String oberseiteAngabe(String oberseite) {
    return 'Oberseite: $oberseite';
  }

  @override
  String get artikelinfo => 'Artikelinfo';

  @override
  String get ja => 'Ja';

  @override
  String get nein => 'Nein';

  @override
  String get dielenlaengeOriginal => 'Mögliche Originallängen (in cm):';

  @override
  String dielenlaengeCm(int cm) {
    return '$cm cm';
  }

  @override
  String get verlegeartFugenschnitt => 'Fugenschnitt';

  @override
  String get verlegeartFugenschnittHinweis =>
      'Auf Fuge geschnitten: alle Stöße in einer Linie';

  @override
  String get verlegeartHalbverband => 'Halbverband';

  @override
  String get verlegeartHalbverbandHinweis =>
      'Jede zweite Reihe um eine halbe Diele versetzt';

  @override
  String get verlegeartDrittelverband => 'Drittelverband';

  @override
  String get verlegeartDrittelverbandHinweis =>
      'Jede Reihe um ein Drittel der Diele versetzt';

  @override
  String get verlegeartWechselverband => 'Wechselverband';

  @override
  String get verlegeartWechselverbandHinweis =>
      'Jede zweite Reihe beginnt an der Gegenseite';

  @override
  String get verlegerichtungWaagrecht => 'waagrecht';

  @override
  String get verlegerichtungSenkrecht => 'senkrecht';

  @override
  String get verlegerichtungDiagonal45 => '45 Grad';

  @override
  String get verlegerichtungDiagonal135 => '135 Grad';

  @override
  String get verlegerichtungIndividuell => 'Individueller Verlegewinkel';

  @override
  String get verlegewinkel => 'Winkel in Grad';

  @override
  String get verlegewinkelUngueltig =>
      'Bitte ganze Grad von 0 bis 179 eingeben';

  @override
  String get ausgangspunktFrage =>
      'Welcher Punkt soll der Ausgangspunkt des Terrassenbelages sein?';

  @override
  String get ausgangspunktVerschieben =>
      'Verschieben Sie die erste ganze Diele mit dem Mauszeiger oder dem Eingabefeld nach:';

  @override
  String get verschiebungLinksRechts => 'links/rechts um';

  @override
  String get verschiebungObenUnten => 'oben/unten um';

  @override
  String get verschiebungHilfeLinksRechts => 'in cm, negativ = links';

  @override
  String get verschiebungHilfeObenUnten => 'in cm, negativ = oben';

  @override
  String verschiebungCm(String cm) {
    return '$cm cm';
  }

  @override
  String verschiebungUngueltig(String grenze) {
    return 'Bitte eine Zahl von −$grenze bis $grenze cm eingeben';
  }

  @override
  String get verschiebungOhneDielen =>
      'Verschieben lässt sich die erste Diele, sobald ein Belag aus Dielen verlegt ist.';

  @override
  String get zuschnittWarnung =>
      'Achtung: Es entstehen Zuschnitte unter 5 cm. Verschieben Sie die erste ganze Diele, damit keine so schmalen oder kurzen Stücke entstehen.';

  @override
  String get befestigungsartClips => 'Mit Clips';

  @override
  String get befestigungsartVerschraubt => 'Direkt verschraubt';

  @override
  String get befestigungsartAbstandshalter => 'Verschraubt mit Abstandshaltern';

  @override
  String get befestigungOhneDielen =>
      'Die Befestigung ergibt sich, sobald ein Belag aus Dielen verlegt ist.';

  @override
  String befestigungspunkte(int anzahl) {
    return 'Befestigungspunkte: $anzahl';
  }

  @override
  String befestigungsmittel(int anzahl, String titel) {
    return '$anzahl × $titel';
  }

  @override
  String get kurzeStueckeVerbinden =>
      'Sollen kurze Dielenstücke miteinander verbunden werden?';

  @override
  String get dielenlaengeNichtWaehlbar =>
      'Für diesen Belag gibt es keine Längenauswahl.';

  @override
  String get belagKeinTreffer => 'Kein Belag passt zu den Filtern.';

  @override
  String get zurueckZurKonfiguration => 'Zurück zur Konfiguration';

  @override
  String get gewaehlt => 'Gewählt';

  @override
  String get belagmeldungBelagErsetzt =>
      'Der gewählte Belag ist nicht mehr im Sortiment. Geplant wird mit dem Vorgabebelag – wählen Sie bei Bedarf über „Produktauswahl“ einen anderen.';

  @override
  String get belagmeldungOhneMasse =>
      'Für diesen Belag fehlen Breite oder Lieferlängen, er kann nicht verlegt werden. Bitte wählen Sie einen anderen Belag.';

  @override
  String get belagmeldungSystemdiele =>
      'Systemdielen werden im Längenmix endlos verlegt – das zeichnet der Planer noch nicht.';

  @override
  String get belagmeldungFlaecheKleiner =>
      'Die Fläche oder eine Teilfläche ist kleiner als eine Diele bzw. Fliese: Es passt keine ganze Belagbreite hinein, nur ein Zuschnitt.';

  @override
  String get belagmeldungFliesenSpitzeWinkel =>
      'Die Fläche hat Ecken unter 90°. Holzfliesen müssen dort schräg zugeschnitten werden – für solche Formen eignen sich Dielen besser.';

  @override
  String get belagmeldungBombierung =>
      'Ab 8 cm Breite empfehlen wir bombierte (leicht gewölbte) Dielen.';

  @override
  String belagmeldungLaengeNichtLieferbar(int cm) {
    return 'Die gewählte Länge von $cm cm gibt es für diesen Belag nicht. Die Dielenlänge wird automatisch ermittelt.';
  }

  @override
  String get belagmeldungBefestigungsart =>
      'Genutete Dielen werden verdeckt mit Clips befestigt. Die gewählte Verschraubung gilt nur für glattkante Dielen.';

  @override
  String get belagmeldungOhneBefestigung =>
      'Für diesen Belag sind keine passenden Clips oder Schrauben hinterlegt – die Befestigung fehlt in der Materialliste. Bitte sprechen Sie uns an.';

  @override
  String get belagmeldungSchraubeZuKurz =>
      'Keine hinterlegte Schraube ist mindestens doppelt so lang, wie die Diele stark ist. Gerechnet wird mit der längsten – bitte prüfen Sie die Schraubenlänge.';

  @override
  String get zubehoerLaedt => 'Zubehör wird geladen …';

  @override
  String get zubehoerFehler => 'Das Zubehör konnte nicht geladen werden.';

  @override
  String get zubehoerKeine => 'In dieser Gruppe gibt es keine Artikel.';

  @override
  String get zubehoerBezeichnung => 'Bezeichnung';

  @override
  String get zubehoerTatsaechlich => 'Tatsächlich';

  @override
  String zubehoerMengeUngueltig(int max) {
    return 'Bitte 0 bis $max eingeben';
  }

  @override
  String zubehoerBerechnet(int anzahl) {
    return 'berechnet: $anzahl';
  }

  @override
  String zubehoerPflicht(int anzahl) {
    return 'Pflichtzubehör, mindestens $anzahl';
  }

  @override
  String zubehoerPflichtMindestens(int anzahl) {
    return 'Pflichtzubehör: mindestens $anzahl';
  }

  @override
  String get materialliste => 'Materialliste';

  @override
  String get materiallisteLeer =>
      'Die Materialliste entsteht, sobald ein Belag verlegt ist.';

  @override
  String get materialSpaltePosition => 'Pos.';

  @override
  String get materialSpalteBild => 'Bild';

  @override
  String get materialSpalteArtikel => 'Artikel';

  @override
  String get materialSpalteMenge => 'Menge';

  @override
  String get materialSpalteEinzelpreis => 'Einzelpreis';

  @override
  String get materialSpaltePreisJeLfm => 'Preis je lfm';

  @override
  String get materialSpalteGesamtLfm => 'Gesamt-lfm';

  @override
  String get materialSpaltePositionspreis => 'Positionspreis';

  @override
  String materialLaenge(int laenge) {
    return 'Länge: $laenge mm';
  }

  @override
  String get materialFreidiele => 'Freidiele';

  @override
  String materialBerechnet(int anzahl) {
    return 'berechnet: $anzahl';
  }

  @override
  String materialSumme(String betrag) {
    return 'Summe gesamt: $betrag';
  }

  @override
  String materialMehrwertsteuer(int satz, String betrag) {
    return 'enthaltene $satz % MwSt.: $betrag';
  }

  @override
  String get materialPreishinweis =>
      'Alle Preise inkl. MwSt. und nur zur Information – verbindlich ist unser Angebot.';

  @override
  String get materialOhnePreis =>
      'Für einzelne Artikel liegt kein Preis vor; sie fehlen in der Summe.';

  @override
  String get materialMengeUebernehmen => 'Menge übernehmen';

  @override
  String get materialMengeBerechnet => 'Berechnete Menge verwenden';

  @override
  String get materialMitarbeiter => 'Mitarbeiter-Ansicht: Mengen änderbar';

  @override
  String get einheitStueck => 'Stück';

  @override
  String get einheitLaufmeter => 'lfm';

  @override
  String get einheitQuadratmeter => 'm²';

  @override
  String get einheitVerpackungseinheit => 'VPE';

  @override
  String get einheitKarton => 'Karton';

  @override
  String get einheitSet => 'Set';

  @override
  String get einheitKiste => 'Kiste';

  @override
  String get einheitLiter => 'l';

  @override
  String get stueckliste => 'Stückliste';

  @override
  String get stuecklisteLeer =>
      'Die Stückliste entsteht, sobald ein Belag verlegt ist.';

  @override
  String get stueckSpalteArtikel => 'Artikel';

  @override
  String get stueckSpalteLaenge => 'Länge (cm)';

  @override
  String get stueckSpalteStueck => 'Stück';

  @override
  String get stueckSpalteFarbe => 'Farbe im Plan';

  @override
  String get stueckfarbeRot => 'rot – ganze Länge';

  @override
  String get stueckfarbeBlau => 'blau – zugeschnitten';

  @override
  String get stueckfarbeGruen => 'grün – Querstück';

  @override
  String get stuecklisteHinweis =>
      'Stücke der bearbeiteten Fläche; die Farbe zeigt das Stück in der Zeichnung.';
}
