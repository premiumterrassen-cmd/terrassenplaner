import '../artikel/einheiten.dart';
import '../konfiguration/auflagen.dart';
import '../konfiguration/befestigungsart.dart';
import '../konfiguration/nutzungsart.dart';
import '../konfiguration/terrassenart.dart';
import '../konfiguration/untergrund.dart';
import '../konfiguration/verlegeart.dart';
import '../konfiguration/verlegerichtung.dart';
import '../regeln/auflager.dart';
import '../regeln/belagmeldungen.dart';
import '../regeln/flaechenpruefung.dart';
import 'materialliste.dart';
import 'stueckliste.dart';

/// Sprache der Planungsunterlagen (M9-06): Deutsch und Englisch wie die App
/// (M3-07).
enum Unterlagensprache {
  deutsch('de'),
  englisch('en');

  const Unterlagensprache(this.code);

  /// Sprachcode wie in der App (`de`, `en`).
  final String code;

  /// Sprache zum [code]; unbekannt: Deutsch.
  static Unterlagensprache ausCode(String code) =>
      values.where((s) => s.code == code).firstOrNull ?? deutsch;
}

/// Texte der Planungsunterlagen je Sprache (M9-06). Rechtliche Hinweise und
/// Grußtext wie in den Planungsunterlagen des alten Planers; Wortlaut der
/// Meldungen wie in der App.
final class Unterlagentexte {
  const Unterlagentexte._({
    required this.titel,
    required this.konfigurationsnummer,
    required this.version,
    required this.datum,
    required this.ohneNummer,
    required this.kunde,
    required this.kundenfelder,
    required this.zusammenfassung,
    required this.gesamtflaeche,
    required this.flaechenanzahl,
    required this.volumen,
    required this.verschnitt,
    required this.summeMaterial,
    required this.terrasse,
    required this.terrasseNummer,
    required this.haeufigkeit,
    required this.flaeche,
    required this.belag,
    required this.verlegerichtung,
    required this.verlegeart,
    required this.ausgangspunkt,
    required this.befestigung,
    required this.terrassenart,
    required this.unterkonstruktion,
    required this.untergrund,
    required this.nutzungsart,
    required this.nutzung,
    required this.privat,
    required this.gewerblich,
    required this.auflagen,
    required this.feldbreite,
    required this.geometrie,
    required this.eckpunkt,
    required this.aufbauhoehe,
    required this.winkel,
    required this.ukKapitel,
    required this.stuecklisteUk,
    required this.artikel,
    required this.laengeCm,
    required this.stueck,
    required this.farbeImPlan,
    required this.auflagerKapitel,
    required this.auflagerabstand,
    required this.auflager,
    required this.spalt,
    required this.anzahl,
    required this.belagKapitel,
    required this.dielenHinweis,
    required this.stossHinweis,
    required this.achsmassHinweis,
    required this.dielenNachNummer,
    required this.nr,
    required this.masse,
    required this.lieferung,
    required this.zuschnittBelag,
    required this.ausgangslaenge,
    required this.menge,
    required this.schnittmasse,
    required this.materialliste,
    required this.pos,
    required this.lfmGesamt,
    required this.jeLfm,
    required this.jeStueck,
    required this.gesamt,
    required this.laenge,
    required this.freidiele,
    required this.optional,
    required this.summeGesamt,
    required this.mehrwertsteuer,
    required this.preisHinweis,
    required this.preisFehlt,
    required this.hinweise,
    required this.rechtliches,
    required this.rechtlicheHinweise,
    required this.gruss,
    required this.absender,
    required this.seite,
    required this.dezimal,
    required this.tausender,
  });

