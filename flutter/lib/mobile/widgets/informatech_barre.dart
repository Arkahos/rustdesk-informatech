// InformaTech (OPMD Android, D10): the in-session bars of the viewer, from Gon's mock
// (Jax informatech/brand/05-digital/hub/opmd/android/barre-session.html): an opaque top bar (state dot, PC name,
// duration, « Terminer ») and a bottom bar of tools. The bars push the remote image, they never cover it (D-107).
// « Terminer » is confirmed in place of the bottom bar, never in a dialog. Icons: Lucide (assets/Lucide-LICENSE.txt).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../informatech_charte.dart';

class TextesBarre {
  static const terminer = 'Terminer';
  static const annuler = 'Annuler';
  static const souris = 'Souris';
  static const tactile = 'Tactile';
  static const clavier = 'Clavier';
  static const ecran = 'Écran';
  static const tous = 'Tous';
  static const ctrlAltSuppr = 'Ctrl Alt Suppr';
  static const suppr = 'Suppr';
  static const discussion = 'Discussion';
  static const ecranAAfficher = 'Écran à afficher';
  static const accesResteOuvert = 'L’accès reste ouvert : vous pourrez reprendre la main.';
  static String terminerAvec(String poste) =>
      poste.isEmpty ? 'Terminer la session ?' : 'Terminer la session avec $poste ?';
}

/// « 12:04 », then « 1:02:04 » past the hour.
String dureeSession(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  String deux(int n) => n.toString().padLeft(2, '0');
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, r = s % 60;
  return h > 0 ? '$h:${deux(m)}:${deux(r)}' : '${deux(m)}:${deux(r)}';
}

enum EtatLien { connecte, connexion, perdu }

Color couleurEtat(EtatLien e) => switch (e) {
      EtatLien.connecte => Charte.accent,
      EtatLien.connexion => Charte.ambre,
      EtatLien.perdu => Charte.erreur,
    };

Widget _icone(String nom, Color couleur, [double taille = 20]) => SvgPicture.asset(
      'assets/lucide-$nom.svg',
      width: taille,
      height: taille,
      colorFilter: ColorFilter.mode(couleur, BlendMode.srcIn),
    );

class BarreHaut extends StatefulWidget implements PreferredSizeWidget {
  const BarreHaut({super.key, required this.poste, this.client, required this.etat, required this.debut, required this.onTerminer});
  /// Both read at every tick (once a second): the PC name arrives after the bar is up, and an outage must show
  /// without a rebuild from the page. Plain callbacks, no Obx around the bar.
  final String Function() poste;
  final String? client;
  final EtatLien Function() etat;
  final DateTime debut;
  final VoidCallback onTerminer;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  State<BarreHaut> createState() => _BarreHautState();
}

class _BarreHautState extends State<BarreHaut> {
  Timer? _tic;

