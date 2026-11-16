#!/bin/bash
# InformaTech: fails unless the viewer's window is FLAG_SECURE in the release and profile build types (the waiver for
# screenshots exists in the debug build type only) and MainActivity applies it. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/app/src"
f=kotlin/com/carriez/flutter_hbb/InformatechFenetre.kt
c=CAPTURE_ECRAN_AUTORISEE_BUILD_DEBUG_SEULEMENT
grep -q "const val $c = true" "debug/$f" || { echo "debug/$f: expected true"; exit 1; }
for t in release profile; do
  grep -q "const val $c = false" "$t/$f" || { echo "$t/$f: must be false"; exit 1; }
done
[ "$(grep -rl "const val $c" . | wc -l)" = 3 ] || { echo "$c defined elsewhere"; exit 1; }
grep -q "if (!InformatechFenetre.$c) {" main/kotlin/com/carriez/flutter_hbb/MainActivity.kt || { echo "MainActivity: FLAG_SECURE not tied to $c"; exit 1; }
grep -A1 "if (!InformatechFenetre.$c) {" main/kotlin/com/carriez/flutter_hbb/MainActivity.kt | grep -q "FLAG_SECURE" || { echo "MainActivity: FLAG_SECURE missing"; exit 1; }
echo "FLAG_SECURE: release and profile always, waived in debug only"
