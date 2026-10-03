import 'package:connectanum_router/auth.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

void main() {
  test('ohne Mitarbeiter-Verzeichnis gibt es keine Zugänge', () async {
    final auth = await AuthServerProzess.starte(await testAuthEinstellungen());
    addTearDown(auth.stoppe);
    expect(
      await AuthCredentialRegistry.loadScram(
        realmUri: RouterEinstellungen.standardRealm,
        authId: 'anna',
      ),
      isNull,
    );
  });
}
