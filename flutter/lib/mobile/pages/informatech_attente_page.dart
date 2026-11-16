// InformaTech (OPMD Android, A1): the viewer's only home screen. No ID field, no address book, no recent peers, no
// « share my screen »: a session starts only from « InformaTech Admin » (ConnexionActivity). Look: Gon (A6, Hub chart
// D-229) replaces the plain styling below.
import 'package:flutter/material.dart';

import 'home_page.dart';

class InformaTechAttentePage extends StatelessWidget implements PageShape {
  InformaTechAttentePage({Key? key}) : super(key: key);

  @override
  final String title = 'InformaTech Assistance';

  @override
  final Widget icon = const Icon(Icons.desktop_windows_outlined);

  @override
  final List<Widget> appBarActions = const [];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.desktop_windows_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              'En attente d’une session',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ouvrez InformaTech Admin, choisissez l’accès du client, puis « Prendre la main ». '
              'La session s’ouvre ici toute seule.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