  static const deutsch = Unterlagentexte._(
    titel: 'Planungsunterlagen',
    konfigurationsnummer: 'Ihre Konfigurationsnummer',
    version: 'Version',
    datum: 'Stand',
    ohneNummer: 'nicht gespeichert',
    kunde: 'Ihre Angaben',
    kundenfelder: ['Name', 'Adresse', 'Ort', 'Telefon', 'E-Mail'],
    zusammenfassung: 'Ihre konfigurierte Terrasse',
    gesamtflaeche: 'Terrassenfläche',
    flaechenanzahl: 'Anzahl der Flächen',
    volumen: 'Volumen',
    verschnitt: 'Verschnitt',
    summeMaterial: 'Summe Materialliste',
    terrasse: 'Ihre Terrasse',
    terrasseNummer: 'Terrasse',
    haeufigkeit: 'Anzahl gleicher Flächen',
    flaeche: 'Fläche',
    belag: 'Belag',
    verlegerichtung: 'Verlegerichtung',
    verlegeart: 'Verlegeart',
    ausgangspunkt: 'Ausgangspunkt',
    befestigung: 'Befestigung',
    terrassenart: 'Art der Terrasse',
    unterkonstruktion: 'Art der Unterkonstruktion',
    untergrund: 'Untergrund',
    nutzungsart: 'Art der Terrassennutzung',
    nutzung: 'Nutzung',
    privat: 'private Nutzung',
    gewerblich: 'gewerbliche Nutzung',
    auflagen: 'Auflagen',
    feldbreite: 'Feldbreite (UK-Achsabstand)',
    geometrie: 'Terrassengeometrie',
    eckpunkt: 'Eckpunkt',
    aufbauhoehe: 'Aufbauhöhe',
    winkel: 'Winkel',
    ukKapitel: 'Unterkonstruktion',
    stuecklisteUk: 'Stückliste Unterkonstruktion',
    artikel: 'Artikel',
    laengeCm: 'Länge in cm',
    stueck: 'Stück',
    farbeImPlan: 'Farbe im Plan',
    auflagerKapitel: 'Höhenzuordnung der Auflager',
    auflagerabstand: 'Abstand der Auflager',
    auflager: 'Auflager',
    spalt: 'Spalt UK bis Boden',
    anzahl: 'Anzahl',
    belagKapitel: 'Terrassenbelag',
    dielenHinweis:
        'Hinweis: Die Zahl in den Dielen/Platten ist die Nummer in der '
        'nachstehenden Tabelle.',
    stossHinweis:
        'Rot gestrichelt: Stoß – jedes Dielenende liegt auf einer eigenen '
        'UK (Doppel-UK).',
    achsmassHinweis: 'Blau: Achsmaße der UK in cm.',
    dielenNachNummer: 'Dielen/Platten nach Nummer',
    nr: 'Nr.',
    masse: 'Maße in cm',
    lieferung: 'Benötigte Dielen',
    zuschnittBelag: 'Zuschnittsplan Belag',
    ausgangslaenge: 'Ausgangslänge in cm',
    menge: 'Menge',
    schnittmasse: 'Schnittmaße in cm',
    materialliste: 'Materialliste',
    pos: 'Pos.',
    lfmGesamt: 'lfm gesamt',
    jeLfm: '€/lfm',
    jeStueck: '€/Stück',
    gesamt: '€ gesamt',
    laenge: 'Länge',
    freidiele: 'Freidiele',
    optional: 'optional – nicht in der Summe',
    summeGesamt: 'Summe gesamt',
    mehrwertsteuer: 'enthaltene $mehrwertsteuerSatz % MwSt.',
    preisHinweis:
        'Alle Preise inkl. MwSt. und nur zur Information – verbindlich ist '
        'unser Angebot.',
    preisFehlt:
        'Für Positionen mit „–“ ist kein Preis hinterlegt; sie fehlen in der '
        'Summe.',
    hinweise: 'Hinweise zur Planung',
    rechtliches: 'Rechtliche Hinweise',
    rechtlicheHinweise: [
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
    ],
    gruss: 'Es grüßt Sie das',
    absender: [
      'RobinienWelt TEAM',
      'anfrage@robinienwelt.de',
      'shop.robinienwelt.de',
    ],
    seite: 'Seite {n} von {gesamt}',
    dezimal: ',',
    tausender: '.',
  );

