#!/usr/bin/env node
// Prüfung des Ladebildschirms (M3-08) im echten Browser: headless Chrome über
// das DevTools-Protokoll, ohne Zusatzpakete (Node ≥ 22: fetch, WebSocket).
//
//   node tool/ladebild/pruefung.mjs [build/web]              alle Fälle prüfen
//   node tool/ladebild/pruefung.mjs --benchmark [build/web]  Benchmark-Zeilen
//   LADEBILD_FALL=offline node tool/ladebild/pruefung.mjs   nur passende Fälle
//
// Voraussetzung: gebaute Web-App mit Größenliste (flutter build web --wasm,
// danach tool/startgroessen.py) und ein laufender WAMP-Router
// (LADEBILD_WAMP_PORT, /ws wird wie von Traefik dorthin weitergereicht).
// Chrome aus CHROME_EXECUTABLE, sonst die übliche Installation.
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { connect } from 'node:net';
import { tmpdir } from 'node:os';
import { extname, join, normalize, resolve } from 'node:path';

const argumente = process.argv.slice(2);
const benchmark = argumente.includes('--benchmark');
const web = resolve(argumente.find((a) => !a.startsWith('--')) ?? 'packages/app/build/web');
const durchlaeufe = Number(process.env.LADEBILD_DURCHLAEUFE ?? 5);
// Port des WAMP-Routers (tool/smoke.sh); ohne Router zeigt die App „Keine Verbindung“.
const wampPort = process.env.LADEBILD_WAMP_PORT;

// Texte des Ladebildschirms (web/ladebild/fortschritt.js, Deutsch).
const TEXT = {
  langsam: 'Das Laden dauert länger. Bitte prüfen Sie Ihre Verbindung.',
  offline: 'Sie sind offline. Bitte prüfen Sie Ihre Verbindung.',
  fehlerTitel: 'Start nicht möglich',
};

// ---------------------------------------------------------------- Server

const TYPEN = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.css': 'text/css',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.ttf': 'font/ttf', '.otf': 'font/otf',
};

/** Liefert build/web aus – mit COOP/COEP wie nginx im Deployment und Cache-Headern. */
function starteServer() {
  const server = createServer((anfrage, antwort) => {
    let pfad = decodeURIComponent(new URL(anfrage.url, 'http://x').pathname);
    if (pfad.endsWith('/')) pfad += 'index.html';
    const datei = normalize(join(web, pfad));
    if (!datei.startsWith(web) || !existsSync(datei) || !statSync(datei).isFile()) {
      antwort.writeHead(404).end();
      return;
    }
    const geaendert = statSync(datei).mtime.toUTCString();
    const kopf = {
      'Content-Type': TYPEN[extname(datei)] ?? 'application/octet-stream',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cache-Control': extname(datei) === '.html' ? 'no-cache' : 'max-age=600',
      'Last-Modified': geaendert,
    };
    if (anfrage.headers['if-modified-since'] === geaendert) {
      antwort.writeHead(304, kopf).end();
      return;
    }
    antwort.writeHead(200, kopf).end(readFileSync(datei));
  });
  // WebSocket /ws an den WAMP-Router weiterreichen (wie Traefik), falls einer läuft.
  server.on('upgrade', (anfrage, socket, kopf) => {
    if (!wampPort) { socket.destroy(); return; }
    const router = connect(Number(wampPort), '127.0.0.1', () => {
      router.write(`${anfrage.method} ${anfrage.url} HTTP/${anfrage.httpVersion}\r\n`);
      for (let i = 0; i < anfrage.rawHeaders.length; i += 2) {
        router.write(`${anfrage.rawHeaders[i]}: ${anfrage.rawHeaders[i + 1]}\r\n`);
      }
      router.write('\r\n');
      router.write(kopf);
      socket.pipe(router).pipe(socket);
    });
    router.on('error', () => socket.destroy());
    socket.on('error', () => router.destroy());
  });
  return new Promise((fertig) => server.listen(0, '127.0.0.1', () => fertig(server)));
}

