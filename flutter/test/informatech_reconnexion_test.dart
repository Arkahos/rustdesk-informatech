import 'package:flutter_hbb/mobile/informatech_reconnexion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retries come back within 4 s: 1, 2, 4, 4', () {
    var d = 1;
    final suite = <int>[];
    for (var i = 0; i < 4; i++) {
      d = informatechProchainDelai(d);
      suite.add(d);
    }
    expect(suite, [2, 4, 4, 4]);
    expect(informatechProchainDelai(0), 1);
  });

  test('airplane mode 2 min: still retrying, a retry lands within 4 s of the network', () {
    final t0 = DateTime(2026, 11, 16, 14);
    expect(informatechAbandonner(t0, t0.add(const Duration(seconds: 120))), isFalse);
    expect(informatechAbandonner(t0, t0.add(const Duration(seconds: 239))), isFalse);
  });

  test('past the A12 grace the viewer stops and says so', () {
    final t0 = DateTime(2026, 11, 16, 14);
    expect(informatechAbandonner(t0, t0.add(const Duration(seconds: 240))), isTrue);
    expect(InformatechReconnexion.perteCorps, contains('InformaTech Admin'));
  });
}
