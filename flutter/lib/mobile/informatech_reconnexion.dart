// InformaTech (OPMD Android, D17): how the viewer retries after the phone lost the session (screen off, airplane mode,
// 4G <-> Wi-Fi). Pure functions, tested in test/informatech_reconnexion_test.dart.
//
// The client PC keeps the session's OPMD password for 3 minutes after the connection dropped (A12 grace), then draws a
// new one: a retry is useful only inside that window. Retries come every few seconds (upstream doubles without bound,
// which could leave a 2-minute outage waiting 2 more minutes), and stop once the window is surely over.

/// Longest wait between two retries, in seconds.
const informatechDelaiMaxS = 4;

/// Retries stop after this long. Worst case for the PC's rotation after a silent drop (Argos 16/11): 30 s (the PC's
/// receive timeout, connection.rs SEC30) + 180 s (A12 GRACE_S) + 15 s (one PAS tick) = 225 s. At 240 s the PC has
/// rotated for sure, so « Rouvrez la session » works at once; stopping before 225 s could send Adrien to a
/// `mot_de_passe_utilise` refusal.
const informatechAbandonApres = Duration(seconds: 240);

/// The next wait (seconds) after a wait of [actuel] seconds: 1, 2, 4, 4, 4…
int informatechProchainDelai(int actuel) {
  final n = actuel < 1 ? 1 : actuel * 2;
  return n > informatechDelaiMaxS ? informatechDelaiMaxS : n;
}

/// True once retrying since [depuis] is pointless at [maintenant].
bool informatechAbandonner(DateTime depuis, DateTime maintenant) =>
    maintenant.difference(depuis) >= informatechAbandonApres;

class InformatechReconnexion {
  static const perteTitre = 'Session interrompue';
  static const perteCorps = 'La connexion au poste du client n’a pas pu être rétablie. '
      'Rouvrez la session depuis InformaTech Admin. Une recette lancée continue sur le poste.';
}