// ---------------------------------------------------------------- Chrome

function chromePfad() {
  const kandidaten = [
    process.env.CHROME_EXECUTABLE,
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium',
  ];
  const pfad = kandidaten.find((k) => k && existsSync(k));
  if (!pfad) throw new Error('Chrome nicht gefunden (CHROME_EXECUTABLE setzen)');
  return pfad;
}

// Zwei Browser-Umgebungen: mit WebGL (Software-Rendering) wählt Flutter den
// WebAssembly-Build mit Skwasm, ohne WebGL den JS-Build mit CanvasKit.
// (Linux-Chrome bietet trotz --disable-gpu WebGL über SwiftShader an, darum
// WebGL ausdrücklich abschalten.) Mit Software-WebGL meldet Chrome das erste
// Bild erst nach dem GPU-Start (> 2 s, teils nach fertig()); „sofort
// sichtbar“ wird deshalb nur ohne WebGL über first-contentful-paint geprüft.
const UMGEBUNGEN = [
  { name: 'WebAssembly', einstieg: 'main.dart.wasm', schalter: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] },
  { name: 'JavaScript ohne WebGL', einstieg: 'main.dart.js', schalter: ['--disable-gpu', '--disable-webgl', '--disable-3d-apis'], nur: ['kalter Start', 'Cache'], erstesBildMessbar: true },
];

async function starteChrome(schalter) {
  const profil = mkdtempSync(join(tmpdir(), 'ladebild-'));
  const prozess = spawn(chromePfad(), [
    '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profil}`,
    '--no-first-run', '--no-default-browser-check', ...schalter,
    // GitHub-Runner (Ubuntu 24.04) sperren die Namensräume der Chrome-Sandbox.
    ...(process.env.CI ? ['--no-sandbox'] : []),
  ], { stdio: ['ignore', 'ignore', 'pipe'] });
  const adresse = await new Promise((fertig, fehler) => {
    let puffer = '';
    prozess.stderr.on('data', (d) => {
      puffer += d;
      const treffer = puffer.match(/DevTools listening on (ws:\/\/\S+)/);
      if (treffer) fertig(treffer[1]);
    });
    prozess.on('exit', () => fehler(new Error(`Chrome beendet:\n${puffer}`)));
  });
  return { prozess, profil, adresse };
}

/** Schmaler Client für das DevTools-Protokoll (flache Sitzungen). */
class Protokoll {
  constructor(adresse) {
    this.socket = new WebSocket(adresse);
    this.nummer = 0;
    this.offen = new Map();
    this.hoerer = [];
    this.socket.onmessage = (e) => {
      const nachricht = JSON.parse(e.data);
      if (nachricht.id && this.offen.has(nachricht.id)) {
        const { fertig, fehler } = this.offen.get(nachricht.id);
        this.offen.delete(nachricht.id);
        if (nachricht.error) fehler(new Error(`${nachricht.error.message}`));
        else fertig(nachricht.result);
      } else if (nachricht.method) {
        this.hoerer.forEach((h) => h(nachricht));
      }
    };
  }

  bereit() {
    return new Promise((fertig, fehler) => {
      this.socket.onopen = fertig;
      this.socket.onerror = fehler;
    });
  }

  sende(methode, parameter = {}, sitzung) {
    const id = ++this.nummer;
    this.socket.send(JSON.stringify({ id, method: methode, params: parameter, sessionId: sitzung }));
    return new Promise((fertig, fehler) => this.offen.set(id, { fertig, fehler }));
  }

  auf(rueckruf) { this.hoerer.push(rueckruf); }
}

// ---------------------------------------------------------------- Seite

