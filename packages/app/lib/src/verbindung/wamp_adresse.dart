/// Adresse des WAMP-Routers für die Web-App.
///
/// Standard: derselbe Host wie die Seite, Pfad `/ws` (über Traefik),
/// `wss` bei HTTPS. Mit [vorgabe] (z. B. `--dart-define=PLANER_WAMP_URL=…`)
/// lässt sich eine andere Adresse setzen – für Smoke-Tests und Entwicklung.
Uri wampAdresse(Uri seite, {String vorgabe = ''}) {
  if (vorgabe.isNotEmpty) return Uri.parse(vorgabe);
  return Uri(
    scheme: seite.scheme == 'https' ? 'wss' : 'ws',
    host: seite.host,
    port: seite.hasPort ? seite.port : null,
    path: '/ws',
  );
}
