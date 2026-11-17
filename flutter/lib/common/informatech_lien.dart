// InformaTech (S-078): a link that reached this process on its command line never names a password. The second lock
// behind the engine's `informatech_refus_au_demarrage` (src/common.rs), with the same reading as its
// `informatech_lire_lien`, wider on purpose than `Uri.parse` (Scylla 17/11), so no second reading of the same text
// gets a password past it:
// - tabs and line ends are dropped anywhere, a backslash counts as a slash;
// - any run of slashes after `scheme:`; the first path segment is the command (`password/<value>` is refused);
// - a name is percent-decoded until it no longer changes, `+` is a space, spaces around are trimmed, case is ignored;
// - names are looked for in the query AND the fragment, split on `&`, `;`, `?` and `#`.
// Unlike the engine, any scheme is read: this only ever gets a link.
import 'dart:convert';

/// InformaTech (S-078, Scylla R1 18/11): what `handleUriLink` takes for `--password` at index `i` of `args`.
/// From the real command line: nothing, the session does not start (the engine exits 2 on such a line first; this is
/// the second lock). From a link that reached the running window (the warm path: our engine hands it
/// `informatech://connect/<id>?password=…`, built from its stdin read, to a window of this very executable, owner
/// checked), `urlLinkToCmdArgs` turns the link's password into `--password <value>`: that one is taken. null = refuse.
String? informatechMotDePasseDesArguments(List<String> args, int i, {required bool depuisLien}) {
  if (!depuisLien || i + 1 >= args.length) return null;
  final valeur = args[i + 1];
  return valeur.isEmpty ? null : valeur;
}

bool lienAvecMotDePasse(String lien) {
  final a = lien.replaceAll(RegExp(r'[\t\r\n]'), '').replaceAll('\\', '/').trim();
  final deuxPoints = a.indexOf(':');
  if (deuxPoints <= 0) return false;
  final reste = a.substring(deuxPoints + 1).replaceFirst(RegExp(r'^/+'), '');
  final coupe = reste.indexOf(RegExp(r'[?#]'));
  final chemin = coupe < 0 ? reste : reste.substring(0, coupe);
  final suite = coupe < 0 ? '' : reste.substring(coupe + 1);
  if (_nommeUnMotDePasse(chemin.split('/').first)) return true;
  return suite.split(RegExp(r'[&;?#]')).any((p) => _nommeUnMotDePasse(p.split('=').first));
}

/// True for a name that decodes to « password », or that still changes after eight decodings (nothing reads that).
bool _nommeUnMotDePasse(String brut) {
  var courant = brut;
  for (var i = 0; i < 8; i++) {
    final suivant = _decoderPourcent(courant);
    if (suivant == courant) return courant.trim().toLowerCase() == 'password';
    courant = suivant;
  }
  return true;
}

/// `%41` → `A`, `+` → space; anything malformed stays as it is.
String _decoderPourcent(String s) {
  final o = utf8.encode(s);
  final sortie = <int>[];
  int? hexa(int i) => i < o.length ? int.tryParse(String.fromCharCode(o[i]), radix: 16) : null;
  for (var i = 0; i < o.length;) {
    final h = hexa(i + 1), l = hexa(i + 2);
    if (o[i] == 0x25 && h != null && l != null) {
      sortie.add(h * 16 + l);
      i += 3;
    } else {
      sortie.add(o[i] == 0x2B ? 0x20 : o[i]);
      i += 1;
    }
  }
  return utf8.decode(sortie, allowMalformed: true);
}