// Läuft vor jedem Dokument: hält alle Zwischenstände des Ladebilds fest,
// damit der Test auch die Werte sieht, die zwischen zwei Abfragen liegen.
const SONDE = `(() => {
  const sonde = window.__ladebild = { werte: [], prozente: [], ausblenden: false, entferntNach: null };
  new MutationObserver(() => {
    const balken = document.getElementById('ladebild-balken');
    const prozent = document.getElementById('ladebild-prozent');
    if (balken) {
      const wert = balken.getAttribute('aria-valuenow');
      if (wert !== null && sonde.werte[sonde.werte.length - 1] !== Number(wert)) sonde.werte.push(Number(wert));
    }
    if (prozent && prozent.textContent && sonde.prozente[sonde.prozente.length - 1] !== prozent.textContent) {
      sonde.prozente.push(prozent.textContent);
    }
    const wurzel = document.getElementById('ladebild');
    if (wurzel && wurzel.classList.contains('ausblenden')) sonde.ausblenden = true;
    if (!wurzel && document.body && sonde.entferntNach === null) sonde.entferntNach = performance.now();
  }).observe(document, { subtree: true, childList: true, attributes: true, characterData: true });
})();`;

class Seite {
  constructor(protokoll, sitzung, kontext) {
    this.p = protokoll;
    this.sitzung = sitzung;
    this.kontext = kontext;
    this.anfragen = [];
    this.fehlerMeldungen = [];
    this.gehalten = new Map(); // Teil der URL -> wartende requestIds
    this.halten = [];
    this.scheitern = [];
    this.ersetzen = {};
    this.abfangAktiv = false;
    protokoll.auf((n) => {
      if (n.sessionId !== sitzung) return;
      if (n.method === 'Network.requestWillBeSent') this.anfragen.push(n.params.request.url);
      if (n.method === 'Runtime.exceptionThrown') { const d = n.params.exceptionDetails; this.fehlerMeldungen.push(`${d.text} ${JSON.stringify(d.exception)} ${d.url ?? ''}:${d.lineNumber}`); };
      if (n.method === 'Runtime.consoleAPICalled' && n.params.type === 'error') {
        this.fehlerMeldungen.push(n.params.args.map((a) => a.value ?? a.description).join(' '));
      }
      // Nach Fetch.disable kann noch ein angehaltenes Ereignis eintreffen;
      // Chrome hat die Anfrage dann schon selbst fortgesetzt.
      if (n.method === 'Fetch.requestPaused') {
        this.#pausiert(n.params).catch((e) => {
          if (this.abfangAktiv) this.fehlerMeldungen.push(`Abfangen: ${e.message}`);
        });
      }
    });
  }

  static async oeffne(protokoll, { cache } = {}) {
    const { browserContextId } = cache ?? await protokoll.sende('Target.createBrowserContext');
    const { targetId } = await protokoll.sende('Target.createTarget', { url: 'about:blank', browserContextId });
    const { sessionId } = await protokoll.sende('Target.attachToTarget', { targetId, flatten: true });
    const seite = new Seite(protokoll, sessionId, { browserContextId, targetId });
    for (const domain of ['Page', 'Runtime', 'Network']) await seite.sende(`${domain}.enable`);
    await seite.sende('Page.addScriptToEvaluateOnNewDocument', { source: SONDE });
    // Im Hintergrund pausiert requestAnimationFrame – das Ladebild verschwindet
    // erst, wenn der Tab sichtbar ist. Deshalb jede Testseite nach vorn holen.
    await seite.sende('Page.bringToFront');
    return seite;
  }

  sende(methode, parameter) { return this.p.sende(methode, parameter, this.sitzung); }

  async schliessen({ kontextBehalten } = {}) {
    await this.p.sende('Target.closeTarget', { targetId: this.kontext.targetId });
    if (!kontextBehalten) {
      await this.p.sende('Target.disposeBrowserContext', { browserContextId: this.kontext.browserContextId });
    }
  }

  /** Anfragen, deren URL einen Teil enthält, anhalten, scheitern lassen oder ersetzen (Skript). */
  async abfangen({ halten = [], scheitern = [], ersetzen = {} }) {
    this.halten = halten;
    this.scheitern = scheitern;
    this.ersetzen = ersetzen;
    this.abfangAktiv = true;
    const muster = [...halten, ...scheitern, ...Object.keys(ersetzen)]
      .map((t) => ({ urlPattern: `*${t}*`, requestStage: 'Request' }));
    await this.sende('Fetch.enable', { patterns: muster });
  }

  async #pausiert({ requestId, request }) {
    const ersatz = Object.entries(this.ersetzen).find(([t]) => request.url.includes(t));
    if (ersatz) {
      await this.sende('Fetch.fulfillRequest', {
        requestId, responseCode: 200,
        responseHeaders: [{ name: 'Content-Type', value: 'text/javascript' }],
        body: Buffer.from(ersatz[1]).toString('base64'),
      });
      return;
    }
    if (this.scheitern.some((t) => request.url.includes(t))) {
      await this.sende('Fetch.failRequest', { requestId, errorReason: 'ConnectionRefused' });
      return;
    }
    const teil = this.halten.find((t) => request.url.includes(t));
    if (teil) {
      this.gehalten.set(teil, [...(this.gehalten.get(teil) ?? []), requestId]);
      return;
    }
    await this.sende('Fetch.continueRequest', { requestId });
  }

  async freigeben() {
    this.halten = [];
    this.scheitern = [];
    for (const ids of this.gehalten.values()) {
      for (const requestId of ids) await this.sende('Fetch.continueRequest', { requestId });
    }
    this.gehalten.clear();
    this.abfangAktiv = false;
    await this.sende('Fetch.disable');
  }

  async werte(ausdruck) {
    const { result, exceptionDetails } = await this.sende('Runtime.evaluate', {
      expression: ausdruck, returnByValue: true, awaitPromise: true,
    });
    if (exceptionDetails) throw new Error(`${ausdruck}: ${exceptionDetails.text}`);
    return result.value;
  }

  async warte(ausdruck, beschreibung, frist = 60000) {
    const ende = Date.now() + frist;
    while (Date.now() < ende) {
      if (await this.werte(ausdruck).catch(() => false)) return;
      await new Promise((r) => setTimeout(r, 100));
    }
    // Für die Fehlersuche: Zustand des Ladebilds und geladene Dateien.
    const stand = await this.werte(`JSON.stringify({ sichtbar: document.visibilityState,
      zustand: window.planerLadebildschirm
      && window.planerLadebildschirm.zustand(), dateien: performance.getEntriesByType('resource')
      .map((e) => e.name.replace(location.origin, '') + ' ' + e.initiatorType + ' ' + e.decodedBodySize) })`)
      .catch((e) => e.message);
    throw new Error(`Zeitüberschreitung: ${beschreibung}\n        ${stand}`);
  }

  oeffneUrl(url) { return this.sende('Page.navigate', { url }); }

  /** Wartet, bis Flutter gezeichnet und das Ladebild entfernt hat. */
  warteAufApp() {
    return this.warte('window.__ladebild.entferntNach !== null', 'Ladebild wird entfernt');
  }

  zustand() { return this.werte('window.planerLadebildschirm && window.planerLadebildschirm.zustand()'); }
  sonde() { return this.werte('window.__ladebild'); }
  text(id) { return this.werte(`(document.getElementById('${id}') || {}).textContent`); }
}