  static const englisch = Unterlagentexte._(
    titel: 'Planning documents',
    konfigurationsnummer: 'Your configuration number',
    version: 'Version',
    datum: 'Date',
    ohneNummer: 'not saved',
    kunde: 'Your details',
    kundenfelder: ['Name', 'Address', 'Town', 'Phone', 'Email'],
    zusammenfassung: 'Your configured terrace',
    gesamtflaeche: 'Terrace area',
    flaechenanzahl: 'Number of areas',
    volumen: 'Volume',
    verschnitt: 'Offcuts',
    summeMaterial: 'Material list total',
    terrasse: 'Your terrace',
    terrasseNummer: 'Terrace',
    haeufigkeit: 'Number of identical areas',
    flaeche: 'Area',
    belag: 'Decking',
    verlegerichtung: 'Laying direction',
    verlegeart: 'Laying pattern',
    ausgangspunkt: 'Starting point',
    befestigung: 'Fixing',
    terrassenart: 'Type of terrace',
    unterkonstruktion: 'Type of substructure',
    untergrund: 'Surface',
    nutzungsart: 'Type of terrace use',
    nutzung: 'Use',
    privat: 'Private use',
    gewerblich: 'Commercial use',
    auflagen: 'Supports',
    feldbreite: 'Joist spacing',
    geometrie: 'Terrace geometry',
    eckpunkt: 'Corner',
    aufbauhoehe: 'Construction height',
    winkel: 'Angle',
    ukKapitel: 'Substructure',
    stuecklisteUk: 'Substructure parts list',
    artikel: 'Item',
    laengeCm: 'Length in cm',
    stueck: 'Pieces',
    farbeImPlan: 'Colour in the plan',
    auflagerKapitel: 'Height assignment of the supports',
    auflagerabstand: 'Distance between supports',
    auflager: 'Support',
    spalt: 'Gap substructure to ground',
    anzahl: 'Quantity',
    belagKapitel: 'Decking',
    dielenHinweis:
        'Note: the number in the boards/tiles is the number in the table '
        'below.',
    stossHinweis:
        'Red dashed: butt joint – each board end rests on its own joist '
        '(double joist).',
    achsmassHinweis: 'Blue: joist centre distances in cm.',
    dielenNachNummer: 'Boards/tiles by number',
    nr: 'No.',
    masse: 'Size in cm',
    lieferung: 'Boards required',
    zuschnittBelag: 'Decking cutting plan',
    ausgangslaenge: 'Stock length in cm',
    menge: 'Quantity',
    schnittmasse: 'Cuts in cm',
    materialliste: 'Material list',
    pos: 'Pos.',
    lfmGesamt: 'Total m',
    jeLfm: '€/m',
    jeStueck: '€/piece',
    gesamt: '€ total',
    laenge: 'Length',
    freidiele: 'Free board',
    optional: 'optional – not included in the total',
    summeGesamt: 'Total',
    mehrwertsteuer: 'incl. $mehrwertsteuerSatz % VAT',
    preisHinweis:
        'All prices incl. VAT and for information only – our quotation is '
        'binding.',
    preisFehlt:
        'No price is stored for items marked “–”; they are missing from the '
        'total.',
    hinweise: 'Planning notes',
    rechtliches: 'Legal notes',
    rechtlicheHinweise: [
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
    ],
    gruss: 'Kind regards from the',
    absender: [
      'RobinienWelt TEAM',
      'anfrage@robinienwelt.de',
      'shop.robinienwelt.de',
    ],
    seite: 'Page {n} of {gesamt}',
    dezimal: '.',
    tausender: ',',
  );

  /// Texte der [sprache].
  static Unterlagentexte fuer(Unterlagensprache sprache) => switch (sprache) {
    Unterlagensprache.deutsch => deutsch,
    Unterlagensprache.englisch => englisch,
  };

  final String titel;
  final String konfigurationsnummer;
  final String version;
  final String datum;
  final String ohneNummer;
  final String kunde;

