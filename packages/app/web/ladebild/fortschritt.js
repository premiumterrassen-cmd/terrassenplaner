// Ladebildschirm des Terrassenplaners (M3-08): echter Fortschritt in Prozent.
//
// Verfahren: Beim Build schreibt tool/startgroessen.py die Größe jeder
// Startdatei in #startgroessen. Dieses Skript zählt die tatsächlich geladenen
// Bytes (Downloads per fetch werden beim Durchreichen mitgezählt, ohne sie zu
// puffern; Skripte und Dateien aus dem Browser-Cache über die Ressourcen-Zeiten)
// und teilt sie durch die Summe der Dateien, die der gewählte Build braucht.
// Passt etwas nicht zusammen, zeigt der Balken nur „unbestimmt“ statt einer
// falschen Zahl. Flutter selbst ruft fertig() nach dem ersten Bild (über
// flutter_bootstrap.js).
(function () {
  'use strict';

  var TEXTE = {
    de: {
      laden: 'Planungsdaten werden geladen …',
      initialisieren: 'Darstellung wird vorbereitet …',
      starten: 'Ihr Terrassenplaner wird geöffnet …',
      langsam: 'Das Laden dauert länger. Bitte prüfen Sie Ihre Verbindung.',
      offline: 'Sie sind offline. Bitte prüfen Sie Ihre Verbindung.',
      fehlerTitel: 'Start nicht möglich',
      fehler: 'Der Terrassenplaner konnte nicht gestartet werden. Bitte versuchen Sie es erneut.'
    }
  };
  var sprache = (navigator.language || 'de').slice(0, 2).toLowerCase();
  var t = TEXTE[sprache] || TEXTE.de;

  var groessen = {};
  try {
    var meta = JSON.parse(document.getElementById('startgroessen').textContent || '{}');
    if (meta && meta.version === 1 && meta.dateien) groessen = meta.dateien;
  } catch (e) { /* ohne Größen: unbestimmter Balken */ }

  var basis = new URL(document.baseURI);
  var geladen = {};          // Pfad -> Bytes
  var plan = null;           // Pfade, die der gewählte Build braucht
  var builds = [];
  var verlaesslich = Object.keys(groessen).length > 0;
  var phase = 'laden';
  var letzterFortschritt = Date.now();
  var beendet = false;
  var anzeigeProzent = 0;

  var el = function (id) { return document.getElementById(id); };

  function pfad(url) {
    try {
      var u = new URL(url, basis);
      if (u.origin !== basis.origin || u.pathname.indexOf(basis.pathname) !== 0) return null;
      var p = decodeURIComponent(u.pathname.slice(basis.pathname.length));
      return Object.prototype.hasOwnProperty.call(groessen, p) ? p : null;
    } catch (e) { return null; }
  }

  function erfasse(p, bytes, vollstaendig) {
    if (!p || beendet) return;
    if ((geladen[p] || 0) < bytes) { geladen[p] = bytes; letzterFortschritt = Date.now(); }
    if (vollstaendig && bytes !== groessen[p]) verlaesslich = false;
    waehlePlan(p);
    zeichne();
  }

  // Sobald der Renderer feststeht (skwasm oder canvaskit), ist klar, welche
  // Dateien der Start braucht: Einstieg des passenden Builds + Renderer.
  function waehlePlan(p) {
    if (plan || !builds.length || p.indexOf('canvaskit/') !== 0) return;
    var stamm = p.split('/').pop().replace(/\.(js|wasm)$/, '');
    var renderer = stamm === 'canvaskit' ? 'canvaskit' : (stamm.indexOf('skwasm') === 0 ? 'skwasm' : null);
    var build = builds.filter(function (b) { return b.renderer === renderer; })[0];
    if (!build) return;
    var einstieg = build.compileTarget === 'dart2wasm' ? ['main.dart.wasm', 'main.dart.mjs'] : ['main.dart.js'];
    var wasm = p.replace(/\.js$/, '.wasm');
    var liste = einstieg.concat([wasm, wasm.replace(/\.wasm$/, '.js')]);
    if (liste.some(function (d) { return !(groessen[d] > 0); })) { verlaesslich = false; return; }
    plan = liste;
  }

  function prozent() {
    if (!plan || !verlaesslich) return null;
    var summe = 0, ist = 0;
    plan.forEach(function (d) { summe += groessen[d]; ist += Math.min(geladen[d] || 0, groessen[d]); });
    return summe ? Math.floor(ist / summe * 100) : null;
  }

  function zeichne() {
    if (beendet && phase !== 'fehler') return;
    var balken = el('ladebild-balken');
    var p = prozent();
    if (p === null) {
      balken.classList.add('unbestimmt');
      balken.removeAttribute('aria-valuenow');
      el('ladebild-prozent').textContent = '';
    } else {
      // monoton steigend, 100 % erst wenn Flutter wirklich zeichnet
      anzeigeProzent = Math.max(anzeigeProzent, Math.min(p, 99));
      balken.classList.remove('unbestimmt');
      balken.setAttribute('aria-valuenow', String(anzeigeProzent));
      el('ladebild-fuellung').style.width = anzeigeProzent + '%';
      el('ladebild-prozent').textContent = anzeigeProzent + ' %';
    }
    var langsam = Date.now() - letzterFortschritt > 10000;
    el('ladebild-status').textContent =
      !navigator.onLine ? t.offline : (langsam && phase === 'laden' ? t.langsam : t[phase]);
  }

  // fetch durchreichen und Bytes mitzählen – ohne Puffern, damit
  // WebAssembly weiter streamend kompiliert werden kann.
  var originalFetch = window.fetch;
  function gezaehltesFetch(eingabe, optionen) {
    var url = typeof eingabe === 'string' || eingabe instanceof URL ? eingabe : eingabe && eingabe.url;
    var p = pfad(url);
    if (beendet || !p) return originalFetch.apply(this, arguments);
    return originalFetch.apply(this, arguments).then(function (antwort) {
      if (!antwort.ok || !antwort.body || typeof ReadableStream === 'undefined') return antwort;
      var leser = antwort.body.getReader();
      var bytes = 0;
      var koerper = new ReadableStream({
        pull: function (ziel) {
          return leser.read().then(function (stueck) {
            if (stueck.done) { erfasse(p, bytes, true); ziel.close(); return; }
            bytes += stueck.value.byteLength;
            erfasse(p, bytes, false);
            ziel.enqueue(stueck.value);
          }, function (fehler) { ziel.error(fehler); });
        },
        cancel: function (grund) { return leser.cancel(grund); }
      });
      var neu = new Response(koerper, { status: antwort.status, statusText: antwort.statusText, headers: antwort.headers });
      ['url', 'type', 'redirected'].forEach(function (k) { Object.defineProperty(neu, k, { value: antwort[k] }); });
      return neu;
    });
  }
  window.fetch = gezaehltesFetch;

  // Skripte (script/import) und Cache-Treffer über die Ressourcen-Zeiten.
  function beobachte(eintraege) {
    eintraege.forEach(function (e) {
      if (e.initiatorType === 'fetch') return;
      var p = pfad(e.name);
      if (p && e.responseEnd > 0) erfasse(p, e.decodedBodySize || groessen[p], true);
    });
  }
  var beobachter = null;
  if (typeof PerformanceObserver !== 'undefined') {
    try {
      beobachter = new PerformanceObserver(function (liste) { beobachte(liste.getEntries()); });
      beobachter.observe({ type: 'resource', buffered: true });
    } catch (e) { beobachter = null; }
  }

  var takt = setInterval(zeichne, 1000);
  window.addEventListener('online', zeichne);
  window.addEventListener('offline', zeichne);
  window.addEventListener('error', function (e) {
    if (!beendet && e.target && e.target.tagName === 'SCRIPT') ladebild.fehler(e);
  }, true);

  function aufraeumen() {
    beendet = true;
    clearInterval(takt);
    if (beobachter) beobachter.disconnect();
    if (window.fetch === gezaehltesFetch) window.fetch = originalFetch;
  }

  var ladebild = {
    // Für Tests und Fehlersuche: aktueller Zustand der Fortschrittsberechnung.
    zustand: function () {
      return { phase: phase, plan: plan, verlaesslich: verlaesslich, geladen: geladen, prozent: prozent(), beendet: beendet };
    },
    konfiguriere: function (buildConfig) {
      builds = (buildConfig && buildConfig.builds) || [];
      beobachte(performance.getEntriesByType ? performance.getEntriesByType('resource') : []);
      Object.keys(geladen).forEach(waehlePlan);
      zeichne();
    },
    phase: function (neu) { phase = neu; letzterFortschritt = Date.now(); zeichne(); },
    fertig: function () {
      if (beendet) return;
      aufraeumen();
      var wurzel = el('ladebild');
      el('ladebild-fuellung').style.width = '100%';
      el('ladebild-prozent').textContent = prozent() === null ? '' : '100 %';
      wurzel.setAttribute('aria-hidden', 'true');
      var entferne = function () { if (wurzel.parentNode) wurzel.parentNode.removeChild(wurzel); };
      var ruhig = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      // zwei Bilder abwarten, damit Flutter sicher sichtbar ist
      requestAnimationFrame(function () {
        requestAnimationFrame(function () {
          if (ruhig) { entferne(); return; }
          wurzel.classList.add('ausblenden');
          setTimeout(entferne, 220);
        });
      });
    },
    fehler: function (ursache) {
      if (beendet) return;
      aufraeumen();
      phase = 'fehler';
      if (window.console) console.error('Start des Terrassenplaners fehlgeschlagen', ursache);
      el('ladebild').classList.add('fehler');
      el('ladebild-titel').textContent = t.fehlerTitel;
      el('ladebild-prozent').textContent = '';
      el('ladebild-status').textContent = t.fehler;
      var knopf = el('ladebild-erneut');
      knopf.hidden = false;
      knopf.onclick = function () { location.reload(); };
    }
  };
  window.planerLadebildschirm = ladebild;
  zeichne();
})();
