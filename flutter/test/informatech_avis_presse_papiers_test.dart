import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/informatech_presse_papiers.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _fenetre(bool actif) => MaterialApp(home: Scaffold(body: Column(children: [informatechAvisPressePapiersCm(actif)])));

Map<String, dynamic> _client({bool? pressePapiers}) => {
      'id': 1,
      'authorized': true,
      'is_file_transfer': false,
      'is_view_camera': false,
      'port_forward': '',
      'name': 'Adrien',
      'peer_id': '123456789',
      'keyboard': true,
      'clipboard': true,
      'audio': false,
      'file': false,
      'restart': false,
      'recording': false,
      'block_input': false,
      'disconnected': false,
      'from_switch': false,
      'in_voice_call': false,
      'incoming_voice_call': false,
      if (pressePapiers != null) 'informatech_presse_papiers_client': pressePapiers,
    };

void main() {
  testWidgets('S-098b: the client window shows the clipboard line only while the switch is on', (tester) async {
    await tester.pumpWidget(_fenetre(true));
    expect(find.text('Le technicien peut copier depuis votre presse-papiers pendant cette séance.'), findsOneWidget);
    await tester.pumpWidget(_fenetre(false));
    expect(find.byKey(const ValueKey('informatech-avis-presse-papiers')), findsNothing);
  });

  test('S-098b: the engine row carries the switch, absent means off', () {
    expect(Client.fromJson(_client(pressePapiers: true)).informatechPressePapiersClient, isTrue);
    expect(Client.fromJson(_client()).informatechPressePapiersClient, isFalse);
    expect(Client.fromJson(_client(pressePapiers: true)).toJson()['informatech_presse_papiers_client'], isTrue);
  });

  // ServerModel needs the engine, so the update of an existing row (the switch turned on mid-session) is pinned in place.
  test('S-098b: every addConnection branch that updates an existing row carries the switch', () {
    final source = File('lib/models/server_model.dart').readAsStringSync().replaceAll('\r\n', '\n');
    final debut = source.indexOf('void addConnection(Map<String, dynamic> evt) {');
    final fin = source.indexOf('_addTab(client);', debut);
    expect(debut, greaterThan(0));
    final corps = source.substring(debut, fin);
    const copie = '_clients[index].informatechPressePapiersClient = client.informatechPressePapiersClient;';
    expect('_clients[index].privacyMode = client.privacyMode;'.allMatches(corps).length, 3);
    expect(copie.allMatches(corps).length, 3);
    final ligne = RegExp(r'_clients\[index\]\.privacyMode = client\.privacyMode;\n\s*' + RegExp.escape(copie));
    expect(ligne.allMatches(corps).length, 3);
  });
}