// ---------------------------------------------------------------- Prüfungen

function pruefe(bedingung, meldung) {
  if (!bedingung) throw new Error(meldung);
}

function pruefeVerlauf(sonde, adresse, anfragen) {
  pruefe(sonde.werte.length >= 2, `zu wenige Zwischenstände: ${JSON.stringify(sonde.werte)}`);
  sonde.werte.forEach((w, i) => pruefe(i === 0 || w >= sonde.werte[i - 1], `nicht monoton: ${sonde.werte}`));
  pruefe(sonde.werte.at(-1) === 99, `vor dem ersten Bild nicht bei 99 %: ${sonde.werte}`);
  pruefe(sonde.prozente.at(-1) === '100 %', `endet nicht bei 100 %: ${sonde.prozente}`);
  const fremd = anfragen.filter((u) => !u.startsWith(adresse) && !/^(data|blob):/.test(u));
  pruefe(fremd.length === 0, `Anfragen an fremde Server: ${fremd.join(', ')}`);
}

async function pruefeStart(seite, adresse) {
  await seite.warteAufApp();
  pruefeVerlauf(await seite.sonde(), adresse, seite.anfragen);
  pruefe(seite.fehlerMeldungen.length === 0, `Konsolenfehler: ${seite.fehlerMeldungen.join(' | ')}`);
  pruefe(await seite.werte('window.fetch.toString().includes("[native code]")'), 'fetch nicht wiederhergestellt');
}

