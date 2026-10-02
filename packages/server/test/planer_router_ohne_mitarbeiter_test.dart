import 'package:connectanum_router/auth.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

void main() {
  test(
    'ohne Mitarbeiter-Verzeichnis gibt es keine Mitarbeiter-Zugänge',
    () async {
      final router = await PlanerRouter.starte(await testEinstellungen());
      addTearDown(router.stoppe);
      expect(
        await AuthCredentialRegistry.loadScram(
          realmUri: RouterEinstellungen.standardRealm,
          authId: 'anna',
        ),
        isNull,
      );
    },
  );
}
