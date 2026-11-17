import 'package:flutter_hbb/mobile/informatech_marges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('portrait: top bar and bottom tools; landscape: top bar and a right rail; tablet: wider rail', () {
    InformatechMarges.retirer();
    expect(InformatechMarges.poser(412, 900), isTrue);
    expect((InformatechMarges.haut, InformatechMarges.bas, InformatechMarges.droite), (52.0, 64.0, 0.0));
    expect(InformatechMarges.poser(412, 900), isFalse);
    // A phone in landscape is wider than 840 dp (S24+ about 914 x 412) and still gets the phone rail.
    expect(InformatechMarges.poser(914, 412), isTrue);
    expect((InformatechMarges.haut, InformatechMarges.bas, InformatechMarges.droite), (52.0, 0.0, 72.0));
    expect(InformatechMarges.poser(1280, 800), isTrue);
    expect(InformatechMarges.droite, 88.0);
    // A tablet in portrait keeps the bottom bar.
    expect(InformatechMarges.poser(800, 1280), isTrue);
    expect((InformatechMarges.bas, InformatechMarges.droite), (64.0, 0.0));
    InformatechMarges.retirer();
    expect((InformatechMarges.haut, InformatechMarges.bas, InformatechMarges.droite), (0.0, 0.0, 0.0));
  });

  // Argos 17/11 (P3): with the soft keyboard up the image lost the top bar twice and the hidden bottom bar once.
  test('image height: the top bar counts once, the bottom bar hides behind the keyboard', () {
    double h({required double ecran, double inset = 0, double clavier = 0, double outils = 0}) =>
        InformatechMarges.hauteurImage(ecran: ecran, insetHaut: inset, clavier: clavier, outilsClavier: outils);
    InformatechMarges.poser(412, 900);
    // Portrait, keyboard down: screen - top inset - 52 - 64.
    expect(h(ecran: 900, inset: 30), 900 - 30 - 52 - 64);
    // Portrait, keyboard 300 up with a 96 px key row: exactly the room between the key row and the keyboard.
    expect(h(ecran: 900, inset: 30, clavier: 300, outils: 96), 900 - 30 - 52 - 96 - 300);
    // A keyboard lower than the bar (a floating one reports 0) never frees room the bar still takes.
    expect(h(ecran: 900, clavier: 20), 900 - 52 - 64);
    // Landscape: no bottom bar; the status bar comes back with the keyboard and the top bar sits under it.
    InformatechMarges.poser(914, 412);
    expect(h(ecran: 412), 412 - 52);
    expect(h(ecran: 412, inset: 24, clavier: 200, outils: 60), 412 - 24 - 52 - 200 - 60);
    // Never negative.
    expect(h(ecran: 412, clavier: 400, outils: 60), 0);
    InformatechMarges.retirer();
  });
}