  @override
  void initState() {
    super.initState();
    _tic = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    return Material(
      color: Charte.fond,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 52,
          padding: const EdgeInsets.only(left: 14, right: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.trait))),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: couleurEtat(widget.etat()), shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.poste(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: Charte.police, fontWeight: FontWeight.w600, fontSize: 15, color: Charte.texte)),
                if (client != null && client.isNotEmpty)
                  Text(client,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: Charte.police, fontSize: 12, color: Charte.texte2)),
              ]),
            ),
            Text(dureeSession(DateTime.now().difference(widget.debut)),
                style: const TextStyle(
                    fontFamily: Charte.police, fontSize: 13, color: Charte.texte2, fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(width: 10),
            SizedBox(
              height: 36,
              child: OutlinedButton.icon(
                onPressed: widget.onTerminer,
                icon: _icone('square', Charte.erreur, 16),
                label: const Text(TextesBarre.terminer),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Charte.erreur,
                  side: const BorderSide(color: Charte.erreur, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontFamily: Charte.police, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Outil extends StatelessWidget {
  const _Outil({required this.icone, required this.libelle, required this.onTap, this.actif = false, this.petit = false});
  final Widget icone;
  final String libelle;
  final VoidCallback? onTap;
  final bool actif;
  final bool petit;

  @override
  Widget build(BuildContext context) {
    final couleur = onTap == null ? Charte.texte3 : (actif ? Charte.accent : Charte.texte);
    return SizedBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        child: Material(
          color: actif ? Charte.surface2 : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(height: 22, child: Center(child: icone)),
              const SizedBox(height: 4),
              Text(libelle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: TextStyle(fontFamily: Charte.police, fontSize: petit ? 10 : 11, color: couleur)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The bottom bar: 5 tools, or the « Terminer » confirmation in the same place.
class BarreBas extends StatelessWidget {
  const BarreBas({
    super.key,
    required this.poste,
    required this.confirme,
    required this.tactile,
    required this.clavierPermis,
    required this.ecrans,
    required this.ecranCourant,
    required this.onMode,
    required this.onClavier,
    required this.onEcran,
    required this.onCtrlAltSuppr,
    required this.onDiscussion,
    required this.onAnnuler,
    required this.onTerminer,
    this.rail = 0,
  });

  /// 0 = bottom bar (portrait); else the width of the right rail (landscape, tablet).
  final double rail;
  final String poste;
  final bool confirme;
  final bool tactile;
  final bool clavierPermis;
  final int ecrans;
  /// 0-based; negative = all screens.
  final int ecranCourant;
  final VoidCallback onMode, onClavier, onEcran, onCtrlAltSuppr, onDiscussion, onAnnuler, onTerminer;

  @override
  Widget build(BuildContext context) {
    if (rail > 0 && !confirme) {
      return Material(
        color: Charte.fond,
        child: Container(
          width: rail,
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Charte.trait))),
          // Centred in a rail as tall as the body (the page stretches it); scrolls when the body is shorter.
          child: Center(
            child: SingleChildScrollView(
              child: Column(children: [for (final o in _outils()) SizedBox(width: rail, height: 60, child: o)]),
            ),
          ),
        ),
      );
    }
    return Material(
      color: Charte.fond,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: confirme ? Charte.erreur : Charte.trait))),
          child: confirme
              ? _confirmation()
              : SizedBox(height: 64, child: Row(children: [for (final o in _outils()) Expanded(child: o)])),
        ),
      ),
    );
  }

  List<Widget> _outils() {
    final c = clavierPermis ? Charte.texte : Charte.texte3;
    return [
      _Outil(
          icone: _icone(tactile ? 'hand' : 'mouse-pointer-2', Charte.accent),
          libelle: tactile ? TextesBarre.tactile : TextesBarre.souris,
          actif: true,
          onTap: onMode),
      _Outil(icone: _icone('keyboard', c), libelle: TextesBarre.clavier, onTap: clavierPermis ? onClavier : null),
      if (ecrans > 1)
        _Outil(
            icone: _icone('monitor', Charte.texte),
            libelle: ecranCourant < 0 ? TextesBarre.tous : '${TextesBarre.ecran} ${ecranCourant + 1}',
            onTap: onEcran),
      _Outil(
          icone: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(5)),
            child: Text(TextesBarre.suppr,
                style: TextStyle(fontFamily: Charte.police, fontWeight: FontWeight.w600, fontSize: 10, color: c)),
          ),
          libelle: TextesBarre.ctrlAltSuppr,
          petit: true,
          onTap: clavierPermis ? onCtrlAltSuppr : null),
      _Outil(icone: _icone('message-square', Charte.texte), libelle: TextesBarre.discussion, onTap: onDiscussion),
    ];
  }

  Widget _confirmation() {
    const style = TextStyle(fontFamily: Charte.police, fontWeight: FontWeight.w600, fontSize: 15);
    final forme = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(TextesBarre.terminerAvec(poste),
            style: const TextStyle(fontFamily: Charte.police, fontWeight: FontWeight.w500, fontSize: 15, color: Charte.texte)),
        const SizedBox(height: 4),
        const Text(TextesBarre.accesResteOuvert,
            style: TextStyle(fontFamily: Charte.police, fontSize: 13, height: 1.4, color: Charte.texte2)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextButton(
                autofocus: true,
                onPressed: onAnnuler,
                style: TextButton.styleFrom(backgroundColor: Charte.surface2, foregroundColor: Charte.texte, shape: forme, textStyle: style),
                child: const Text(TextesBarre.annuler),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: TextButton.icon(
                onPressed: onTerminer,
                icon: _icone('square', const Color(0xFF1A0D0C), 16),
                label: const Text(TextesBarre.terminer),
                style: TextButton.styleFrom(
                    backgroundColor: Charte.erreur, foregroundColor: const Color(0xFF1A0D0C), shape: forme, textStyle: style),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Bottom sheet « Écran à afficher ». Returns the chosen 0-based index, -1 for all, null when dismissed.
Future<int?> choisirEcran(BuildContext context, {required int ecrans, required int courant, required bool tousPermis}) {
  Widget tuile(String libelle, int valeur) {
    final choisi = valeur == courant || (valeur < 0 && courant < 0);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).pop(valeur),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Charte.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: choisi ? Charte.accent : Colors.transparent, width: 2),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _icone('monitor', choisi ? Charte.texte : Charte.texte2),
              const SizedBox(height: 4),
              Text(libelle,
                  style: TextStyle(fontFamily: Charte.police, fontSize: 12, color: choisi ? Charte.texte : Charte.texte2)),
            ]),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Charte.surface,
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 36, height: 4, decoration: BoxDecoration(color: Charte.traitFort, borderRadius: BorderRadius.circular(2)))),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 16, 4, 14),
            child: Text(TextesBarre.ecranAAfficher,
                style: TextStyle(fontFamily: Charte.police, fontWeight: FontWeight.w600, fontSize: 16, color: Charte.texte)),
          ),
          Row(children: [
            for (var i = 0; i < ecrans; i++) tuile('${TextesBarre.ecran} ${i + 1}', i),
            if (tousPermis) tuile(TextesBarre.tous, -1),
          ]),
        ]),
      ),
    ),
  );
}
