/// InformaTech (A9-2, Scylla 18/11): a switch of the client's connection window that the engine refuses (audio, file
/// copy and paste, session recording: `informatech_permissions_forcees` in src/common.rs) must not move on screen
/// while doing nothing. It is shown off, greyed, with one line saying why.
///
/// The switch names are the ones the window sends (`cmSwitchPermission`), the options those the engine forces to
/// « N » for a refused kind. Keep in step with `informatech_option_de_bascule` (src/common.rs).
const Map<String, String> kInformatechBasculesRefusables = {
  'audio': 'enable-audio',
  'file': 'enable-file-transfer',
  'recording': 'enable-record-session',
};

/// The line shown on a refused switch (wording to confirm with Styx).
const String kInformatechRefusBascule = 'Désactivé sur ce poste par InformaTech';

/// The reason to show on switch `nom`, or null when the client may use it. `option` reads an engine option
/// (`bind.mainGetOptionSync`); only the kinds above can be refused here, so a client who turned the keyboard off
/// never reads « désactivé par InformaTech ».
String? informatechRefusBascule(String nom, String Function(String option) option) {
  final cle = kInformatechBasculesRefusables[nom];
  if (cle == null) return null;
  return option(cle) == 'N' ? kInformatechRefusBascule : null;
}
