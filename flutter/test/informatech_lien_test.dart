import 'package:flutter_hbb/common/informatech_lien.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // S-078 (Argos P3, Scylla 17/11): the same cases as the engine's test
  // informatech_s078_no_password_in_a_command_line_link (src/common.rs). Keep the two lists in step.
  test('a link naming a password is told from one that does not', () {
    for (final refuse in [
      'informatech://connect/123456789?password=secret',
      'InformaTech://connect/123456789?relay=true&PASSWORD=secret',
      'informatech://123456789?key=abc;password=secret',
      'informatech://connect/123456789?p%61ssword=secret',
      'informatech://connect/123456789?%50assword=secret#x',
      'informatech://connect/123456789?password',
      ' informatech://connect/123456789?password=secret ',
      'informatech://password/secret',
      'informatech://PASS%57ORD/secret',
      'informatech://connect/123456789?PassWord=x',
      'informatech://connect/123456789?%50assword=x',
      'informatech://connect/123456789?pass%77ord=x',
      'informatech://connect/123456789?%2570assword=x',
      'informatech://connect/123456789?%252570assword=x',
      'informatech://connect/123456789?a=1;password=x',
      'informatech://connect/123456789#password=x',
      'informatech://connect/123456789?a=1#b=2&password=x',
      'informatech://connect/123456789?a=1?password=x',
      'INFORMATECH://CONNECT/123456789?PASSWORD=X',
      'informatech:\\\\password\\secret',
      'informatech:\\\\connect\\123456789?password=x',
      'informatech:/password/secret',
      'informatech:password/secret',
      'informatech:////password/secret',
      'informatech://connect/123456789?pass\tword=x',
      'infor\tmatech://connect/123456789?password=x',
      'informatech://connect/123456789?\r\npassword=x',
      'informatech://connect/123456789? password =x',
      'informatech://connect/123456789?+password+=x',
      'informatech://connect/123456789?%20password=x',
      'informatech://%20password%20/secret',
      // Nine encodings deep: nothing reads that, refused all the same.
      'informatech://connect/1?%25252525252525252570assword=x',
      // Any scheme is read here (the engine reads only ours).
      'autre://connect/1?password=secret',
    ]) {
      expect(lienAvecMotDePasse(refuse), isTrue, reason: refuse);
    }
    for (final accepte in [
      'informatech://connect/123456789',
      'informatech://connect/123456789?relay=true&key=abc',
      'informatech://connect/123456789?motdepasse=x&passwordx=y&xpassword=z',
      'informatech://connect/123456789?pass word=x',
      'informatech://connect/123456789#relay',
      'informatech://connect/password',
      'informatech://connect/123456789?key=password',
      'informatech://',
      'informatech:',
      // Not a link.
      '--password',
      'password=secret',
      'é',
      '',
    ]) {
      expect(lienAvecMotDePasse(accepte), isFalse, reason: accepte);
    }
  });
}
