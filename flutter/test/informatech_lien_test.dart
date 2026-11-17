import 'package:flutter_hbb/common/informatech_lien.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // S-078 (Argos P3): the same cases as the engine's test informatech_s078_no_password_in_a_command_line_link.
  test('a link with a password is told from one without', () {
    for (final refuse in [
      'informatech://connect/123456789?password=secret',
      'InformaTech://connect/123456789?relay=true&PASSWORD=secret',
      'informatech://connect/123456789?p%61ssword=secret',
      'informatech://connect/123456789?%50assword=secret#x',
      'informatech://connect/123456789?password',
      ' informatech://connect/123456789?password=secret ',
      'informatech://password/secret',
    ]) {
      expect(lienAvecMotDePasse(refuse), isTrue, reason: refuse);
    }
    for (final accepte in [
      'informatech://connect/123456789',
      'informatech://connect/123456789?relay=true&key=abc',
      'informatech://connect/123456789?motdepasse=x&passwordx=y&xpassword=z',
      'informatech://connect/123456789#password=x',
      'informatech://',
      '',
    ]) {
      expect(lienAvecMotDePasse(accepte), isFalse, reason: accepte);
    }
  });
}
