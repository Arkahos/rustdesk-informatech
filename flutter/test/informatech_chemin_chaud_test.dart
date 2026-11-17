import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/informatech_lien.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Scylla R1, Argos 18/11: the warm path end to end on the parser side. Our engine hands the running window
  // informatech://connect/<id>?password=… (password percent-encoded from its stdin read); the real urlLinkToCmdArgs
  // turns it into arguments, and handleUriLink's `--password` case (informatechMotDePasseDesArguments, depuisLien
  // set by its link branches) must hand the session the exact password. The same arguments from the command line
  // are refused.
  test('a forwarded password link reaches the session with its exact password', () {
    const motDePasse = 'aB3 +&=?#%/é';
    final lien = Uri.parse('informatech://connect/123456789?password=${Uri.encodeQueryComponent(motDePasse)}');
    final args = urlLinkToCmdArgs(lien)!;
    expect(args, ['--connect', '123456789', '--password', motDePasse]);
    final i = args.indexOf('--password');
    expect(informatechMotDePasseDesArguments(args, i, depuisLien: true), motDePasse);
    expect(informatechMotDePasseDesArguments(args, i, depuisLien: false), isNull);
    // With the relay option, the password is still the value right after `--password`.
    final relais = urlLinkToCmdArgs(Uri.parse('informatech://connect/123456789?password=x1&relay=1'))!;
    expect(relais, ['--connect', '123456789', '--password', 'x1', '--relay']);
    expect(informatechMotDePasseDesArguments(relais, relais.indexOf('--password'), depuisLien: true), 'x1');
  });
}
