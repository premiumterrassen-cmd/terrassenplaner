import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Testsortiment für den Paritätsnachweis (M10-01): neutrale Artikel in den
/// Formaten der Referenzkonfigurationen, ohne Preise. Die echte Artikeldatei
/// gehört nicht ins Repository (Artikelimport, B-023); verglichen werden
/// deshalb Mengen und Längen, nicht Artikelnummern des Altsortiments.
const _laengen = [Millimeter(4000), Millimeter(5000), Millimeter(6000)];

Artikel _diele(int breite, int staerke, Profil profil) => Artikel(
  nummer: Artikelnummer('diele-$breite-$staerke-${profil.name}'),
  titel: 'Diele $breite x $staerke ${profil.name}',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: Millimeter(breite),
    staerke: Millimeter(staerke),
    laengen: _laengen,
  ),
  holzart: robinie,
  serie: basic,
  profil: profil,
);

Artikel _uk(
  String name,
  int breite,
  int staerke, {
  bool alu = false,
  int laenge = 4000,
}) => Artikel(
  nummer: Artikelnummer('uk-$name'),
  titel: 'UK $name',
  art: alu ? Artikelart.aluUnterkonstruktion : Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: Millimeter(breite),
    staerke: Millimeter(staerke),
    laengen: alu ? [Millimeter(laenge)] : const [],
  ),
  holzart: alu ? null : robinie,
  serie: alu ? null : basic,
);

Artikel _clip(int vpe) => Artikel(
  nummer: Artikelnummer('80-10-001-$vpe'),
  titel: 'Clip VPE $vpe',
  art: Artikelart.clip,
  einheit: Verkaufseinheit(Mengeneinheit.verpackungseinheit, inhalt: vpe),
);

final _clips = [_clip(50), _clip(100), _clip(250)];

final _schraube = Artikel(
  nummer: const Artikelnummer('schraube'),
  titel: 'Terrassenschraube',
  art: Artikelart.schraube,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
);

/// Blende 80 x 21 mm glattkant (F37, F38): die glattkante Diele der Serie
/// in der Belagstärke (Planungsregeln Alexander, Planungskern v6, 4a.1).
final blende = Artikel(
  nummer: const Artikelnummer('blende-80'),
  titel: 'Blende 80 x 21',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(80),
    staerke: const Millimeter(21),
    laengen: _laengen,
  ),
  holzart: robinie,
  serie: basic,
  profil: Profil.glattkant,
);

final _rinne = Artikel(
  nummer: const Artikelnummer('rinne'),
  titel: 'Ventilationsprofil',
  art: Artikelart.rinne,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  abmessungen: Abmessungen(
    breite: const Millimeter(120),
    laengen: const [Millimeter(1200)],
  ),
);

final _rinnenauflage = Artikel(
  nummer: const Artikelnummer('rinnenauflage'),
  titel: 'Auflagerprofil',
  art: Artikelart.rinnenzubehoer,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
);

/// Holzfliese 606 × 606 mm (ROBI-FIXX).
final fliese = Artikel(
  nummer: const Artikelnummer('fliese'),
  titel: 'Holzfliese',
  art: Artikelart.holzfliese,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  abmessungen: Abmessungen(
    breite: const Millimeter(606),
    laengen: const [Millimeter(606)],
  ),
);

/// Belag zum Text der Altdaten: „22 mm“ gibt es nicht, richtig 21 mm
/// (B-032); 23 und 26 mm bleiben.
Artikel? belagZuText(String? text) {
  if (text == null) return null;
  if (text.contains('liese')) return fliese;
  final m = RegExp(r'(\d+) x (\d+) mm').firstMatch(text);
  if (m == null) return null;
  final staerke = int.parse(m.group(2)!);
  return _diele(
    int.parse(m.group(1)!),
    staerke == 22 ? 21 : staerke,
    text.contains('glattkant') ? Profil.glattkant : Profil.genutet,
  );
}

/// UK zum Text der Altdaten; Alu-UK in der Länge aus dem Titel (RELO
/// „56 x 27 x 2000 mm“), sonst 4000 mm wie ALUecofix (F27).
Artikel? ukZuText(String? text) {
  if (text == null) return null;
  final m = RegExp(r'(\d+) ?x ?(\d+)(?: x (\d+))? ?mm').firstMatch(text);
  if (m == null) return null;
  final b = int.parse(m.group(1)!);
  final s = int.parse(m.group(2)!);
  final alu = !text.startsWith('Unterkonstruktionsholz');
  return _uk(
    '$b-$s${alu ? '-alu' : ''}',
    b,
    s,
    alu: alu,
    laenge: int.parse(m.group(3) ?? '4000'),
  );
}