  /// Name, Adresse, Ort, Telefon, E-Mail.
  final List<String> kundenfelder;
  final String zusammenfassung;
  final String gesamtflaeche;
  final String flaechenanzahl;
  final String volumen;
  final String verschnitt;
  final String summeMaterial;
  final String terrasse;
  final String terrasseNummer;
  final String haeufigkeit;
  final String flaeche;
  final String belag;
  final String verlegerichtung;
  final String verlegeart;
  final String ausgangspunkt;
  final String befestigung;
  final String terrassenart;
  final String unterkonstruktion;
  final String untergrund;
  final String nutzungsart;
  final String nutzung;
  final String privat;
  final String gewerblich;
  final String auflagen;
  final String feldbreite;
  final String geometrie;
  final String eckpunkt;
  final String aufbauhoehe;
  final String winkel;
  final String ukKapitel;
  final String stuecklisteUk;
  final String artikel;
  final String laengeCm;
  final String stueck;
  final String farbeImPlan;
  final String auflagerKapitel;
  final String auflagerabstand;
  final String auflager;
  final String spalt;
  final String anzahl;
  final String belagKapitel;
  final String dielenHinweis;

  /// Legende der Stoßlinien im Verlegeplan (R-E01).
  final String stossHinweis;

  /// Legende der Achsmaßkette im UK-Plan (R-E02).
  final String achsmassHinweis;
  final String dielenNachNummer;
  final String nr;
  final String masse;
  final String lieferung;
  final String zuschnittBelag;
  final String ausgangslaenge;
  final String menge;
  final String schnittmasse;
  final String materialliste;
  final String pos;
  final String lfmGesamt;
  final String jeLfm;
  final String jeStueck;
  final String gesamt;
  final String laenge;
  final String freidiele;

  /// Kennzeichen einer optionalen Position (Planungskern v6 Regel 4.5).
  final String optional;
  final String summeGesamt;
  final String mehrwertsteuer;
  final String preisHinweis;
  final String preisFehlt;
  final String hinweise;
  final String rechtliches;
  final List<String> rechtlicheHinweise;
  final String gruss;
  final List<String> absender;

  /// Seitenangabe mit den Platzhaltern `{n}` und `{gesamt}`.
  final String seite;
  final String dezimal;
  final String tausender;

  bool get _de => dezimal == ',';

  /// „Seite 2 von 7“.
  String seitenangabe(int n, int gesamt) =>
      seite.replaceFirst('{n}', '$n').replaceFirst('{gesamt}', '$gesamt');

  /// [wert] mit [stellen] Nachkommastellen im Zahlformat der Sprache.
  String zahl(double wert, int stellen) =>
      wert.toStringAsFixed(stellen).replaceFirst('.', dezimal);

  /// Länge in cm ohne überflüssige Nachkommastelle: 480 bzw. 43,5.
  String cm(Millimeter laenge) => _ganzeCm(laenge) ?? zahl(laenge.cm, 1);

  /// Ganze Zentimeter von [laenge] als Text, sonst `null`.
  static String? _ganzeCm(Millimeter laenge) {
    final cm = laenge.mm ~/ 10;
    return cm * 10 == laenge.mm ? '$cm' : null;
  }

  /// Betrag mit Tausendertrennung und zwei Nachkommastellen, z. B.
  /// „2.066,57 €“ bzw. „2,066.57 €“.
  String preis(Cent betrag) {
    final text = betrag.anzeige;
    if (_de) return text;
    return text
        .replaceAll('.', '#')
        .replaceAll(',', dezimal)
        .replaceAll('#', tausender);
  }

  String stueckfarbe(Stueckfarbe farbe) => switch ((farbe, _de)) {
    (Stueckfarbe.rot, true) => 'rot',
    (Stueckfarbe.blau, true) => 'blau',
    (Stueckfarbe.gruen, true) => 'grün',
    (Stueckfarbe.rot, false) => 'red',
    (Stueckfarbe.blau, false) => 'blue',
    (Stueckfarbe.gruen, false) => 'green',
  };

  String einheit(Mengeneinheit einheit) => _de
      ? einheit.anzeige
      : switch (einheit) {
          Mengeneinheit.stueck => 'pcs',
          Mengeneinheit.laufmeter => 'm',
          Mengeneinheit.quadratmeter => 'm²',
          Mengeneinheit.verpackungseinheit => 'pack',
          Mengeneinheit.karton => 'box',
          Mengeneinheit.set => 'set',
          Mengeneinheit.kiste => 'crate',
          Mengeneinheit.liter => 'l',
        };

