#!/bin/bash
# InformaTech: fails unless the viewer's window is FLAG_SECURE in the release and profile build types (the waiver for
# screenshots exists in the debug build type only) and MainActivity applies it. Run by every Gradle build
# (app/build.gradle, task informatechFlagSecure) and by hand from anywhere.
set -euo pipefail
cd "$(dirname "$0")/app/src"
f=kotlin/com/carriez/flutter_hbb/InformatechFenetre.kt
c=CAPTURE_ECRAN_AUTORISEE_BUILD_DEBUG_SEULEMENT
m=main/kotlin/com/carriez/flutter_hbb/MainActivity.kt
echec() { echo "FLAG_SECURE check: $1"; exit 1; }
# The constant: one definition per build type, three in all, and nothing else named like it in a definition.
[ "$(grep -c "^    const val $c = true\$" "debug/$f")" = 1 ] || echec "debug/$f: expected exactly « const val $c = true »"
for t in release profile; do
  [ "$(grep -c "^    const val $c = false\$" "$t/$f")" = 1 ] || echec "$t/$f: expected exactly « const val $c = false »"
  # Not even in a comment: the word must not appear at all in a release or profile file.
  ! grep -q "true" "$t/$f" || echec "$t/$f: contains « true »"
done
[ "$(grep -rl "val $c" . | wc -l)" = 3 ] || echec "$c is defined somewhere else too"
# MainActivity: the three lines, in this order, exactly once; and nothing that could take the flag away again.
n=$(grep -n "^        if (!InformatechFenetre.$c) {\$" "$m" | cut -d: -f1)
[ "$(echo "$n" | grep -c .)" = 1 ] || echec "MainActivity: the guarded block must appear exactly once"
[ "$(sed -n "$((n + 1))p" "$m")" = "            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)" ] || echec "MainActivity: addFlags(FLAG_SECURE) must follow the guard"
[ "$(sed -n "$((n + 2))p" "$m")" = "        }" ] || echec "MainActivity: the guarded block must hold addFlags only"
# Nothing may take the flag away again: the only clearFlags / setFlags allowed in the app is upstream's own
# clearFlags(FLAG_ALT_FOCUSABLE_IM); any other one (a FLAG_SECURE one, or a computed flag) fails the build.
autres=$(grep -rnE "clearFlags|setFlags\(" . | grep -vF "window.clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)" || true)
[ -z "$autres" ] || echec "unexpected clearFlags / setFlags: $autres"
echo "FLAG_SECURE: release and profile always, waived in debug only"