/// Regelwerk für Belag und UK eines Falls.
Regelwerk regelwerkFuer(Artikel? belag, Artikel? uk) => Regelwerk(
  Artikeldatei(
    quelle: 'paritaet',
    version: '1',
    eintraege: [
      if (belag != null)
        Artikeleintrag(
          artikel: belag,
          verweise: {
            Beziehung.befestigung.spalte: belag.profil == Profil.glattkant
                ? [_schraube.nummer]
                : [for (final c in _clips) c.nummer],
            Beziehung.drainage.spalte: [_rinne.nummer],
          },
        ),
      for (final c in _clips) Artikeleintrag(artikel: c),
      Artikeleintrag(artikel: _schraube),
      if (belag != blende) Artikeleintrag(artikel: blende),
      Artikeleintrag(
        artikel: _rinne,
        benoetigt: {_rinnenauflage.nummer: 1},
        angaben: const {'Abstand_Stelzfuesse': 1000},
      ),
      Artikeleintrag(artikel: _rinnenauflage),
      if (uk != null) Artikeleintrag(artikel: uk),
    ],
  ),
);

/// Vergleichbare Vergleichswerte eines Falls, alt und neu gleich aufbereitet.
final class Vergleichswerte {
  Vergleichswerte({
    required this.flaeche,
    required this.verschnitt,
    required this.volumen,
    required this.dielen,
    required this.freidielen,
    required this.verblendung,
    required this.uk,
    required this.clips,
  });

  /// Aus Anzeige und Materialliste des alten Planers; Anfangsdielen zählen
  /// als normale Dielen (B-033).
  factory Vergleichswerte.alt(Referenzkonfiguration f) {
    final belag = f.eingaben['belag']! as String;
    final kern = belag.split(',').first;
    final dielen = <int, int>{};
    final verblendung = <int, int>{};
    final uk = <int, int>{};
    final clips = <int, int>{};
    var frei = 0;
    void zaehle(Map<int, int> ziel, int laenge, int anzahl) =>
        ziel.update(laenge, (n) => n + anzahl, ifAbsent: () => anzahl);
    for (final m in f.materialliste) {
      final laenge = m.laengeMm ?? 606;
      if (m.typ.startsWith('Deckbelag') || m.typ == 'Anfangsdiele') {
        if (m.bezeichnung.contains('Freidiele')) {
          frei += m.anzahl;
        } else if (m.bezeichnung.startsWith(kern) || m.typ == 'Anfangsdiele') {
          zaehle(dielen, laenge, m.anzahl);
        } else {
          zaehle(verblendung, laenge, m.anzahl);
        }
      } else if (m.typ == 'Unterkonstruktion') {
        zaehle(uk, laenge, m.anzahl);
      } else if (RegExp(r'CLIP-FIXX.*VPE (\d+)').firstMatch(m.bezeichnung)
          case final c?) {
        zaehle(clips, int.parse(c.group(1)!), m.anzahl);
      }
    }
    return Vergleichswerte(
      flaeche: f.flaecheM2,
      verschnitt: f.verschnittProzent,
      volumen: f.volumenM3,
      dielen: dielen,
      freidielen: frei,
      verblendung: verblendung,
      uk: uk,
      clips: clips,
    );
  }

