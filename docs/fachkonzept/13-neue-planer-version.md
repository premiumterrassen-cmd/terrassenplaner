# 13 Neue Planer-Version – Ziel-Funktionsumfang (M1-05)

Der alte RobinienWelt-Konfigurator ([00](00-rahmen.md)–[08](08-ergebnisse.md)) ist eine **alte Version**. Die neue Version desselben Anbieters zeigt den Funktionsumfang, den der neue Planer haben soll: https://terrassenplaner.terrassen-montagesysteme.de/de (Vorgabe Alexander, 19.10.2026).

**Übernommen werden nur Funktionen** – nicht das Sortiment der Vorlage (Alu-Systeme, Clips, Rinnen, WaterUps …) und keine herstellerspezifischen Anpassungen. Robinien-Regeln und Artikel kommen aus Firmenwissen ([M1-04](../../ROADMAP.md)) und Master-Artikelliste (B-122). Wie beim alten Planer gilt: Quelle sind nur Bedienung und sichtbare Texte, kein Code und keine Architektur der Vorlage.

Erfasst am 19.10.2026 durch Bedienung (Ansicht 1440 × 900). Nicht ausgelöst wurden Speichern, Anmelden, PDF-Export, Grundriss-Upload, KI-Generierung, AR-Export und das Absenden der Anfrage – sie hätten Daten beim Anbieter angelegt.

## Überblick: alt ↔ neu

