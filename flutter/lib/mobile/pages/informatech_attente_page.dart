// InformaTech (OPMD Android, A1): the viewer's only home screen. No ID field, no address book, no recent peers, no
// « share my screen »: a session starts only from « InformaTech Admin » (ConnexionActivity). Look: Hub charter D-229
// (informatech_charte.dart), texts in informatech_textes.dart, Lucide icon (assets/Lucide-LICENSE.txt).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../informatech_charte.dart';
import '../informatech_textes.dart';
import 'home_page.dart';

class InformaTechAttentePage extends StatelessWidget implements PageShape {
  InformaTechAttentePage({Key? key}) : super(key: key);

  @override
  final String title = Textes.nomApp;

  @override
  final Widget icon = const SizedBox.shrink();

  @override
  final List<Widget> appBarActions = const [];

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Charte.fond,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: Charte.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Charte.trait),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: Charte.surface2, borderRadius: BorderRadius.circular(18)),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/lucide-monitor-smartphone.svg',
                    width: 30,
                    height: 30,
                    colorFilter: const ColorFilter.mode(Charte.accent, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  Textes.attenteTitre,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: Charte.police, fontWeight: FontWeight.w600, fontSize: 18, color: Charte.texte),
                ),
                const SizedBox(height: 10),
                const Text(
                  Textes.attenteCorps,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: Charte.police, fontSize: 14, height: 1.5, color: Charte.texte2),
                ),
                const SizedBox(height: 18),
                Container(height: 1, color: Charte.trait),
                const SizedBox(height: 14),
                const Text(
                  Textes.attenteNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: Charte.police, fontSize: 12, height: 1.4, color: Charte.texte3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