  String richtung(Verlegerichtung r, int winkel) => switch ((r, _de)) {
    (Verlegerichtung.waagrecht, true) => 'waagrecht',
    (Verlegerichtung.senkrecht, true) => 'senkrecht',
    (Verlegerichtung.waagrecht, false) => 'horizontal',
    (Verlegerichtung.senkrecht, false) => 'vertical',
    _ => '$winkel°',
  };

  String art(Verlegeart a) => switch ((a, _de)) {
    (Verlegeart.fugenschnitt, true) => 'Fugenschnitt',
    (Verlegeart.halbverband, true) => 'Halbverband',
    (Verlegeart.drittelverband, true) => 'Drittelverband',
    (Verlegeart.wechselverband, true) => 'Wechselverband',
    (Verlegeart.fugenschnitt, false) => 'Aligned joints',
    (Verlegeart.halbverband, false) => 'Half bond',
    (Verlegeart.drittelverband, false) => 'Third bond',
    (Verlegeart.wechselverband, false) => 'Alternating bond',
  };

  String befestigungsart(Befestigungsart b) => switch ((b, _de)) {
    (Befestigungsart.clips, true) => 'mit Clips',
    (Befestigungsart.verschraubt, true) => 'direkt verschraubt',
    (Befestigungsart.verschraubtMitAbstandshaltern, true) =>
      'verschraubt mit Abstandshaltern',
    (Befestigungsart.clips, false) => 'with clips',
    (Befestigungsart.verschraubt, false) => 'screwed directly',
    (Befestigungsart.verschraubtMitAbstandshaltern, false) =>
      'screwed with spacers',
  };

  String terrassenartText(Terrassenart a) => switch ((a, _de)) {
    (Terrassenart.normal, true) => 'normale Terrasse',
    (Terrassenart.hochterrasse, true) => 'Hochterrasse',
    (Terrassenart.vorhandeneUk, true) => 'vorhandene Unterkonstruktion',
    (Terrassenart.normal, false) => 'normal terrace',
    (Terrassenart.hochterrasse, false) => 'raised terrace',
    (Terrassenart.vorhandeneUk, false) => 'existing substructure',
  };

  String untergrundText(Untergrund u) => switch ((u, _de)) {
    (Untergrund.schotter, true) => 'Schotter (verdichtet)',
    (Untergrund.beton, true) => 'Beton',
    (Untergrund.bitumen, true) => 'Bitumenabdichtung',
    (Untergrund.schotter, false) => 'gravel (compacted)',
    (Untergrund.beton, false) => 'concrete',
    (Untergrund.bitumen, false) => 'bitumen sealing',
  };

  String nutzungsartText(Nutzungsart n) => switch ((n, _de)) {
    (Nutzungsart.schwimmend, true) => 'schwimmende Verlegung',
    (Nutzungsart.versteifungOhneRahmen, true) => 'Versteifung ohne Rahmen',
    (Nutzungsart.rahmen, true) => 'Rahmen',
    (Nutzungsart.versteifungMitRahmen, true) => 'Versteifung mit Rahmen',
    (Nutzungsart.doppelteUk, true) => 'doppelte Unterkonstruktion',
    (Nutzungsart.schwimmend, false) => 'floating installation',
    (Nutzungsart.versteifungOhneRahmen, false) => 'bracing without frame',
    (Nutzungsart.rahmen, false) => 'frame',
    (Nutzungsart.versteifungMitRahmen, false) => 'bracing with frame',
    (Nutzungsart.doppelteUk, false) => 'double substructure',
  };

  String auflagenText(Auflagen a) => switch ((a, _de)) {
    (Auflagen.stelzfuesse, true) => 'mit Stelzfüßen',
    (Auflagen.stelzfuesseUndPads, true) => 'mit Stelzfüßen und Pads',
    (Auflagen.stelzfuesse, false) => 'with adjustable feet',
    (Auflagen.stelzfuesseUndPads, false) => 'with adjustable feet and pads',
  };

