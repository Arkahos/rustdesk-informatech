import 'package:flutter/material.dart';

/// InformaTech (S-098, Adrien 23/11): the viewer's switch letting the client's clipboard reach the technician for one
/// session. Keep the option name in step with `INFORMATECH_OPTION_PRESSE_PAPIERS_CLIENT` (src/common.rs).
const String kInformatechOptionPressePapiersClient = 'informatech-clipboard-from-client';

const String kInformatechPressePapiersClient = 'Copier depuis le presse-papiers du client (cette session)';

/// S-098b (Adrien 23/11, « message visible », no consent asked): line the client's window shows while the technician's
/// switch is on. Wording: Styx.
const String kInformatechAvisPressePapiersCm = 'Le technicien peut copier depuis votre presse-papiers pendant cette séance.';

/// S-098b: the client's connection manager window shows this banner while the switch is on, nothing otherwise.
Widget informatechAvisPressePapiersCm(bool actif) {
  if (!actif) return const SizedBox.shrink();
  return Container(
    key: const ValueKey('informatech-avis-presse-papiers'),
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8.0),
    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
    decoration: BoxDecoration(
      color: Colors.amber.shade100,
      border: Border.all(color: Colors.amber.shade700),
      borderRadius: BorderRadius.circular(6.0),
    ),
    child: Row(
      children: [
        Icon(Icons.content_paste_rounded, color: Colors.amber.shade900, size: 20),
        const SizedBox(width: 8.0),
        Expanded(
          child: Text(
            kInformatechAvisPressePapiersCm,
            style: TextStyle(color: Colors.brown.shade900, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
