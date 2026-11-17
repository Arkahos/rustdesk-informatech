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
# (`|| true`: without it an absent guard killed the script under `set -e` before any message, Argos 17/11.)
n=$(grep -n "^        if (!InformatechFenetre.$c) {\$" "$m" | cut -d: -f1 || true)
[ "$(echo "$n" | grep -c .)" = 1 ] || echec "MainActivity: the guarded block must appear exactly once"
# The block must also RUN (Argos 17/11: an early `return` before the guard, or the block moved into a function nobody
# calls, got past the lines above). It is the first statement of the one onCreate: between the signature and the
# guard, only `super.onCreate(savedInstanceState)`, comments and blank lines.
d=$(grep -n "^    override fun onCreate(savedInstanceState: Bundle?) {\$" "$m" | cut -d: -f1 || true)
[ "$(echo "$d" | grep -c .)" = 1 ] || echec "MainActivity: exactly one « override fun onCreate(savedInstanceState: Bundle?) » expected"
[ "$n" -gt "$d" ] || echec "MainActivity: the guarded block must sit inside onCreate (found above it)"
avant=$(sed -n "$((d + 1)),$((n - 1))p" "$m" | grep -vE "^[[:space:]]*(//.*)?\$" || true)
[ "$avant" = "        super.onCreate(savedInstanceState)" ] || echec "MainActivity: the guarded block must be the first statement of onCreate after super.onCreate, found before it: $avant"
[ "$(sed -n "$((n + 1))p" "$m")" = "            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)" ] || echec "MainActivity: addFlags(FLAG_SECURE) must follow the guard"
[ "$(sed -n "$((n + 2))p" "$m")" = "        }" ] || echec "MainActivity: the guarded block must hold addFlags only"
# Nothing may take the flag away again: the only clearFlags / setFlags allowed in the app is upstream's own
# clearFlags(FLAG_ALT_FOCUSABLE_IM); any other one (a FLAG_SECURE one, or a computed flag) fails the build.
autres=$(grep -rnE "clearFlags|setFlags\(" . | grep -vF "window.clearFlags(WindowManager.LayoutParams.FLAG_ALT_FOCUSABLE_IM)" || true)
[ -z "$autres" ] || echec "unexpected clearFlags / setFlags: $autres"
# Nor through the window attributes (Scylla 16/11: `window.attributes = … flags and FLAG_SECURE.inv()` got past the
# rule above). Two rules: (1) in the two activities that own a window, no write to `.flags` or `attributes` and no
# `.inv()`; (2) in the whole app, the token FLAG_SECURE appears only on an addFlags line or in a comment.
activites="main/kotlin/com/carriez/flutter_hbb/MainActivity.kt main/kotlin/com/carriez/flutter_hbb/ConnexionActivity.kt"
attributs=$(grep -nE "flags[[:space:]]*(=|[|&^]=)|attributes[[:space:]]*=|\.inv\(\)" $activites || true)
[ -z "$attributs" ] || echec "window flags written another way: $attributs"
ailleurs=$(grep -rn "FLAG_SECURE" --include=*.kt --include=*.java . | grep -vE ":[0-9]+:[[:space:]]*(//|\*)" | grep -vE "window\.addFlags\((android\.view\.)?WindowManager\.LayoutParams\.FLAG_SECURE\)$" || true)
[ -z "$ailleurs" ] || echec "FLAG_SECURE used outside an addFlags line: $ailleurs"
echo "FLAG_SECURE: release and profile always, waived in debug only (checked by $(command -v bash), $(uname -sr))"