  /// Meldung zum Belag wie in der App; [laenge] ist die gewählte
  /// Dielenlänge für [Belagmeldung.laengeNichtLieferbar].
  /// Meldung zur Größe der Fläche (Planungskern v6 Regel 1.7).
  String flaechenmeldung(Flaechenmeldung m) => switch ((m, _de)) {
    (Flaechenmeldung.masseFalsch, true) =>
      'Maße fehlen oder sind falsch: Die Fläche ist höchstens 0,05 m² groß.',
    (Flaechenmeldung.masseFalsch, false) =>
      'Dimensions are missing or wrong: the area is at most 0.05 m².',
    (Flaechenmeldung.unplausibelGross, true) =>
      'Die Fläche ist unplausibel groß (über 1.000 m²). Bitte prüfen Sie '
          'die Maße.',
    (Flaechenmeldung.unplausibelGross, false) =>
      'The area is implausibly large (over 1,000 m²). Please check the '
          'dimensions.',
    (Flaechenmeldung.ungewoehnlich, true) =>
      'Die Fläche liegt außerhalb der üblichen 1 bis 300 m² – bitte prüfen '
          'Sie die Maße.',
    (Flaechenmeldung.ungewoehnlich, false) =>
      'The area is outside the usual 1 to 300 m² – please check the '
          'dimensions.',
  };

  String belagmeldung(Belagmeldung m, Millimeter? laenge) => switch ((m, _de)) {
    (Belagmeldung.belagErsetzt, true) =>
      'Der gewählte Belag ist nicht mehr im Sortiment. Geplant wird mit '
          'dem Vorgabebelag.',
    (Belagmeldung.belagOhneMasse, true) =>
      'Für diesen Belag fehlen Breite oder Lieferlängen, er kann nicht '
          'verlegt werden.',
    (Belagmeldung.systemdieleOhneVerlegung, true) =>
      'Systemdielen werden im Längenmix endlos verlegt – das zeichnet '
          'der Planer noch nicht.',
    (Belagmeldung.flaecheKleinerAlsBelag, true) =>
      'Die Fläche oder eine Teilfläche ist kleiner als eine Diele bzw. '
          'Fliese: Es passt keine ganze Belagbreite hinein, nur ein '
          'Zuschnitt.',
    (Belagmeldung.fliesenSpitzeWinkel, true) =>
      'Die Fläche hat Ecken unter 90°. Holzfliesen müssen dort schräg '
          'zugeschnitten werden.',
    (Belagmeldung.bombierungEmpfohlen, true) =>
      'Ab 8 cm Breite empfehlen wir bombierte (leicht gewölbte) Dielen.',
    (Belagmeldung.laengeNichtLieferbar, true) =>
      'Die gewählte Länge von ${cm(laenge!)} cm gibt es für diesen Belag '
          'nicht. Die Dielenlänge wird automatisch ermittelt.',
    (Belagmeldung.befestigungsartNichtMoeglich, true) =>
      'Genutete Dielen werden verdeckt mit Clips befestigt. Die gewählte '
          'Verschraubung gilt nur für glattkante Dielen.',
    (Belagmeldung.befestigungOhneArtikel, true) =>
      'Für diesen Belag sind keine passenden Clips oder Schrauben '
          'hinterlegt – die Befestigung fehlt in der Materialliste.',
    (Belagmeldung.schraubeZuKurz, true) =>
      'Keine hinterlegte Schraube ist mindestens doppelt so lang, wie die '
          'Diele stark ist. Gerechnet wird mit der längsten – bitte prüfen '
          'Sie die Schraubenlänge.',
    (Belagmeldung.belagErsetzt, false) =>
      'The selected decking is no longer available. The plan uses the '
          'default decking.',
    (Belagmeldung.belagOhneMasse, false) =>
      'Width or delivery lengths are missing for this decking, so it '
          'cannot be laid.',
    (Belagmeldung.systemdieleOhneVerlegung, false) =>
      'System boards are laid endlessly in mixed lengths – the planner '
          'does not draw this yet.',
    (Belagmeldung.flaecheKleinerAlsBelag, false) =>
      'The area or a partial area is smaller than one board or tile: no '
          'full decking width fits, only a cut piece.',
    (Belagmeldung.fliesenSpitzeWinkel, false) =>
      'The area has corners below 90°. Wooden tiles must be cut at an '
          'angle there.',
    (Belagmeldung.bombierungEmpfohlen, false) =>
      'From 8 cm width we recommend crowned (slightly curved) boards.',
    (Belagmeldung.laengeNichtLieferbar, false) =>
      'The selected length of ${cm(laenge!)} cm is not available for this '
          'decking. The board length is determined automatically.',
    (Belagmeldung.befestigungsartNichtMoeglich, false) =>
      'Grooved boards are fixed invisibly with clips. The selected screw '
          'fixing only applies to smooth-edged boards.',
    (Belagmeldung.befestigungOhneArtikel, false) =>
      'No matching clips or screws are stored for this decking – the '
          'fixing is missing from the material list.',
    (Belagmeldung.schraubeZuKurz, false) =>
      'No stored screw is at least twice as long as the board is thick. '
          'The longest one is used – please check the screw length.',
  };

