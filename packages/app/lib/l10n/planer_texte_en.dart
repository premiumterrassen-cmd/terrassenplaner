// coverage:ignore-file
// Von `flutter gen-l10n` erzeugt – nicht von Hand ändern.

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'planer_texte.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class PlanerTexteEn extends PlanerTexte {
  PlanerTexteEn([String locale = 'en']) : super(locale);

  @override
  String get sprachname => 'English';

  @override
  String get sprache => 'Language';

  @override
  String get darstellung => 'Appearance';

  @override
  String get darstellungHell => 'Light';

  @override
  String get darstellungDunkel => 'Dark';

  @override
  String get darstellungSystem => 'System';

  @override
  String get planerTitel => 'DECKING CONFIGURATOR';

  @override
  String get logoBeschreibung => 'RobinienWelt';

  @override
  String get folgt => 'This feature is coming soon.';

  @override
  String get verbinde => 'Connecting to the server …';

  @override
  String get keineVerbindung => 'No connection to the server';

  @override
  String get speichern => 'SAVE';

  @override
  String get laden => 'LOAD';

  @override
  String get zuruecksetzen => 'RESET';

  @override
  String get videoberatung => 'Book a video consultation';

  @override
  String get pdf => 'PDF';

  @override
  String get anfordern => 'REQUEST CONFIGURATION';

  @override
  String get anfordernKurz => 'REQUEST';

  @override
  String get fortschritt => 'Progress';

  @override
  String get menuEinklappen => 'Collapse menu';

  @override
  String get menuAusklappen => 'Expand menu';

  @override
  String flaeche(String wert) {
    return 'Area: $wert';
  }

  @override
  String gesamtflaeche(String wert) {
    return 'Total area: $wert';
  }

  @override
  String flaecheReiter(int nummer) {
    return 'Area $nummer';
  }

  @override
  String get flaecheHinzufuegen => 'Add area';

  @override
  String get flaecheLoeschen => 'Delete area';

  @override
  String get haeufigkeit => 'Frequency of the area';

  @override
  String get haeufigkeitHinweis =>
      'How often this area is built. Material quantities are multiplied accordingly.';

  @override
  String get haeufigkeitWeniger => 'Less often';

  @override
  String get haeufigkeitMehr => 'More often';

  @override
  String volumen(String wert) {
    return 'Volume: $wert';
  }

  @override
  String verschnitt(String wert) {
    return 'Waste: $wert';
  }

  @override
  String get benoetigteDielen => 'Boards required:';

  @override
  String get keineDielen => 'No boards laid yet.';

  @override
  String massPlatzhalter(String kante) {
    return '$kante: cm';
  }

  @override
  String get formRechteck => 'Rectangle';

  @override
  String get formLForm => 'L-shape';

  @override
  String get formTForm => 'T-shape';

  @override
  String get formUForm => 'U-shape';

  @override
  String get formOForm => 'O-shape';

  @override
  String get formKreis => 'Circle';

  @override
  String get formFreiform => 'Freeform';

  @override
  String get freiformHinweis => 'Set points – [x] to close the shape';

  @override
  String get einrastfunktion => 'Snap to grid';

  @override
  String get zeichnungshilfe => 'Drawing aid';

  @override
  String get eingabeStrecke => 'Distance';

  @override
  String get eingabeKoordinaten => 'Coordinates';

  @override
  String get feldWinkel => 'Angle';

  @override
  String winkelPlatzhalter(String feld) {
    return '$feld: °';
  }

  @override
  String get letztenPunktEntfernen => 'Remove last point';

  @override
  String get formSchliessen => 'Close shape';

  @override
  String get formGeschlossen => 'Shape closed';

  @override
  String punktAusgewaehlt(String name) {
    return 'Point $name';
  }

  @override
  String get eckeAntippen =>
      'Tap a corner to edit it; drag an edge midpoint to move the edge, tap it to add a point.';

  @override
  String get punktEntfernen => 'Remove point';

  @override
  String get freiformMindestens3 => 'The shape needs at least 3 points.';

  @override
  String get freiformKreuzt => 'Edges must not cross.';

  @override
  String freiformKante(int min, int max) {
    return 'Edges must be $min to $max cm long.';
  }

  @override
  String ausschnittTitel(String bezeichnung) {
    return 'Cut-out $bezeichnung';
  }

  @override
  String get feldLaenge => 'Length';

  @override
  String get feldBreite => 'Width';

  @override
  String massUngueltig(int min, int max) {
    return 'Please enter $min to $max cm';
  }

  @override
  String get berechnungFehler =>
      'Calculation not possible – please check the connection';

  @override
  String get agb => 'Terms';

  @override
  String get datenschutz => 'Privacy';

  @override
  String get impressum => 'Legal notice';

  @override
  String get zuruecksetzenTitel => 'Reset planning?';

  @override
  String get zuruecksetzenText =>
      'Are you sure you want to reset the planning? Your progress will be lost. Make sure you have saved the configuration and noted the configuration number.';

  @override
  String get zuruecksetzenZurueck => 'Back to configuration';

  @override
  String get zuruecksetzenBestaetigen => 'Reset configuration';

  @override
  String get standardwertTitel => 'Keep default values';

  @override
  String get standardwertText =>
      'You have not changed anything in these steps – the planner\'s default values apply there:';

  @override
  String get standardwertFrage => 'Do you want to continue anyway?';

  @override
  String get zurueck => 'Back';

  @override
  String get fortfahren => 'Continue';

  @override
  String get rueckgaengig => 'Undo';

  @override
  String get wiederherstellen => 'Redo';

  @override
  String get zentrieren => 'Center';

  @override
  String get rundungenHinzufuegen => 'Add roundings';

  @override
  String get rundungenUebernehmen => 'Apply roundings';

  @override
  String get rundungenZuruecksetzen => 'Reset roundings';

  @override
  String get rundungHinweis =>
      'Drag a corner handle inwards to round the corner, drag a side handle to curve the side. Apply changes (ESC).';

  @override
  String rundungEcke(String name) {
    return 'Corner $name';
  }

  @override
  String rundungSeite(String name) {
    return 'Side from $name';
  }

  @override
  String get feldRadius => 'Radius';

  @override
  String get feldStich => 'Rise';

  @override
  String get rundungEntfernen => 'Remove rounding';

  @override
  String get rundungUnzulaessig => 'This rounding is not possible.';

  @override
  String get rundungVerlassenTitel => 'Apply roundings?';

  @override
  String get rundungVerlassenText =>
      'You are leaving the rounding of corners and sides.';

  @override
  String get weitereFlaeche => 'Add further area';

  @override
  String get ausschnittEntfernen => 'Remove area';

  @override
  String get formDreieck => 'Triangle';

  @override
  String get formSechseck => 'Hexagon';

  @override
  String get funktionLeer => 'empty area';

  @override
  String get funktionBelag => 'other decking';

  @override
  String get inhaltLeer => 'empty/white';

  @override
  String get inhaltKies => 'Light gravel';

  @override
  String get inhaltStein => 'Dark stone';

  @override
  String get inhaltPool => 'Pool';

  @override
  String get inhaltRasen => 'Lawn';

  @override
  String get inhaltErde => 'Soil';

  @override
  String get feldBezeichnung => 'Area name';

  @override
  String get meldungAusserhalb =>
      'The cut-out must not lie outside the terrace!';

  @override
  String meldungKollision(String a, String b) {
    return '$a and $b must not overlap.';
  }

  @override
  String meldungTeilung(String a) {
    return '$a must not split the terrace.';
  }

  @override
  String get schliessen => 'CLOSE';

  @override
  String get formDrehen => 'Rotate shape';

  @override
  String get drehenTitel => 'Rotate shape?';

  @override
  String get drehenText => 'Rotating resets all cut-outs.';

  @override
  String get drehenBestaetigen => 'Rotate';

  @override
  String get abbrechen => 'Cancel';

  @override
  String get verkleinern => 'Zoom out';

  @override
  String get vergroessern => 'Zoom in';

  @override
  String get zoom => 'Zoom';

  @override
  String get bedienHinweis => 'Mouse wheel: zoom · Drag: move';

  @override
  String get beschriftungen => 'Labels';

  @override
  String get ebeneBelag => 'Deck';

  @override
  String get ebeneUnterkonstruktion => 'Sub';

  @override
  String get ebeneMasse => 'Dims';

  @override
  String get ebeneBelagLang => 'Decking';

  @override
  String get ebeneUnterkonstruktionLang => 'Substructure';

  @override
  String get ebeneMasseLang => 'Dimensions';

  @override
  String get beschriftungSeitenlaengen => 'Side lengths';

  @override
  String get beschriftungWinkel => 'Angles';

  @override
  String get beschriftungPunkte => 'Points';

  @override
  String get beschriftungAblaeufe => 'Drains';

  @override
  String get ablauf => 'Drain';

  @override
  String get willkommenTitel =>
      'Welcome to the RobinienWelt decking configurator!';

  @override
  String get willkommenText =>
      'Plan your dream terrace made of robinia in just a few clicks: you choose the boards, the laying pattern and the substructure yourself. Then order directly or request a quote. Personal help is available in the video consultation.';

  @override
  String get konfigurationLadenKnopf => 'LOAD CONFIGURATION';

  @override
  String get neuKnopf => 'CONFIGURE YOUR DREAM TERRACE';

  @override
  String gefunden(String nummer, int version) {
    return 'We found a configuration. Would you like to continue planning with it? ($nummer, version $version)';
  }

  @override
  String get weiterplanen => 'CONTINUE PLANNING';

  @override
  String get ladenTitel => 'Load configuration';

  @override
  String get nummerFeld => 'Configuration number with check code';

  @override
  String get nummerHinweis => 'e.g. 2026-10-08-1511-K7QXM';

  @override
  String get nummerFehler => 'Please enter in the format YYYY-MM-DD-NNNN-XXXXX';

  @override
  String get version => 'Version';

  @override
  String get ladeFehler =>
      'The configuration could not be loaded – the server cannot be reached.';

  @override
  String get konfigurationUnbekannt =>
      'This configuration does not exist. Please check the configuration number, check code and version.';

  @override
  String get konfigurationSpeichernKnopf => 'Save configuration';

  @override
  String get gefundenEntwurf =>
      'We found an unsaved configuration. Would you like to continue planning with it?';

  @override
  String gespeichertMeldung(String nummer, int version) {
    return 'Saved: configuration number $nummer, version $version. Please note the number including the check code (the last five characters) – only with it can the configuration be loaded again.';
  }

  @override
  String get speichernFehler =>
      'Saving is not possible – the server cannot be reached. Your planning is kept, please save again later.';

  @override
  String get modell3dTitel => '3D preview (prototype): terrace 4 x 3 m';

  @override
  String get modell3dLaedt => 'Loading 3D model …';

  @override
  String get modell3dFehler => 'The 3D model could not be loaded';

  @override
  String get nurImBrowser => 'The 3D view is only available in the browser.';

  @override
  String get keinBild => 'No image';

  @override
  String get schrittGrundriss => 'FLOOR PLAN';

  @override
  String get schrittTerrassenbelag => 'DECKING';

  @override
  String get schrittTerrassenbelagGetrennt => 'DECKING';

  @override
  String get schrittUnterkonstruktion => 'SUBSTRUCTURE';

  @override
  String get schrittUnterkonstruktionGetrennt => 'SUB-\nSTRUCTURE';

  @override
  String get schrittTerrassenanschluss => 'CONNECTIONS';

  @override
  String get schrittTerrassenanschlussGetrennt => 'CONNEC-\nTIONS';

  @override
  String get schrittTreppen => 'STAIRS';

  @override
  String get schrittZubehoer => 'ACCESSORIES';

  @override
  String get schrittVerschnittoptimierung => 'CUTTING OPTIMISATION';

  @override
  String get schrittVerschnittoptimierungGetrennt => 'CUTTING\nOPTIMISATION';

  @override
  String get grundriss1 => 'Choose terrace shape';

  @override
  String get grundriss2 => 'Terrace dimensions';

  @override
  String get grundriss3 => 'Round corners and sides';

  @override
  String get grundriss4 => 'Cut-outs and partial areas';

  @override
  String get terrassenbelag1 => 'Choose decking';

  @override
  String get terrassenbelag2 => 'Determine board length automatically';

  @override
  String get terrassenbelag3 => 'Laying patterns';

  @override
  String get terrassenbelag4 => 'Laying directions';

  @override
  String get terrassenbelag5 => 'Starting point of the decking';

  @override
  String get terrassenbelag6 => 'Fastening method';

  @override
  String get unterkonstruktion1 => 'Type of terrace';

  @override
  String get unterkonstruktion2 => 'Height points';

  @override
  String get unterkonstruktion3 => 'Choose substructure';

  @override
  String get unterkonstruktion4 => 'Length of the substructure';

  @override
  String get unterkonstruktion5 => 'Subsoil';

  @override
  String get unterkonstruktion6 => 'Type of terrace use';

  @override
  String get unterkonstruktion7 => 'Cross braces';

  @override
  String get unterkonstruktion8 => 'Private or commercial use';

  @override
  String get terrassenanschluss1 => 'Adjacent building elements';

  @override
  String get terrassenanschluss2 => 'Fascia';

  @override
  String get terrassenanschluss3 => 'Drainage channels';

  @override
  String get treppen1 => 'Stairs';

  @override
  String get zubehoer1 => 'General';

  @override
  String get zubehoer2 => 'Delivery';

  @override
  String get zubehoer3 => 'Clips & screws';

  @override
  String get zubehoer4 => 'Height adjustment';

  @override
  String get zubehoer5 => 'Pads & EPDM tapes';

  @override
  String get zubehoer6 => 'Rhombus battens';

  @override
  String get zubehoer7 => 'Deck tiles';

  @override
  String get zubehoer8 => 'RIBOL decking oil';

  @override
  String get verschnittoptimierung1 => 'Choose cutting variant';

  @override
  String get produktauswahl => 'Product selection';

  @override
  String belagMasse(String masse) {
    return 'Dimensions: $masse';
  }

  @override
  String belagFuge(int mm) {
    return 'Joint: $mm mm';
  }

  @override
  String get belagLaedt => 'Loading decking …';

  @override
  String get belagFehler => 'The decking could not be loaded.';

  @override
  String get belagKeine => 'No decking in the article data.';

  @override
  String get erneutVersuchen => 'Try again';

  @override
  String get belagDialogTitel => 'Select decking';

  @override
  String get belagUnsichtbar => 'Hidden fastening';

  @override
  String get belagSichtbar => 'Visible fastening';

  @override
  String get belagHolzfliese => 'Wood tile';

  @override
  String get belagSuche => 'Search by title or article number';

  @override
  String get filterMaterial => 'Material';

  @override
  String get filterOberseite => 'Top side';

  @override
  String get filterBreite => 'Width';

  @override
  String get filterStaerke => 'Thickness';

  @override
  String get filterLaenge => 'Length';

  @override
  String get filterZuruecksetzen => 'Reset filters';

  @override
  String get oberseiteGlatt => 'smooth';

  @override
  String get oberseiteBombiert => 'convex';

  @override
  String get profilGenutet => 'grooved';

  @override
  String get profilGlattkant => 'square edge';

  @override
  String abmessungen(String masse) {
    return 'Dimensions: $masse';
  }

  @override
  String preisJeLfm(String preis) {
    return 'Price per running metre: $preis incl. VAT';
  }

  @override
  String preisJeM2(String preis) {
    return 'Price per m²: $preis incl. VAT';
  }

  @override
  String artikelnummer(String nummer) {
    return 'Article number: $nummer';
  }

  @override
  String materialAngabe(String material) {
    return 'Material: $material';
  }

  @override
  String profilAngabe(String profil) {
    return 'Profile: $profil';
  }

  @override
  String oberseiteAngabe(String oberseite) {
    return 'Top side: $oberseite';
  }

  @override
  String get artikelinfo => 'Article info';

  @override
  String get ja => 'Yes';

  @override
  String get nein => 'No';

  @override
  String get dielenlaengeOriginal => 'Available original lengths (in cm):';

  @override
  String dielenlaengeCm(int cm) {
    return '$cm cm';
  }

  @override
  String get verlegeartFugenschnitt => 'Aligned joints';

  @override
  String get verlegeartFugenschnittHinweis =>
      'Cut on the joint: all butt joints in one line';

  @override
  String get verlegeartHalbverband => 'Half bond';

  @override
  String get verlegeartHalbverbandHinweis =>
      'Every second row offset by half a board';

  @override
  String get verlegeartDrittelverband => 'Third bond';

  @override
  String get verlegeartDrittelverbandHinweis =>
      'Each row offset by a third of a board';

  @override
  String get verlegeartWechselverband => 'Alternating bond';

  @override
  String get verlegeartWechselverbandHinweis =>
      'Every second row starts at the opposite side';

  @override
  String get verlegerichtungWaagrecht => 'Horizontal';

  @override
  String get verlegerichtungSenkrecht => 'Vertical';

  @override
  String get verlegerichtungDiagonal45 => '45 degrees';

  @override
  String get verlegerichtungDiagonal135 => '135 degrees';

  @override
  String get verlegerichtungIndividuell => 'Custom laying angle';

  @override
  String get verlegewinkel => 'Angle in degrees';

  @override
  String get verlegewinkelUngueltig =>
      'Please enter whole degrees from 0 to 179';

  @override
  String get ausgangspunktFrage =>
      'Which point should be the starting point of the decking?';

  @override
  String get ausgangspunktVerschieben =>
      'Move the first full board with the mouse pointer or the input field:';

  @override
  String get verschiebungLinksRechts => 'left/right by';

  @override
  String get verschiebungObenUnten => 'up/down by';

  @override
  String get verschiebungHilfeLinksRechts => 'in cm, negative = left';

  @override
  String get verschiebungHilfeObenUnten => 'in cm, negative = up';

  @override
  String verschiebungCm(String cm) {
    return '$cm cm';
  }

  @override
  String verschiebungUngueltig(String grenze) {
    return 'Please enter a number from −$grenze to $grenze cm';
  }

  @override
  String get verschiebungOhneDielen =>
      'The first board can be moved as soon as decking boards are laid.';

  @override
  String get zuschnittWarnung =>
      'Caution: there are cuts under 5 cm. Move the first full board so that no such narrow or short pieces are left.';

  @override
  String get befestigungsartClips => 'With clips';

  @override
  String get befestigungsartVerschraubt => 'Screwed directly';

  @override
  String get befestigungsartAbstandshalter => 'Screwed with spacers';

  @override
  String get befestigungOhneDielen =>
      'The fastening follows as soon as decking boards are laid.';

  @override
  String befestigungspunkte(int anzahl) {
    return 'Fastening points: $anzahl';
  }

  @override
  String befestigungsmittel(int anzahl, String titel) {
    return '$anzahl × $titel';
  }

  @override
  String get kurzeStueckeVerbinden =>
      'Should short board pieces be joined together?';

  @override
  String get dielenlaengeNichtWaehlbar =>
      'This decking has no choice of lengths.';

  @override
  String get belagKeinTreffer => 'No decking matches the filters.';

  @override
  String get zurueckZurKonfiguration => 'Back to configuration';

  @override
  String get gewaehlt => 'Selected';

  @override
  String get anmelden => 'LOG IN';

  @override
  String get abmelden => 'LOG OUT';

  @override
  String angemeldetAls(String email) {
    return 'Logged in as $email';
  }

  @override
  String get anmeldenTitel => 'Login';

  @override
  String get anmeldenHinweis => 'For ALTO HOLZ staff only.';

  @override
  String get emailFeld => 'Email address';

  @override
  String get passwortFeld => 'Password';

  @override
  String get anmeldenKnopf => 'Log in';

  @override
  String get anmeldungAbgelehnt =>
      'Login not possible. Please check email address and password – after several failed attempts the account is locked for 15 minutes.';

  @override
  String get anmeldungFehler =>
      'Login is not possible – the server cannot be reached.';

  @override
  String get abgemeldetMeldung => 'You are logged out.';

  @override
  String get nummerHinweisMitarbeiter =>
      'As a staff member the configuration number is enough – the check code may be omitted.';

  @override
  String get terrassenartNormal => 'Normal terrace';

  @override
  String get terrassenartHochterrasse => 'Raised terrace';

  @override
  String get terrassenartVorhandeneUk => 'Existing substructure';

  @override
  String vorgabehoehe(String cm) {
    return 'Default height: $cm cm';
  }

  @override
  String get spannweiteFrage =>
      'Span of the substructure (spacing of the existing joists)';

  @override
  String get spannweite => 'Span';

  @override
  String get spannweiteUngueltig => 'Please enter a number from 10 to 300 cm';

  @override
  String get hoehenpunkteHilfe =>
      'Measured from the top of the decking to the ground.';

  @override
  String get ohneGefaelle => 'without slope';

  @override
  String get mitGefaelle => 'with slope';

  @override
  String get hoeheAlle => 'All';

  @override
  String get hoeheUngueltig => 'Please enter a number above 0 up to 300 cm';

  @override
  String aufbauhoehe(String cm) {
    return 'Construction height (decking and substructure): $cm cm';
  }

  @override
  String get ukGedreht =>
      'The substructure is turned (width and thickness swapped) to keep to the construction height.';

  @override
  String hoeheKorrigiert(String cm) {
    return 'The height reference point is below the minimum height of $cm cm. It has been corrected.';
  }

  @override
  String get belagmeldungBelagErsetzt =>
      'The selected decking is no longer available. The plan uses the default decking – choose another one via “Product selection” if needed.';

  @override
  String get belagmeldungOhneMasse =>
      'Width or delivery lengths are missing for this decking, so it cannot be laid. Please choose another decking.';

  @override
  String get belagmeldungSystemdiele =>
      'System boards are laid endlessly in mixed lengths – the planner does not draw this yet.';

  @override
  String get belagmeldungFlaecheKleiner =>
      'The area or a partial area is smaller than one board or tile: no full decking width fits, only a cut piece.';

  @override
  String get belagmeldungFliesenSpitzeWinkel =>
      'The area has corners below 90°. Wooden tiles must be cut at an angle there – boards are better suited for such shapes.';

  @override
  String get belagmeldungBombierung =>
      'From 8 cm width we recommend crowned (slightly curved) boards.';

  @override
  String belagmeldungLaengeNichtLieferbar(int cm) {
    return 'The selected length of $cm cm is not available for this decking. The board length is determined automatically.';
  }

  @override
  String get belagmeldungBefestigungsart =>
      'Grooved boards are fixed invisibly with clips. The selected screw fixing only applies to smooth-edged boards.';

  @override
  String get belagmeldungOhneBefestigung =>
      'No matching clips or screws are stored for this decking – the fixing is missing from the material list. Please contact us.';

  @override
  String get belagmeldungSchraubeZuKurz =>
      'No stored screw is at least twice as long as the board is thick. The longest one is used – please check the screw length.';

  @override
  String get ukLaedt => 'Loading substructures …';

  @override
  String get ukFehler => 'The substructures could not be loaded.';

  @override
  String get ukKeine =>
      'No substructure in the range matches the selected decking.';

  @override
  String get ukDialogTitel => 'Select substructure';

  @override
  String get ukLaengeOhneUk =>
      'The length follows as soon as a substructure is selected.';

  @override
  String get automatisch => 'Automatic';

  @override
  String get materialliste => 'Material list';

  @override
  String get materiallisteLeer =>
      'The material list appears as soon as decking has been laid.';

  @override
  String get materialSpaltePosition => 'No.';

  @override
  String get materialSpalteBild => 'Image';

  @override
  String get materialSpalteArtikel => 'Item';

  @override
  String get materialSpalteMenge => 'Quantity';

  @override
  String get materialSpalteEinzelpreis => 'Unit price';

  @override
  String get materialSpaltePreisJeLfm => 'Price per lin. m';

  @override
  String get materialSpalteGesamtLfm => 'Total lin. m';

  @override
  String get materialSpaltePositionspreis => 'Line total';

  @override
  String materialLaenge(int laenge) {
    return 'Length: $laenge mm';
  }

  @override
  String get materialFreidiele => 'Free board';

  @override
  String materialBerechnet(int anzahl) {
    return 'calculated: $anzahl';
  }

  @override
  String materialSumme(String betrag) {
    return 'Total: $betrag';
  }

  @override
  String materialMehrwertsteuer(int satz, String betrag) {
    return 'incl. $satz % VAT: $betrag';
  }

  @override
  String get materialPreishinweis =>
      'All prices incl. VAT and for information only – our quotation is binding.';

  @override
  String get materialOhnePreis =>
      'Some items have no price yet; they are missing from the total.';

  @override
  String get materialMengeUebernehmen => 'Apply quantity';

  @override
  String get materialMengeBerechnet => 'Use calculated quantity';

  @override
  String get materialMitarbeiter => 'Staff view: quantities editable';

  @override
  String get einheitStueck => 'pcs';

  @override
  String get einheitLaufmeter => 'lin. m';

  @override
  String get einheitQuadratmeter => 'm²';

  @override
  String get einheitVerpackungseinheit => 'pack';

  @override
  String get einheitKarton => 'carton';

  @override
  String get einheitSet => 'set';

  @override
  String get einheitKiste => 'crate';

  @override
  String get einheitLiter => 'l';

  @override
  String get stueckliste => 'Parts list';

  @override
  String get stuecklisteLeer =>
      'The parts list appears as soon as decking has been laid.';

  @override
  String get stueckSpalteArtikel => 'Item';

  @override
  String get stueckSpalteLaenge => 'Length (cm)';

  @override
  String get stueckSpalteStueck => 'Pieces';

  @override
  String get stueckSpalteFarbe => 'Colour in the plan';

  @override
  String get stueckfarbeRot => 'red – full length';

  @override
  String get stueckfarbeBlau => 'blue – cut to length';

  @override
  String get stueckfarbeGruen => 'green – cross piece';

  @override
  String get stuecklisteHinweis =>
      'Pieces of the area being edited; the colour marks the piece in the drawing.';
}
