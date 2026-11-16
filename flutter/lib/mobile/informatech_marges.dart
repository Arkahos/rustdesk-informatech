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

  /// Material « expanded » width: tablet layout from here (Gon, tablette.html).
  static const largeurTablette = 840.0;

  /// The bars for a screen of [largeur] x [hauteur]: tools at the bottom in portrait, in a right rail in landscape.
  /// Returns true when something changed (the canvas must then be fitted again).
  static bool poser(double largeur, double hauteur) {
    final paysage = largeur > hauteur;
    const h = barreHaut;
    final b = paysage ? 0.0 : barreBas;
    final d = paysage ? (largeur >= largeurTablette ? railTablette : rail) : 0.0;
    final change = h != haut || b != bas || d != droite;
    haut = h;
    bas = b;
    droite = d;
    return change;
  }

  static void retirer() {
    haut = 0;
    bas = 0;
    droite = 0;
  }
}