  /// Aus der Berechnung des neuen Planers.
  factory Vergleichswerte.neu(
    Berechnung b,
    Artikel? belag,
    Artikel? ukArtikel,
  ) {
    final dielen = <int, int>{};
    final verblendung = <int, int>{};
    final uk = <int, int>{};
    final clips = <int, int>{};
    var frei = 0;
    void zaehle(Map<int, int> ziel, int laenge, int anzahl) =>
        ziel.update(laenge, (n) => n + anzahl, ifAbsent: () => anzahl);
    for (final p in b.materialliste.positionen) {
      final laenge = p.laenge?.mm ?? 606;
      if (p.zusatz == Materialzusatz.freidiele) {
        frei += p.anzahl;
      } else if (p.zusatz == Materialzusatz.verblendung) {
        zaehle(verblendung, laenge, p.anzahl);
      } else if (p.nummer == belag?.nummer) {
        zaehle(dielen, laenge, p.anzahl);
      } else if (p.nummer == ukArtikel?.nummer) {
        zaehle(uk, laenge, p.anzahl);
      } else if (p.nummer.wert.startsWith('80-10-001-')) {
        zaehle(clips, int.parse(p.nummer.wert.substring(10)), p.anzahl);
      }
    }
    return Vergleichswerte(
      flaeche: _runde(b.gesamtflaecheQuadratmeter, 3),
      verschnitt: b.verschnitt == null ? null : _runde(b.verschnitt! * 100, 2),
      volumen: b.volumen == null ? null : _runde(b.volumen!, 3),
      dielen: dielen,
      freidielen: frei,
      verblendung: verblendung,
      uk: uk,
      clips: clips,
    );
  }

  final double flaeche;
  final double? verschnitt;
  final double? volumen;
  final Map<int, int> dielen;
  final int freidielen;
  final Map<int, int> verblendung;
  final Map<int, int> uk;
  final Map<int, int> clips;

  /// Abweichende Größen gegenüber [neu] als Name → (alt, neu). Der
  /// Verschnitt zählt nur, wo der alte Planer ihn angezeigt hat. Das
  /// Volumen folgt aus Dielen und UK (M6-10): Bei gleichem Material weicht
  /// es nur ab, wenn es mehr als 5 % auseinanderliegt (21 statt 22 mm,
  /// B-032, sind 4,5 % der Dielen); sonst steckt die Abweichung schon im
  /// Material.
  Map<String, (String, String)> abweichungen(Vergleichswerte neu) {
    final material =
        _gleich(dielen, neu.dielen) &&
        _gleich(uk, neu.uk) &&
        _gleich(verblendung, neu.verblendung);
    return {
      if (flaeche != neu.flaeche) 'Fläche': ('$flaeche', '${neu.flaeche}'),
      if (verschnitt != null && verschnitt != neu.verschnitt)
        'Verschnitt': ('$verschnitt %', '${neu.verschnitt} %'),
      if (material &&
          volumen != null &&
          (neu.volumen! - volumen!).abs() > 0.05 * volumen!)
        'Volumen': ('$volumen m³', '${neu.volumen} m³'),
      if (!_gleich(dielen, neu.dielen))
        'Dielen': (stueckliste(dielen), stueckliste(neu.dielen)),
      if (freidielen != neu.freidielen)
        'Freidielen': ('$freidielen', '${neu.freidielen}'),
      if (!_gleich(verblendung, neu.verblendung))
        'Verblendung': (stueckliste(verblendung), stueckliste(neu.verblendung)),
      if (!_gleich(uk, neu.uk)) 'UK': (stueckliste(uk), stueckliste(neu.uk)),
      if (!_gleich(clips, neu.clips))
        'Clips': (_clipzahl(clips), _clipzahl(neu.clips)),
    };
  }

  @override
  String toString() =>
      'F $flaeche | V% $verschnitt | m³ $volumen | Dielen $dielen + '
      '$freidielen frei | Blende $verblendung | UK $uk | Clips $clips';
}

bool _gleich(Map<int, int> a, Map<int, int> b) =>
    a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

/// „48 × 5000 + 2 × 4000“ (mm), längste zuerst; „–“ ohne.
String stueckliste(Map<int, int> anzahl) {
  final laengen = anzahl.keys.toList()..sort((a, b) => b.compareTo(a));
  return laengen.isEmpty
      ? '–'
      : [for (final l in laengen) '${anzahl[l]} × $l'].join(' + ');
}

/// Clips als Stückzahl aus den Packungen (VPE → Anzahl).
String _clipzahl(Map<int, int> packungen) =>
    '${packungen.entries.fold(0, (n, e) => n + e.key * e.value)}';

/// Verschnittvariante des neuen Planers zur gewählten des alten: Variante 1
/// ist dort die übliche Verlegung (F01–F42, neu 0 = nicht optimiert),
/// weitere Varianten wählen die Optimierung (F43).
int _variante(int alt) => alt == 1 ? 0 : alt;

double _runde(double wert, int stellen) =>
    double.parse(wert.toStringAsFixed(stellen));

