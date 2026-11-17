// InformaTech (OPMD Android, D10): room taken by the viewer's session bars (widgets/informatech_barre.dart), in logical
// pixels. The bars push the remote image instead of covering it (D-107), so CanvasModel.getSize() subtracts them: the
// image is fitted to what is left, not to the whole screen. All zero outside a session.
class InformatechMarges {
  static double haut = 0;
  static double bas = 0;
  static double droite = 0;

  static const barreHaut = 52.0;
  static const barreBas = 64.0;
  static const rail = 72.0;
  static const railTablette = 88.0;

  /// A tablet is told by its SHORT side (Android's sw600dp), not by its width: a phone in landscape is wider than
  /// Material's 840 dp « expanded » breakpoint (S24+: about 914 x 412 dp) and must keep the phone rail.
  static const petitCoteTablette = 600.0;

  /// The bars for a screen of [largeur] x [hauteur]: tools at the bottom in portrait, in a right rail in landscape.
  /// Returns true when something changed (the canvas must then be fitted again).
  static bool poser(double largeur, double hauteur) {
    final paysage = largeur > hauteur;
    const h = barreHaut;
    final b = paysage ? 0.0 : barreBas;
    final petitCote = largeur < hauteur ? largeur : hauteur;
    final d = paysage ? (petitCote >= petitCoteTablette ? railTablette : rail) : 0.0;
    final change = h != haut || b != bas || d != droite;
    haut = h;
    bas = b;
    droite = d;
    return change;
  }

  /// Height left for the image in a session (Argos 17/11, P3), from the screen height [ecran]: the top bar sits under
  /// the top inset [insetHaut] in both orientations; the Scaffold lays the bottom bar BEHIND the soft keyboard, so the
  /// body ends at the taller of the two ([clavier] = viewInsets.bottom), never at their sum; [outilsClavier] is the
  /// height of the key row shown above the image while the keyboard is up (0 otherwise).
  static double hauteurImage(
      {required double ecran, required double insetHaut, required double clavier, required double outilsClavier}) {
    final h = ecran - insetHaut - haut - (clavier > bas ? clavier : bas) - outilsClavier;
    return h < 0 ? 0 : h;
  }

  static void retirer() {
    haut = 0;
    bas = 0;
    droite = 0;
  }
}
