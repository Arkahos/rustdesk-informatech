// InformaTech (Styx 16/11): the session view shows the client's screen, which is never recorded.
// DEBUG build type only: screenshots of the viewer are allowed so the screens can be captured for
// design and test notes. Never shipped: Adrien installs release builds signed with his certificate.
// One file per build type (src/debug, src/release, src/profile): a compile-time constant, not a runtime option.
package com.carriez.flutter_hbb

object InformatechFenetre {
    const val CAPTURE_ECRAN_AUTORISEE_BUILD_DEBUG_SEULEMENT = true
}
