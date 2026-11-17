import 'package:flutter_hbb/common/informatech_permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A9-2 (Scylla 18/11): a refused switch is greyed with its reason; the client's own switches never are.
  test('the refused kinds read their forced option, the others are never greyed', () {
    String toutRefuse(String option) => 'N';
    String rienRefuse(String option) => '';
    for (final nom in ['audio', 'file', 'recording']) {
      expect(informatechRefusBascule(nom, toutRefuse), kInformatechRefusBascule, reason: nom);
      expect(informatechRefusBascule(nom, rienRefuse), isNull, reason: nom);
    }
    for (final nom in ['keyboard', 'clipboard', 'restart', 'block_input', 'privacy_mode', 'inconnu']) {
      expect(informatechRefusBascule(nom, toutRefuse), isNull, reason: nom);
    }
    expect(kInformatechBasculesRefusables, {
      'audio': 'enable-audio',
      'file': 'enable-file-transfer',
      'recording': 'enable-record-session',
    });
  });
}
