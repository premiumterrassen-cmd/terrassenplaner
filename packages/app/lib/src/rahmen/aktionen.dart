import 'package:url_launcher/url_launcher.dart';

/// Öffnet eine Adresse in einem neuen Browser-Tab; in Tests austauschbar.
typedef LinkOeffner = Future<void> Function(Uri adresse);

/// Feste Ziele im Planer (M3-06, Vorgabe Alexander 26.10.2026): Rechtliches
/// und Video-Beratung im Shop. Eine Montageanleitung gibt es noch nicht.
abstract final class PlanerLinks {
  static final agb = Uri.parse(
    'https://shop.robinienwelt.de/policies/terms-of-service',
  );
  static final datenschutz = Uri.parse(
    'https://shop.robinienwelt.de/policies/privacy-policy',
  );
  static final impressum = Uri.parse(
    'https://shop.robinienwelt.de/policies/legal-notice',
  );
  static final videoberatung = Uri.parse(
    'https://shop.robinienwelt.de/products/online-videoberatung-buchen',
  );
}

/// Was die Knöpfe des Rahmens auslösen. Angebot anfordern und PDF kommen mit
/// M9; bis dahin sind sie `null`.
class RahmenAktionen {
  const RahmenAktionen({
    this.oeffne = oeffneImBrowser,
    this.anfordern,
    this.pdf,
  });

  final LinkOeffner oeffne;
  final Future<void> Function()? anfordern;
  final Future<void> Function()? pdf;
}

/// Öffnet [adresse] in einem neuen Tab (`url_launcher`).
Future<void> oeffneImBrowser(Uri adresse) async {
  await launchUrl(adresse, webOnlyWindowName: '_blank');
}
