// InformaTech (Styx 16/11): the session view shows the client's screen, which is never recorded.
// RELEASE build type: the viewer window is always FLAG_SECURE.
// One file per build type (src/debug, src/release, src/profile): a compile-time constant, not a runtime option.
package com.carriez.flutter_hbb

object InformatechFenetre {
    const val CAPTURE_ECRAN_AUTORISEE_BUILD_DEBUG_SEULEMENT = false
}
