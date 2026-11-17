// InformaTech (S-078): a link that reached this process on its command line never carries a password. Same rule as
// the engine's `informatech_lien_avec_mot_de_passe` (src/common.rs): a `password` query parameter, whatever its case
// or percent-encoding, or the `<app>://password/<value>` form.
bool lienAvecMotDePasse(String lien) {
  final uri = Uri.tryParse(lien.trim());
  if (uri == null) return false;
  try {
    if (Uri.decodeComponent(uri.authority).toLowerCase() == 'password') return true;
    return uri.queryParameters.keys.any((k) => k.trim().toLowerCase() == 'password');
  } catch (_) {
    // Not decodable: nothing will read a password out of it, but anything that names one is still refused.
    return uri.toString().toLowerCase().contains('password');
  }
}
