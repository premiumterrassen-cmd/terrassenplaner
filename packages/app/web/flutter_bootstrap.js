{{flutter_js}}
{{flutter_build_config}}

// Start der App mit Rückmeldung an den Ladebildschirm (web/ladebild/fortschritt.js).
(function () {
  var ladebild = window.planerLadebildschirm;
  ladebild.konfiguriere(_flutter.buildConfig);
  _flutter.loader.load({
    // Renderer (CanvasKit/Skwasm) vom eigenen Server statt von gstatic.com:
    // keine Anfragen an Google beim Start und messbarer Ladefortschritt.
    config: { canvasKitBaseUrl: 'canvaskit/' },
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        ladebild.phase('initialisieren');
        var appRunner = await engineInitializer.initializeEngine();
        ladebild.phase('starten');
        await appRunner.runApp();
        ladebild.fertig();
      } catch (fehler) {
        ladebild.fehler(fehler);
      }
    }
  }).catch(function (fehler) { ladebild.fehler(fehler); });
})();
