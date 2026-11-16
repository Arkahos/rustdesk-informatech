import 'package:flutter_hbb/mobile/informatech_marges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('portrait: top bar and bottom tools; landscape: top bar and a right rail; tablet: wider rail', () {
    InformatechMarges.retirer();
    expect(InformatechMarges.poser(412, 900), isTrue);
    expect((InformatechMarges.haut, InformatechMarges.bas, InformatechMarges.droite), (52.0, 64.0, 0.0));
    expect(InformatechMarges.poser(412, 900), isFalse);
    expect(InformatechMarges.poser(900, 412), isTrue);
    expect((InformatechMarges.haut, InformatechMarges.bas, InformatechMarges.droite), (52.0, 0.0, 72.0));
    expect(InformatechMarges.poser(1280, 800), isTrue);
    expect(InformatechMarges.droite, 88.0);
    InformatechMarges.retirer();
    expect((InformatechMarges.haut, InformatechMarges.bas, InformatechMarges.droite), (0.0, 0.0, 0.0));
  });
}