const FAELLE = {
  async 'kalter Start: sofort sichtbar, echter Plan, monoton bis 100 %'(p, adresse, umgebung) {
    const seite = await Seite.oeffne(p);
    await seite.oeffneUrl(adresse);
    await seite.warte("document.getElementById('ladebild')", 'Ladebild im ersten HTML');
    pruefe(await seite.werte(`(() => { const s = getComputedStyle(document.getElementById('ladebild'));
      return s.display !== 'none' && s.visibility !== 'hidden' && s.opacity !== '0'; })()`), 'Ladebild per CSS verborgen');
    await seite.warte('window.planerLadebildschirm.zustand().plan', 'Plan der Startdateien erkannt');
    const zustand = await seite.zustand();
    pruefe(zustand.verlaesslich, `Größen passen nicht: ${JSON.stringify(zustand)}`);
    pruefe(zustand.plan.includes(umgebung.einstieg), `${umgebung.einstieg} nicht im Plan: ${zustand.plan}`);
    await pruefeStart(seite, adresse);
    // Das Ladebild steht im ersten HTML (ohne Skript); es muss gemalt sein,
    // bevor es entfernt wird – messbar nur ohne Software-WebGL (s. o.).
    const zeiten = await seite.werte(`({
      fcp: (performance.getEntriesByName('first-contentful-paint')[0] || {}).startTime,
      bild: performance.getEntriesByName('planer-erstes-bild')[0].startTime,
      entfernt: window.__ladebild.entferntNach })`);
    if (umgebung.erstesBildMessbar) pruefe(zeiten.fcp < zeiten.entfernt, `Ladebild nie sichtbar: ${JSON.stringify(zeiten)}`);
    await seite.schliessen();
    return `Plan ${zustand.plan.join(', ')}; Ladebild nach ${zeiten.fcp.toFixed(0)} ms, App nach ${zeiten.bild.toFixed(0)} ms`;
  },

  async 'Start aus dem Browser-Cache: monoton bis 100 %'(p, adresse) {
    const erste = await Seite.oeffne(p);
    await erste.oeffneUrl(adresse);
    await erste.warteAufApp();
    await erste.schliessen({ kontextBehalten: true });
    const seite = await Seite.oeffne(p, { cache: erste.kontext });
    await seite.oeffneUrl(adresse);
    await pruefeStart(seite, adresse);
    const sonde = await seite.sonde();
    await seite.schliessen();
    return `Zwischenstände ${sonde.werte.join(' → ')}`;
  },

  async 'barrierefrei: Ansage, Fortschrittswerte, Bewegung reduzieren'(p, adresse) {
    const seite = await Seite.oeffne(p);
    await seite.sende('Emulation.setEmulatedMedia', {
      features: [{ name: 'prefers-reduced-motion', value: 'reduce' }],
    });
    await seite.abfangen({ halten: ['main.dart.wasm'] });
    await seite.oeffneUrl(adresse);
    await seite.warte("document.getElementById('ladebild-balken').hasAttribute('aria-valuenow')", 'aria-valuenow gesetzt');
    const aria = await seite.werte(`(() => {
      const w = document.getElementById('ladebild'), b = document.getElementById('ladebild-balken');
      return { rolle: w.getAttribute('role'), live: w.getAttribute('aria-live'), balken: b.getAttribute('role'),
        name: b.getAttribute('aria-label'), min: b.getAttribute('aria-valuemin'), max: b.getAttribute('aria-valuemax'),
        logo: document.querySelector('.ladebild-logo').alt };
    })()`);
    pruefe(aria.rolle === 'status' && aria.live === 'polite', `keine Ansage für Screenreader: ${JSON.stringify(aria)}`);
    pruefe(aria.balken === 'progressbar' && aria.name && aria.min === '0' && aria.max === '100',
      `Fortschrittsbalken unvollständig: ${JSON.stringify(aria)}`);
    pruefe(aria.logo, 'Logo ohne Alternativtext');
    await seite.freigeben();
    await seite.warteAufApp();
    const sonde = await seite.sonde();
    pruefe(!sonde.ausblenden, 'trotz „Bewegung reduzieren“ ausgeblendet statt sofort entfernt');
    await seite.schliessen();
    return 'role=status/aria-live, progressbar 0–100, sofort entfernt';
  },

  async 'langsame Verbindung: Hinweis nach 10 s, danach Start'(p, adresse) {
    const seite = await Seite.oeffne(p);
    await seite.abfangen({ halten: ['main.dart.wasm'] });
    await seite.oeffneUrl(adresse);
    await seite.warte(`document.getElementById('ladebild-status').textContent === ${JSON.stringify(TEXT.langsam)}`,
      'Hinweis „langsam“', 15000);
    await seite.freigeben();
    await pruefeStart(seite, adresse);
    await seite.schliessen();
    return 'Hinweis erschienen, App gestartet';
  },

  async 'offline: Hinweis, wieder online, Start'(p, adresse) {
    const seite = await Seite.oeffne(p);
    await seite.abfangen({ halten: ['main.dart.wasm'] });
    await seite.oeffneUrl(adresse);
    await seite.warte("document.getElementById('ladebild-status').textContent", 'Status sichtbar');
    const netz = (offline) => seite.sende('Network.emulateNetworkConditions', {
      offline, latency: 0, downloadThroughput: -1, uploadThroughput: -1,
    });
    await netz(true);
    await seite.warte(`document.getElementById('ladebild-status').textContent === ${JSON.stringify(TEXT.offline)}`,
      'Hinweis „offline“', 5000);
    await netz(false);
    await seite.warte(`document.getElementById('ladebild-status').textContent !== ${JSON.stringify(TEXT.offline)}`,
      'Hinweis „offline“ verschwindet', 5000);
    await seite.freigeben();
    await pruefeStart(seite, adresse);
    await seite.schliessen();
    return 'Hinweis erschienen und verschwunden, App gestartet';
  },

  async 'Fehler beim Laden: „Start nicht möglich“, Erneut versuchen startet'(p, adresse) {
    const seite = await Seite.oeffne(p);
    await seite.abfangen({ scheitern: ['main.dart.wasm'] });
    await seite.oeffneUrl(adresse);
    await seite.warte("document.getElementById('ladebild').classList.contains('fehler')", 'Fehlerzustand', 20000);
    pruefe(await seite.text('ladebild-titel') === TEXT.fehlerTitel, 'Titel „Start nicht möglich“ fehlt');
    pruefe(await seite.text('ladebild-prozent') === '', 'Prozentzahl im Fehlerzustand');
    pruefe(!await seite.werte("document.getElementById('ladebild-erneut').hidden"), 'Knopf „Erneut versuchen“ fehlt');
    await seite.freigeben();
    seite.fehlerMeldungen = [];
    seite.anfragen = [];
    await seite.werte("document.getElementById('ladebild-erneut').click()");
    await new Promise((r) => setTimeout(r, 500));
    await pruefeStart(seite, adresse);
    await seite.schliessen();
    return 'Fehlerzustand mit Knopf, Neustart erfolgreich';
  },
};