| Bereich | Alte Version | Neue Version |
|---|---|---|
| Start | Formwahl | „Manuell zeichnen“, „Grundriss importieren“ (KI, Bild jpg/png/webp), Standardformen, „Konfiguration laden“ |
| Ansichten | Draufsicht 2D, Ebenen Belag/UK/Maße | **2D · 3D · AR**; 3D-Ebenen (Belag, UK, Traglattung, Stelzfüße, Befestigung, Verblendung, Bemaßung), „Minimalistische Darstellung“, „Tageslicht“, **Aufbauanimation**, **3D-Modell herunterladen**, **AR-Datei exportieren** |
| KI | – | **KI-Terrassenvorschau**: Terrasse in ein Hausfoto einsetzen („Bild tauschen“, „Terrasse neu generieren“) |
| Flächen | eine Fläche + Ausschnitte/Teilflächen | **mehrere Flächen** (Reiter 1, 2, …, „Fläche hinzufügen“, Löschen), je Fläche eigene Einstellungen, **Häufigkeit der Fläche** (Mengen × n), Gesamtfläche = Summe |
| Zeichnen | Formen, Freiform | zusätzlich Zeichenmodus mit Freiform/Rechteck/Kreis/**Oval**, „Einrasten“, „Zeichnungshilfe“, Live-Maß; Punkt hinzufügen/entfernen; Rundungen mit Radius je Ecke |
| Sonderbauteile | – | **Hochbeet, Rampe, Treppe, Bank** als eigene Flächen |
| Art der Terrasse | normal, Hoch, vorhandene UK | normal, Hoch (**Anker: Anker / Fundamentschrauben / Mauern**), **Betonfundament (Mauern)**, vorhandene Konstruktion, **Podest**, **schwimmende Terrasse / Steg** |
| Höhe | Höhenpunkte, Gefälle | dazu **Oberflächengefälle %** mit Gefällerichtung, **Erhöhter Aufbau** (ganze Terrasse anheben) |
| Belag | Einzelartikel | Materialtyp + Farbe + frei eingebbare Maße, **mehrere Lieferlängen**, **wechselnde Dielenbreiten**, Start-/Endclips, Fremd-Clip, Fugen, Spannweite, Fugendichtungsband, Fugenprofile |
| Verlegung | 4 Verlegearten, 5 Richtungen | dazu **Viertelverband**, **Querdiele**, **automatische Designverlegung**, **Rahmendielen**, **Gehrungsschnitte** |
| Unterkonstruktion | Produkt, Länge, Nutzungsart, Querstreben | Rahmen/verstärkt, Stelzlager/Pads, Gefälleausgleich, Rahmen mit Querstreben/Rahmen/**Konterlattung**, Traversen durchgehend/versetzt, Fremd-UK, volle Profillängen, halbierte Längen, max. Stelzfußabstand, **UK von Hand anpassen** (Traversen, Querträger, Stelzlager, Stelzlagerhöhe, Fundamentpfosten) |
| Sicherung | – | **Wind- und Sogschutz, Beschwerungsplatten, Kipp- und Wipplast** |
| Anschluss | Bauelement, Verblendung, Rinne | **geschlossene Seiten, Wandanschlüsse, Seitenabdeckungen**, Rinnen je Seite oder global, Rinnen **innerhalb der Fläche**, **Drainageroste** |
| Verblendung | je Seite | 3 Verblendungsarten, **Blendenhöhe** (= Terrassenhöhe oder höher), **Teilverblendungen** |
| Treppen | Seite, Breite, Art, Stufen | dazu Bezeichnung, **Einrückung**, **Höhendifferenz**, Position außen/innen, Richtung auf-/absteigend |
| Zubehör | 8 Gruppen, manuelle Menge | Kategorien mit Artikelkarten und Mengenfeld |
| Ergebnisse | Kennzahlen, Materialliste, PDF, Anfrage | „Zusammenfassung der Konfiguration“ mit Projektbezeichnung, **Anzahl der Planungen**, Mengen änderbar, Positionen abwählbar; **Anfrage-Assistent** in 4 Schritten (privat/gewerblich, Datei-Upload bis 10 MB, Liefer- und Rechnungsadresse); PDF mit Stückliste |
| Sprache | Deutsch | Deutsch, Englisch |

## Je Schritt

### Rahmen und Werkzeugleiste
RESET (mit Rückfrage) · Rückgängig · Wiederherstellen · Zentrieren · Rotieren · Zoom · Rundung · Punkt hinzufügen/entfernen · Planungs-Nr. mit „Konfigurationsnummer kopieren“ und „Konfiguration speichern“ · Sprache · Anmelden. Die Schritte stehen rechts und zusätzlich als Leiste unten; „Materialliste“ und „Angebot anfragen“ sind immer sichtbar.

### 1 Grundriss
- **Flächenart** Terrasse | Sonderbauteil.
- **Formen** Rechteck, L, T, U, O, Kreis, Freiform, Grundriss hochladen (warnt, dass gezeichnete Formen verworfen werden). Standard Rechteck 750 × 500 cm.
- **Häufigkeit der Fläche** – „Wie oft diese Fläche gebaut wird. Die Materialmengen werden entsprechend vervielfacht.“
- **Flächenfunktion** Deckbelag | Leere Fläche.
- **Art der Terrasse** mit eigenen Feldern:
  - Hochterrasse: Auflage als Anker – Anker / Fundamentschrauben / Mauern; Standardhöhe 60 cm.
  - Betonfundament: Mauern mit Wandstärke (fest/manuell, 30 cm), „Mauern quer zur Unterkonstruktion setzen“, Mauer hinzufügen/entfernen; Höhe 30 cm.
  - Vorhandene Konstruktion: keine Aufbauhöhe.
  - Podest: nur eine Höhe (40 cm), kein Gefälle, keine Rundung.
  - Schwimmende Terrasse / Steg: freischwimmend oder am Ufer, Abstand der Schwimmfässer und Fassreihen (je 200 cm); verkürzte Schrittfolge.
- **Rundungen** im Bearbeitungsmodus, Radius je Ecke einstellbar, einzeln löschbar.
- **Aufbauhöhe** ohne/mit Gefälle (A–D + weitere Höhenpunkte; gemessen von Oberkante Belag bis Untergrund).
- **Oberflächengefälle** in % mit Gefällerichtung. Hinweis der Vorlage: Gefälle 1,5–2 % sei Pflicht – Standard ist trotzdem 0 % (Widerspruch, nicht übernehmen).
- **Erhöhter Aufbau** – Höhe der Erhöhung, verschiebt die ganze Terrasse (z. B. Anschluss an eine zweite Terrasse).
- **Sonderbauteile:** Hochbeet (Rahmenmaße), Rampe (Höhe Fuß/Kopf, Neigung, Ausrichtung), Treppe (wie Treppen unten, plus Ausrichtung), Bank (Lehne, Sitzfläche, Konstruktionsbreite).

### 2 Deckbelag
Materialtyp (Diele mit/ohne Nut, WPC, Bambus, Platte, Kunstrasen), Farbe, Längen (mehrere wählbar), Breite, Stärke, wechselnde Dielenbreiten, Start-/Endclips, Befestigung, Fremd-Clip, Fugenstärke und Stoßfugenabstand, Spannweite (Abstand der tragenden Auflagen), Fugendichtungsband (Warnhinweis zur Entwässerung), Aluminium-Fugenprofile.

### 3 Verlegeoption
Automatische Designverlegung (Vorschlag „aus langjähriger Projekterfahrung“) oder manuell; Verlegearten Fugenschnitt, Halb-, Drittel-, Viertel-, Wechselverband, Querdiele; Richtungen waagrecht, senkrecht, 45°, 135°, individuell; Rahmendielen; Gehrungsschnitte als zeichenbare Schnittflächen; Ausgangspunkt mit X/Y-Reglern.

### 4 Unterkonstruktion
Siehe Überblick. Neu ist vor allem das **Anpassen von Hand**: automatisch berechnete Traversen, Querträger und Stelzlager lassen sich ergänzen oder entfernen, Stelzlagerhöhen ändern, Stelzlager in Fundamentpfosten umwandeln.

### 5 Sicherung der Terrasse
Wind- und Sogschutz (mit Gewichten je lfm Belag und je Beschwerungsplatte), Beschwerungsplatten (max. 5 cm hoch), Kipp- und Wipplast.

### 6 Entwässerung + Rand
Je Seite: geschlossen, Wandanschluss, Seitenabdeckung, Rinne (Rinnenvariante je Seite oder global); Rinnen innerhalb der Fläche; Drainageroste platzieren.

### 7 Verblendung + Treppen
Verblendungsart (Blende aus Dielenbelag, Blendenwinkel, Platte), Blendenhöhe je Seite, Teilverblendungen. Treppen als Liste mit Bearbeiten/Löschen, in der Zeichnung beschriftet; Felder siehe Überblick.

### 8 Zubehör
Kategorien mit Artikelkarte und Mengenfeld.

### Ergebnisse
Zusammenfassung der Konfiguration (siehe Überblick), PDF mit Stückliste, Anfrage-Assistent. „Händler Info“ verlinkt nur auf die Herstellerseite.

## Zuordnung zur Roadmap

**Schon geplant, Umfang wächst:** M3-03 (Rückgängig/Wiederherstellen, Zentrieren, Rotieren), M3-04 (Ansichten, Ebenen), M3-07 (Englisch), M4-08 (Freiform + Oval, Einrasten, Zeichnungshilfe), M4-09 (Punkte hinzufügen/entfernen), M4-11 (Rundung mit Radius), M4-12 (mehrere Flächen statt nur Ausschnitte), M5-01/02 (Belag mit Farbe, mehrere Lieferlängen), M5-04 (Viertelverband, Querdiele), M5-06 (Gehrungsschnitte), M6-01 (neue Terrassenarten), M6-02 (Oberflächengefälle, erhöhter Aufbau), M6-06/08/10/11 (UK-Varianten, Konterlattung), M7-01–05 (Wandanschluss, Seitenabdeckung, Teilverblendung, Blendenhöhe, Rinnen in der Fläche, Treppen-Einrückung/Höhendifferenz), M9-03/06/07 (Zusammenfassung, Anzahl der Planungen, Anfrage-Assistent mit Upload).

**Neu (Vorschlag für Issues – Auswahl durch Alexander):**

| Vorschlag | Inhalt | Meilenstein |
|---|---|---|
| 3D-Ansicht | Terrasse in 3D mit Ebenen, Tageslicht, minimalistischer Darstellung | M3 (Architektur) + eigener Meilenstein |
| Aufbauanimation | schrittweiser Aufbau in 3D | 3D |
| 3D-Modell-Download und AR-Export | Datei für AR auf dem Handy | 3D |
| KI-Terrassenvorschau | Terrasse in ein Foto des Kunden einsetzen | später |
| Grundriss-Import mit KI | Plan/Foto → Grundriss | später |
| Mehrere Flächen und Häufigkeit | Reiter je Fläche, Mengen × n | M4 |
| Sonderbauteile | Hochbeet, Rampe, Treppe, Bank | M7 oder eigener |
| Neue Terrassenarten | Betonfundament mit Mauern, Podest, schwimmend/Steg, Ankerart bei Hochterrasse | M6 |
| Rahmendielen | umlaufender Dielenrahmen | M5 |
| Wechselnde Dielenbreiten | gemischte Breiten in einer Fläche | M5 |
| Automatische Designverlegung | Verlegevorschlag nach Gestaltungsregeln | M5 |
| UK von Hand anpassen | Traversen, Querträger, Stützen ergänzen/entfernen | M6 |
| Sicherung der Terrasse | Wind/Sog, Beschwerung, Kipp-/Wipplast | M6 |
| Drainageroste | platzierbare Roste | M7 |

## Auswirkungen auf die Architektur

- **3D und AR** sind die größte Erweiterung: Die Flutter-Web-App braucht eine WebGL-Darstellung. Vorschlag: ein Geometriemodell im domain-Paket (für 2D, 3D und alle Berechnungen gleich), daraus erzeugt der **Server** ein 3D-Modell (z. B. glTF/GLB) – passend zur Vorgabe „Frontend bleibt doof“. Die App zeigt es nur an (3D-Viewer per WebGL); dieselbe Datei dient für Download und AR. Das muss **vor M4** als Architektur-Entscheidung stehen, damit Geometrie-Kern (M4-01) und Zeichenfläche (M3-03) dafür ausgelegt sind.
- **Mehrere Flächen** ändern das Datenmodell: eine Konfiguration enthält n Flächen mit eigenen Einstellungen und Häufigkeit; Materialliste und Zuschnitt summieren über alle Flächen.
- **Rückgängig/Wiederherstellen** über alle Schritte setzt einen Änderungsverlauf der Konfiguration voraus (passt zu unveränderlichen Versionen im Datenmodell).
- **KI-Funktionen** (Vorschau, Grundriss-Import) brauchen einen externen Dienst – Kosten und Datenschutz klären, bevor sie geplant werden.

## Fragen an Alexander

1. Welche der neuen Funktionen aus der Tabelle „Neu“ sollen in den Planer – und welche erst nach dem Go-Live?
2. Belagtypen: Nur Robinie (Dielen, Systemdielen, Fliesen) oder auch WPC, Bambus, Kunstrasen, Platten?
3. Terrassenarten: Werden schwimmende Terrasse / Steg und Betonfundament mit Mauern gebraucht?
4. 3D/AR: Gehört das zum ersten Go-Live oder kommt es danach?
5. KI-Vorschau und Grundriss-Import: gewünscht? (externer Dienst, Kosten, Datenschutz)
6. Sonderbauteile (Hochbeet, Rampe, Bank): passen sie zu unserem Sortiment (z. B. Robinie-Hochbeet)?
