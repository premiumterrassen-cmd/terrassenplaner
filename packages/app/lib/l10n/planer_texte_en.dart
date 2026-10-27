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
  String volumen(String wert) {
    return 'Volume: $wert';
  }

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
  String get nummerFeld => 'Configuration number';

  @override
  String get nummerHinweis => 'e.g. 2026-10-08-1511';

  @override
  String get nummerFehler => 'Please enter in the format YYYY-MM-DD-NNNN';

  @override
  String get version => 'Version';

  @override
  String get ladeFehler => 'The configuration could not be loaded.';

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
}