const _arten = {
  'Fugenschnitt': Verlegeart.fugenschnitt,
  'Halbverband': Verlegeart.halbverband,
  'Drittelverband': Verlegeart.drittelverband,
  'Wechselverband': Verlegeart.wechselverband,
};

const _nutzungen = {
  'schwimmende Verlegung': Nutzungsart.schwimmend,
  'Versteifung ohne Rahmen': Nutzungsart.versteifungOhneRahmen,
  'Rahmen': Nutzungsart.rahmen,
  'Versteifung mit Rahmen': Nutzungsart.versteifungMitRahmen,
  'doppelte Unterkonstruktion': Nutzungsart.doppelteUk,
};

const _treppenarten = {
  'Reguläre Treppe': Treppenart.regulaer,
  '2-teilige Fächertreppe': Treppenart.zweiteilig,
  '3-teilige Fächertreppe': Treppenart.dreiteilig,
};

Millimeter _cm(Object? wert) => Millimeter(((wert! as num) * 10).round());

int _seite(String kante) => kante.codeUnitAt(0) - 0x41;

/// Grundriss und Ausschnitte der Eingaben einer Referenzkonfiguration.
Planungsstand _grundriss(Map<String, Object?> e) {
  final k = e['kanten_cm']! as Map<String, Object?>;
  Millimeter m(String kante) => _cm(k[kante]);
  final grundriss = switch (e['form']) {
    'L-Form' => LGrundriss(m('A-B'), m('B-C'), m('C-D'), m('D-E')),
    'T-Form' => TGrundriss(
      m('B-C'),
      m('C-D'),
      m('D-E'),
      m('E-F'),
      m('G-H'),
      m('H-A'),
    ),
    'U-Form' => UGrundriss(
      m('A-B'),
      m('B-C'),
      m('C-D'),
      m('E-F'),
      m('F-G'),
      m('H-A'),
    ),
    'O-Form' => OGrundriss(m('A-B'), m('B-C')),
    'Kreis' => KreisGrundriss(_cm(e['radius_cm'])),
    _ => RechteckGrundriss(m('A-B'), m('B-C')),
  };
  final ausschnitte = <Ausschnitt>[];
  for (final a in e['ausschnitte']! as List<Object?>) {
    final j = a! as Map<String, Object?>;
    final ak = j['kanten_cm'] as Map<String, Object?>?;
    final laenge = ak == null ? _cm(j['laenge_cm']) : _cm(ak['A1-B1']);
    final breite = ak == null ? _cm(j['breite_cm']) : _cm(ak['B1-C1']);
    final huelle = Planungsstand(grundriss: grundriss).kontur.huellrechteck;
    ausschnitte.add(
      Ausschnitt(
        bezeichnung: j['name']! as String,
        // ohne Lage (O-Form F18): mittig wie die Vorgabe der O-Form
        x: j['x_cm'] == null
            ? Millimeter(((huelle.breite - laenge.mm) / 2).round())
            : _cm(j['x_cm']),
        y: j['y_cm'] == null
            ? Millimeter(((huelle.hoehe - breite.mm) / 2).round())
            : _cm(j['y_cm']),
        laenge: laenge,
        breite: breite,
        funktion: j['funktion'] == 'leere Fläche'
            ? Ausschnittfunktion.leer
            : Ausschnittfunktion.andererBelag,
      ),
    );
  }
  return Planungsstand(grundriss: grundriss, ausschnitte: ausschnitte);
}

