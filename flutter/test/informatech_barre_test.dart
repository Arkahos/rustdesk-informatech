import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/informatech_discussion.dart';
import 'package:flutter_hbb/mobile/widgets/informatech_barre.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _barre({required bool confirme, int ecrans = 1, bool clavier = true, VoidCallback? onTerminer, VoidCallback? onAnnuler}) =>
    MaterialApp(
      home: Scaffold(
        bottomNavigationBar: BarreBas(
          poste: 'PC-SALON',
          confirme: confirme,
          tactile: false,
          clavierPermis: clavier,
          ecrans: ecrans,
          ecranCourant: 0,
          onMode: () {},
          onClavier: () {},
          onEcran: () {},
          onCtrlAltSuppr: () {},
          onDiscussion: () {},
          onAnnuler: onAnnuler ?? () {},
          onTerminer: onTerminer ?? () {},
        ),
      ),
    );

void main() {
  testWidgets('the state dot follows the link: mint connected, amber connecting, coral lost', (t) async {
    var etat = EtatLien.connecte;
    var poste = '';
    await t.pumpWidget(MaterialApp(
        home: Scaffold(appBar: BarreHaut(poste: () => poste, etat: () => etat, debut: DateTime.now(), onTerminer: () {}))));
    // The page wires the bar exactly like this, as the scaffold's appBar and with no Obx: nothing may throw.
    expect(t.takeException(), isNull);
    Color point() => ((t.widgetList<Container>(find.byType(Container)).firstWhere((c) => c.constraints?.maxWidth == 8).decoration) as BoxDecoration).color!;
    expect(point(), couleurEtat(EtatLien.connecte));
    etat = EtatLien.perdu;
    await t.pump(const Duration(seconds: 1));
    expect(point(), couleurEtat(EtatLien.perdu));
    // The PC name arrives after the bar is built: it shows at the next tick.
    expect(find.text('PC-SALON'), findsNothing);
    poste = 'PC-SALON';
    await t.pump(const Duration(seconds: 1));
    expect(find.text('PC-SALON'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('0.x: a message from the PC never opens the chat on the Android viewer; elsewhere upstream is unchanged', () {
    expect(informatechChatOuvrable(android: true, modeClient: true), isFalse);
    // The phone as the controlled side (server mode) and the desktop viewer keep upstream's behaviour.
    expect(informatechChatOuvrable(android: true, modeClient: false), isTrue);
    expect(informatechChatOuvrable(android: false, modeClient: true), isTrue);
  });

  test('duration reads mm:ss, then h:mm:ss', () {
    expect(dureeSession(const Duration(minutes: 12, seconds: 4)), '12:04');
    expect(dureeSession(const Duration(hours: 1, minutes: 2, seconds: 4)), '1:02:04');
    expect(dureeSession(const Duration(seconds: -3)), '00:00');
  });

  testWidgets('D10 tools: mouse, keyboard, Ctrl Alt Suppr; no chat in 0.x, no file transfer, no screen button with one screen', (t) async {
    await t.pumpWidget(_barre(confirme: false));
    for (final l in ['Souris', 'Clavier', 'Ctrl Alt Suppr']) {
      expect(find.text(l), findsOneWidget);
    }
    // Adrien 22/11: the raw OPMD chat is hidden in 0.x (kInformatechDiscussion).
    expect(kInformatechDiscussion, isFalse);
    expect(find.text('Discussion'), findsNothing);
    expect(find.textContaining('Écran'), findsNothing);
    expect(find.textContaining('ichier'), findsNothing);
    await t.pumpWidget(_barre(confirme: false, ecrans: 2));
    expect(find.text('Écran 1'), findsOneWidget);
  });

  testWidgets('« Terminer » is confirmed in place: Annuler or Terminer, with the PC name', (t) async {
    var fin = 0, annule = 0;
    await t.pumpWidget(_barre(confirme: true, onTerminer: () => fin++, onAnnuler: () => annule++));
    expect(find.text('Terminer la session avec PC-SALON ?'), findsOneWidget);
    expect(find.text('Souris'), findsNothing);
    await t.tap(find.text('Annuler'));
    expect((annule, fin), (1, 0));
    await t.tap(find.text('Terminer'));
    expect(fin, 1);
  });
}
