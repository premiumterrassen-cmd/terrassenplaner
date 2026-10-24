import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  test('verschachtelte Maps werden zu JSON-Objekten', () {
    final roh = <Object?, Object?>{
      'a': [
        1,
        <Object?, Object?>{'b': null, 'c': 'ü'},
      ],
      'd': 3.5,
    };
    final json = alsJsonObjekt(roh);
    expect(json, isA<Map<String, Object?>>());
    expect(json['a'], isA<List<Object?>>());
    expect((json['a']! as List)[1], isA<Map<String, Object?>>());
    expect(json, {
      'a': [
        1,
        {'b': null, 'c': 'ü'},
      ],
      'd': 3.5,
    });
    expect(alsJsonWert('x'), 'x');
    expect(alsJsonWert(null), isNull);
  });

  test('nur Texte als Schlüssel', () {
    expect(
      () => alsJsonObjekt(<Object?, Object?>{1: 2}),
      throwsA(isA<TypeError>()),
    );
    expect(() => alsJsonObjekt([1]), throwsA(isA<TypeError>()));
  });
}