/// Planungsstand des neuen Planers aus den Eingaben einer
/// Referenzkonfiguration (M1-03).
Planungsstand standAus(Referenzkonfiguration f, Artikel? belag, Artikel? uk) {
  final e = f.eingaben;
  var s = _grundriss(e).mitVerlegeart(_arten[e['verlegeart']]!);
  if (belag != null) s = s.mitBelag(belag.nummer);
  if (uk != null) s = s.mitUnterkonstruktion(uk.nummer);
  if (e['dielenlaenge'] case final String t when t.startsWith('fest ')) {
    s = s.mitDielenlaenge(_cm(int.parse(t.substring(5))));
  }
  final richtung = e['verlegerichtung']! as String;
  s = switch (richtung) {
    'Senkrecht' => s.mitVerlegerichtung(Verlegerichtung.senkrecht),
    'Diagonal 45' => s.mitVerlegerichtung(Verlegerichtung.diagonal45),
    'Diagonal 135' => s.mitVerlegerichtung(Verlegerichtung.diagonal135),
    _ when richtung.startsWith('Individuell') => s.mitVerlegerichtung(
      Verlegerichtung.individuell,
      winkel: int.parse(richtung.split(' ').last),
    ),
    _ => s,
  };
  if (e['ausgangspunkt'] case {
    'punkt': final String p,
    'waagrecht_cm': final num x,
    'senkrecht_cm': final num y,
  }) {
    s = s.mitAusgangspunkt(ecke: _seite(p), x: _cm(x), y: _cm(y));
  }
  switch (e['art']) {
    case 'Hochterrasse':
      s = s.mitTerrassenart(Terrassenart.hochterrasse);
    case 'Vorhandene UK':
      s = s
          .mitTerrassenart(Terrassenart.vorhandeneUk)
          .mitSpannweite(_cm(e['spannweite_cm']));
  }
  if (e['hoehe_cm'] case final num h) s = s.mitHoehe(_cm(h));
  if (e['hoehenpunkte_cm'] case final Map<String, Object?> h) {
    s = s.mitGefaelle(true);
    for (final MapEntry(:key, :value) in h.entries) {
      s = s.mitEckhoehe(_seite(key), _cm(value));
    }
  }
  s = s
      .mitNutzungsart(_nutzungen[e['nutzung']]!)
      .mitGewerblich(e['gewerblich']! as bool);
  for (final k in e['bauelement_seiten']! as List<Object?>) {
    s = s.mitAngrenzend(_seite(k! as String), an: true);
  }
  for (final k in e['verblendung_seiten']! as List<Object?>) {
    s = s.mitVerblendet(_seite(k! as String), an: true);
  }
  for (final k in (e['rinnen']! as Map<String, Object?>).keys) {
    s = s.mitRinne(_seite(k), Rinnenlage.gesamteSeite);
  }
  for (final t in e['treppen']! as List<Object?>) {
    final j = t! as Map<String, Object?>;
    s = s.mitNeuerTreppe().mitTreppe(
      s.treppen.length,
      Treppe(
        seite: _seite(j['start']! as String),
        bau: j['konstruktionsart'] == 'Fundament'
            ? Treppenbau.fundament
            : Treppenbau.konstruktion,
        art: _treppenarten[j['treppenart']]!,
        anzahl: j['stufen']! as int,
        stufe: (tiefe: _cm(j['tiefe_cm']), hoehe: _cm(j['hoehe_cm'])),
      ),
    );
  }
  return s;
}

/// Rechnet eine Referenzkonfiguration im neuen Planer
/// (`PlanungsDienst.berechnePlanung`) mit dem Testsortiment.
Vergleichswerte rechneKonfiguration(Referenzkonfiguration f) {
  final belag = belagZuText(f.eingaben['belag'] as String?);
  final uk = ukZuText(f.eingaben['unterkonstruktion'] as String?);
  final regelwerk = regelwerkFuer(belag, uk);
  final planung = Planung([
    Terrassenflaeche(standAus(f, belag, uk)),
  ], verschnittvariante: _variante(f.eingaben['verschnittvariante']! as int));
  final b = PlanungsDienst.berechnePlanung(
    planung,
    (n) => n == belag?.nummer ? belag : null,
    regelwerk,
    false,
    (_) => uk,
  );
  return Vergleichswerte.neu(b, belag, uk);
}

/// Vergleichswerte eines echten Referenzfalls (M1-02): Fläche und Lieferung
/// von Deckbelag und UK laut Zuschnittplänen (Länge in mm → Anzahl).
typedef Fallwerte = ({double? flaeche, Map<int, int> dielen, Map<int, int> uk});

Map<int, int> _lieferung(Iterable<(int, int)> zeilen) {
  final anzahl = <int, int>{};
  for (final (laenge, menge) in zeilen) {
    anzahl.update(laenge, (n) => n + menge, ifAbsent: () => menge);
  }
  return anzahl;
}

