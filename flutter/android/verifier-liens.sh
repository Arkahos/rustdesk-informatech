#!/bin/bash
# InformaTech (Scylla 17/11): fails unless NO link can start a session in the Android viewer. A session starts only
# through ConnexionActivity (explicit intent from « InformaTech Admin », extras, signature permission). A Dart unit test
# cannot prove that a call is absent, so the sources are read here. Run by every Gradle build (app/build.gradle, task
# informatechSansLien) and by hand from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."
echec() { echo "link check: $1"; exit 1; }
# Code lines only: a line that is nothing but a `//` comment does not count (`|| true`: no match is not a failure).
code() { grep -rnE "$1" "${@:2}" | grep -vE "^[^:]+:[0-9]+:[[:space:]]*//" || true; }
entrees='handleUriLink\(|initUniLinks\(|listenUniLinks\(|uriLinkStream|getInitialLink|getInitialUri|sendUrlScheme\('

# 1. Nothing under lib/mobile reads, listens to or handles a link.
t=$(code "$entrees" lib/mobile --include=*.dart)
[ -z "$t" ] || echec "lib/mobile reaches a link entry: $t"

# 2. The phone's start-up (runMobileApp, from its signature to its closing brace) does not either.
m=lib/main.dart
d=$(grep -n "^void runMobileApp() async {\$" "$m" | cut -d: -f1 || true)
[ "$(echo "$d" | grep -c .)" = 1 ] || echec "$m: exactly one « void runMobileApp() async { » expected"
f=$(tail -n +"$((d + 1))" "$m" | grep -n "^}" | head -1 | cut -d: -f1 || true)
[ -n "$f" ] || echec "$m: end of runMobileApp not found"
t=$(sed -n "$((d + 1)),$((d + f))p" "$m" | grep -nE "$entrees" | grep -vE "^[0-9]+:[[:space:]]*//" || true)
[ -z "$t" ] || echec "$m: runMobileApp reaches a link entry: $t"

# 3. Whoever else calls them (the engine's event on_url_scheme_received, the web page's handleUnilink in
#    lib/mobile/pages/home_page.dart, a future caller): the two functions that turn a link into a session do nothing
#    on a phone. The first statement of each, after comments and blank lines only, is the guard.
c=lib/common.dart
garde() { # <signature line> <expected first statement>
  local h premiere
  h=$(tr -d '\r' < "$c" | grep -nxF "$1" | cut -d: -f1 || true)
  [ "$(echo "$h" | grep -c .)" = 1 ] || echec "$c: exactly one « $1 » expected"
  premiere=$(tail -n +"$((h + 1))" "$c" | tr -d '\r' | grep -vE "^[[:space:]]*(//.*)?\$" | head -1 || true)
  [ "$premiere" = "$2" ] || echec "$c: « $1 » must start with « $2 », found: $premiere"
}
garde "bool handleUriLink({List<String>? cmdArgs, Uri? uri, String? uriString}) {" "  if (isAndroid || isIOS) return false;"
garde "List<String>? urlLinkToCmdArgs(Uri uri) {" "  if (isAndroid || isIOS) return null;"
# And the two flags are still the platform's own, set once (`final`), with no second definition in that file.
for drapeau in isAndroid isIOS; do
  [ "$(tr -d '\r' < "$c" | grep -cE "^final $drapeau = ${drapeau}_;\$")" = 1 ] || echec "$c: « final $drapeau = ${drapeau}_; » expected"
  [ "$(tr -d '\r' < "$c" | grep -cE "(^|[[:space:]])$drapeau[[:space:]]*=[^=>]")" = 1 ] || echec "$c: $drapeau is assigned more than once"
done

# 4. No scan button, and nothing builds the scan page: the viewer reads no QR code.
t=$(code "ScanButton|ScanPage\(" lib --include=*.dart | grep -vE "^lib/mobile/pages/scan_page\.dart:" || true)
[ -z "$t" ] || echec "the QR scan page is reachable: $t"
# The gallery path of that page, should it come back, never hands a QR's text to a link handler (rule 1 covers it).

# 5. The manifest declares no link: no VIEW action, no data element, no browsable category.
a=android/app/src/main/AndroidManifest.xml
t=$(grep -nE "android\.intent\.action\.VIEW|<data[[:space:]]|android\.intent\.category\.BROWSABLE|android:scheme" "$a" || true)
[ -z "$t" ] || echec "$a declares a link: $t"
echo "links: no link entry on the phone, a session starts through ConnexionActivity only (checked by $(command -v bash), $(uname -sr))"