// ---------------------------------------------------------------- Benchmark

// Vergleich ohne Zählen: dieselben Aufrufe wie fortschritt.js, aber ohne
// fetch-Hülle, Ressourcen-Zeiten und Anzeige.
const HUELLE = `window.planerLadebildschirm = { konfiguriere() {}, phase() {}, fehler() {},
  zustand() { return {}; },
  fertig() { performance.mark('planer-erstes-bild'); document.getElementById('ladebild').remove(); } };`;

/**
 * Ein Start in einem frischen Browser-Kontext (ohne HTTP-Cache) mit CPU-Profil:
 * Zeit bis zum ersten Bild und Rechenzeit in fortschritt.js. Mit [ohneLadebild]
 * ersetzt eine leere Hülle das Skript – der Unterschied ist der Mehraufwand.
 */
async function messeStart(p, adresse, { ohneLadebild = false } = {}) {
  const seite = await Seite.oeffne(p);
  if (ohneLadebild) await seite.abfangen({ ersetzen: { 'ladebild/fortschritt.js': HUELLE } });
  await seite.sende('Profiler.enable');
  await seite.sende('Profiler.setSamplingInterval', { interval: 50 });
  await seite.sende('Profiler.start');
  await seite.oeffneUrl(adresse);
  await seite.warteAufApp();
  const { profile } = await seite.sende('Profiler.stop');
  const bild = await seite.werte("performance.getEntriesByName('planer-erstes-bild')[0].startTime");
  const knoten = new Map(profile.nodes.map((k) => [k.id, k]));
  let skriptUs = 0;
  profile.samples.forEach((id, i) => {
    if (knoten.get(id).callFrame.url.endsWith('ladebild/fortschritt.js')) skriptUs += profile.timeDeltas[i + 1] ?? 0;
  });
  await seite.schliessen();
  return { bildUs: bild * 1000, skriptUs };
}