/// Abweichungen eines Referenzfalls als Name → (alt, neu); Listen nur, wo
/// die Unterlage sie enthält.
Map<String, (String, String)> fallAbweichungen(Fallwerte alt, Fallwerte neu) =>
    {
      if (alt.flaeche != null && alt.flaeche != neu.flaeche)
        'Fläche': ('${alt.flaeche}', '${neu.flaeche}'),
      if (alt.dielen.isNotEmpty && !_gleich(alt.dielen, neu.dielen))
        'Dielen': (stueckliste(alt.dielen), stueckliste(neu.dielen)),
      if (alt.uk.isNotEmpty && !_gleich(alt.uk, neu.uk))
        'UK': (stueckliste(alt.uk), stueckliste(neu.uk)),
    };

/// Werte der Unterlage des alten Planers.
Fallwerte fallAlt(Referenzfall f) {
  Map<int, int> liste(List<Zuschnitt> plan) => _lieferung([
    for (final z in plan) ((z.ausgangslaengeCm * 10).round(), z.menge),
  ]);
  return (
    flaeche: f.flaecheM2,
    dielen: liste(f.zuschnittDeckbelag),
    uk: liste(f.zuschnittUnterkonstruktion),
  );
}

/// Grundriss eines Referenzfalls fester Form ohne Ausschnitte und
/// Rundungen, wenn die Kantenmaße zur Form des neuen Planers passen (wie
/// M4-13); sonst `null` (Freiformen haben in den Unterlagen keine
/// vollständigen Maße).
Grundriss? grundrissAus(ReferenzGrundriss r) {
  final k = r.kantenCm;
  if (r.rundungen || r.ausschnitte.isNotEmpty) return null;
  Millimeter m(String kante) => Millimeter((k[kante]! * 10).round());
  bool hat(List<String> kanten) =>
      k.length == kanten.length && kanten.every((x) => k[x] != null);
  return switch (r.form) {
    'Rechteck' => RechteckGrundriss(m('A-B'), m('B-C')),
    'L-Form'
        when hat(['A-B', 'B-C', 'C-D', 'D-E', 'E-F', 'F-A']) &&
            k['E-F'] == k['A-B']! + k['C-D']! &&
            k['F-A'] == k['B-C']! + k['D-E']! =>
      LGrundriss(m('A-B'), m('B-C'), m('C-D'), m('D-E')),
    'T-Form'
        when hat(['A-B', 'B-C', 'C-D', 'D-E', 'E-F', 'F-G', 'G-H', 'H-A']) &&
            k['A-B'] == k['G-H']! + k['E-F']! + k['C-D']! &&
            k['F-G'] == k['B-C']! + k['D-E']! - k['H-A']! =>
      TGrundriss(m('B-C'), m('C-D'), m('D-E'), m('E-F'), m('G-H'), m('H-A')),
    _ => null,
  };
}

/// Rechnet einen Referenzfall im neuen Planer; [richtung] und [art], wo
/// die Zeichnung der Unterlage von Seite 1 abweicht (M1-02).
Fallwerte fallNeu(
  Referenzfall f,
  Map<String, Object?> eingaben,
  Grundriss grundriss, {
  Verlegerichtung? richtung,
  Verlegeart art = Verlegeart.fugenschnitt,
}) {
  final belag = belagZuText(f.belag ?? f.dielen.firstOrNull?.artikel);
  final uk = ukZuText(f.unterkonstruktion);
  var s = Planungsstand(grundriss: grundriss)
      .mitVerlegeart(art)
      .mitVerlegerichtung(
        richtung ??
            (f.verlegerichtung == 'Senkrecht'
                ? Verlegerichtung.senkrecht
                : Verlegerichtung.waagrecht),
      );
  if (eingaben['ausgangspunkt'] case {'punkt': final String p}) {
    s = s.mitAusgangspunkt(ecke: _seite(p));
  }
  if (belag != null) s = s.mitBelag(belag.nummer);
  if (uk != null) s = s.mitUnterkonstruktion(uk.nummer);
  final b = PlanungsDienst.berechnePlanung(
    Planung([Terrassenflaeche(s)]),
    (n) => n == belag?.nummer ? belag : null,
    regelwerkFuer(belag, uk),
    false,
    (_) => uk,
  );
  Map<int, int> liste(Zuschnittplan plan) =>
      _lieferung([for (final z in plan.zeilen) (z.ausgangslaenge.mm, z.menge)]);
  return (
    flaeche: double.parse(b.flaecheQuadratmeter.toStringAsFixed(3)),
    dielen: liste(b.zuschnittBelag),
    uk: liste(b.zuschnittUk),
  );
}
