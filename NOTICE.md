# NOTICE: OPMD (InformaTech Assistance), a modified version of RustDesk

**OPMD** (shown to users as « InformaTech Assistance ») is a modified version of
[RustDesk](https://github.com/rustdesk/rustdesk), © RustDesk developers (Purslane Tech Pte. Ltd. and contributors), licensed
under the **GNU Affero General Public License v3.0** (see `LICENCE`). This fork is maintained by **InformaTech**
(computer repair, Gap, France) and is distributed under the same licence.

- Upstream base: RustDesk tag **`1.5.0`**.
- Our branch: **`informatech`** (default branch of this repository). Every released build is tagged
  `opmd-v<version>` on the exact commit it was built from, with its source code available here.
- All original copyright notices are kept. OPMD is **not** affiliated with, endorsed or supported by RustDesk;
  « RustDesk » and its logo are not used as our brand.
- Corresponding source for any OPMD build we distribute: the tag of that version in this repository
  (e.g. <https://github.com/Arkahos/rustdesk-informatech/tree/opmd-v0.1.1>).

## Our modifications (vs RustDesk 1.5.0)

| Date | Change | Files |
|---|---|---|
| 2026-10-14 | Client customisation: app name `InformaTech` (custom-client mode), default options | `src/common.rs` |
| 2026-10-14 / 15 | Icons and executable metadata (14/10), dedicated « InformaTech Assistance » icon (15/10, D-128) | `res/icon.*`, `res/tray-icon.ico`, `flutter/windows/runner/*`, `flutter/assets/icon.svg` |
| 2026-10-14 | Windows x64-only release workflow | `.github/workflows/informatech-release.yml` |
| 2026-10-14 | Fork note in the README; integration sheet `CONTRAT.md` | `README.md`, `CONTRAT.md` |
| 2026-10-16 | Installed as `InformaTech.exe` with readable Windows names; `opmd-v*` tags and `OPMD-<version>` assets | `src/common.rs`, `src/platform/windows.rs`, workflow |
| 2026-10-16 | Locked options: password-only access, connection window hidden (the InformaTech hub shows the session and the « end session » control instead) | `src/common.rs` |
| 2026-10-16 | `--close-connections` command: ends every incoming session | `src/core_main.rs`, `src/common.rs` |
| 2026-10-16 | Own ID/relay server `opmd.informatech-paca.fr` with its public key, locked, no fallback to RustDesk's public servers | `src/common.rs`, workflow |
| 2026-10-16 | Viewer home screen (« Postes accessibles »), Poppins font (SIL OFL 1.1, `flutter/assets/Poppins-OFL.txt`) | `flutter/lib/desktop/pages/opmd_home_page.dart`, `desktop_tab_page.dart`, `flutter/pubspec.yaml`, `flutter/assets/fonts/*` |
| 2026-10-16 | 0.1.1: setup executable named OPMD / InformaTech Assistance, remote audio locked off | `libs/portable/*`, `src/common.rs`, `opmd_home_page.dart` (footer) |

The full, exact list is `git log 1.5.0..informatech` and `git diff 1.5.0 informatech` in this repository.

## Third-party components added by us

- **Poppins** font, © Indian Type Foundry, SIL Open Font License 1.1 (`flutter/assets/Poppins-OFL.txt`).

## Intended use

OPMD is used by InformaTech for **authorised** remote support of its clients' computers, with their consent.