  /// Meldung zu den Höhengrenzen der Auflager (M6-08); [grenze] ist die
  /// unterschrittene bzw. überschrittene Höhe.
  String auflagermeldung(Auflagermeldung m, Millimeter grenze) =>
      switch ((m, _de)) {
        (Auflagermeldung.unterMindesthoehe, true) =>
          'Ein Höhenpunkt liegt unter der Mindesthöhe von ${cm(grenze)} cm '
              'mit Stelzfüßen.',
        (Auflagermeldung.ueberHoechsthoehe, true) =>
          'Ein Höhenpunkt liegt über der Höchsthöhe von ${cm(grenze)} cm mit '
              'Stelzfüßen.',
        (Auflagermeldung.unterMindesthoehe, false) =>
          'A height point lies below the minimum height of ${cm(grenze)} cm '
              'with adjustable feet.',
        (Auflagermeldung.ueberHoechsthoehe, false) =>
          'A height point lies above the maximum height of ${cm(grenze)} cm '
              'with adjustable feet.',
      };

  String get ukGedreht => _de
      ? 'Die Unterkonstruktion wird gedreht (Breite und Stärke getauscht), '
            'damit die Aufbauhöhe eingehalten wird.'
      : 'The substructure is turned (width and thickness swapped) to keep to '
            'the construction height.';

  String hoeheKorrigiert(Millimeter mindesthoehe) => _de
      ? 'Ein Höhenpunkt unterschritt die minimale Höhe von '
            '${cm(mindesthoehe)} cm und wurde korrigiert.'
      : 'A height point was below the minimum height of '
            '${cm(mindesthoehe)} cm and has been corrected.';

  /// Höhe ungültig (Planungsregeln Alexander (Planungskern v6, 11.11.2026),
  /// Regel 3a.5): über der [hoechsthoehe] mit Stellfüßen, gerechnet mit dem
  /// Standardaufbau; mit [vorschlag] die Rückfrage „Meintest du … cm?“.
  String hoeheUngueltig(Millimeter hoechsthoehe, Millimeter? vorschlag) => _de
      ? 'Höhe ungültig: höchstens ${cm(hoechsthoehe)} cm mit Stellfüßen. '
            'Gerechnet wird mit dem Standardaufbau.'
            '${vorschlag == null ? '' : ' Meintest du ${cm(vorschlag)} cm?'}'
      : 'Invalid height: at most ${cm(hoechsthoehe)} cm with adjustable '
            'feet. The standard build-up is used.'
            '${vorschlag == null ? '' : ' Did you mean ${cm(vorschlag)} cm?'}';

  /// Die Selbstkontrolle hat an einer Kante mit Dielenenden eine Rand-UK der
  /// Länge [laenge] ergänzt (Planungsregeln Alexander (Planungskern v6,
  /// 11.11.2026), Regel 3.4).
  String randUkErgaenzt(Millimeter laenge) => _de
      ? 'Rand-UK ${cm(laenge)} cm ergänzt: An einer Kante endeten Dielen '
            'ohne UK darunter.'
      : 'Edge substructure of ${cm(laenge)} cm added: boards ended at an edge '
            'without substructure underneath.';
}