function median(werte) {
  const s = [...werte].sort((a, b) => a - b);
  return s[Math.floor(s.length / 2)];
}

// ---------------------------------------------------------------- Ablauf

const server = await starteServer();
const adresse = `http://127.0.0.1:${server.address().port}/`;
let fehlgeschlagen = 0;

/** Startet Chrome mit den Schaltern der Umgebung und führt [arbeit] aus. */
async function mitChrome(umgebung, arbeit) {
  const chrome = await starteChrome(umgebung.schalter);
  const protokoll = new Protokoll(chrome.adresse);
  await protokoll.bereit();
  try {
    await arbeit(protokoll);
  } finally {
    protokoll.socket.close();
    const beendet = new Promise((r) => chrome.prozess.once('exit', r));
    chrome.prozess.kill();
    await beendet;
    rmSync(chrome.profil, { recursive: true, force: true });
  }
}

try {
  if (benchmark) {
    await mitChrome(UMGEBUNGEN[0], async (protokoll) => {
      await messeStart(protokoll, adresse); // Aufwärmen
      const mit = [];
      const ohne = [];
      for (let i = 0; i < durchlaeufe; i++) {
        mit.push(await messeStart(protokoll, adresse));
        ohne.push(await messeStart(protokoll, adresse, { ohneLadebild: true }));
      }
      const zeile = (name, us) => console.log(`app.Ladebild.${name}(RunTime): ${us.toFixed(1)} us.`);
      zeile('ErstesBild', median(mit.map((m) => m.bildUs)));
      zeile('ErstesBildOhneZaehlen', median(ohne.map((m) => m.bildUs)));
      // CPU-Zeit in fortschritt.js, einschließlich des Weiterreichens der Downloads.
      zeile('Skriptzeit', median(mit.map((m) => m.skriptUs)));
    });
  } else {
    for (const umgebung of UMGEBUNGEN) {
      console.log(`== ${umgebung.name}`);
      await mitChrome(umgebung, async (protokoll) => {
        for (const [name, fall] of Object.entries(FAELLE)) {
          if (umgebung.nur && !umgebung.nur.some((n) => name.includes(n))) continue;
          if (process.env.LADEBILD_FALL && !name.includes(process.env.LADEBILD_FALL)) continue;
          try {
            console.log(`ok      ${name} – ${await fall(protokoll, adresse, umgebung)}`);
          } catch (fehler) {
            fehlgeschlagen++;
            console.log(`FEHLER  ${name} – ${fehler.message}`);
          }
        }
      });
    }
  }
} finally {
  server.close();
}
process.exit(fehlgeschlagen ? 1 : 0);
