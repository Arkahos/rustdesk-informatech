// InformaTech (OPMD Android, A1): the only way a session starts in « InformaTech Assistance ».
//
// Reached through the activity-alias fr.informatech.assistance.ConnexionActivity (AndroidManifest.xml), guarded by the
// signature-level permission fr.informatech.assistance.permission.CONNECTER: only « InformaTech Admin » signed with the
// same certificate can start it. Contract: Hub repo, mobile-admin/plugins/lanceur-visionneuse/src/lib.rs.
//
// - CONNECTER: extras « id » (digits) and « motDePasse » (one-shot), read once, removed from the intent, kept in memory
//   only until Flutter takes them (informatech_connexion), never written, logged or put in a URI.
// - FERMER: closes the session window.
package com.carriez.flutter_hbb

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager

class ConnexionActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        traiter(intent)
        finish()
    }

    private fun traiter(i: Intent?) {
        when (i?.action) {
            ACTION_CONNECTER -> {
                val id = i.getStringExtra("id").orEmpty()
                val mot = i.getStringExtra("motDePasse").orEmpty()
                i.removeExtra("id")
                i.removeExtra("motDePasse")
                if (!idValide(id) || mot.isEmpty() || mot.length > 128) return
                ConnexionEnAttente.deposer(id, mot)
                startActivity(
                    Intent(this, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                )
                MainActivity.flutterMethodChannel?.invokeMethod("informatech_connexion_prete", null)
            }
            ACTION_FERMER -> {
                ConnexionEnAttente.vider()
                MainActivity.flutterMethodChannel?.invokeMethod("informatech_fermer", null)
            }
        }
    }

    companion object {
        const val ACTION_CONNECTER = "fr.informatech.assistance.action.CONNECTER"
        const val ACTION_FERMER = "fr.informatech.assistance.action.FERMER"

        fun idValide(id: String): Boolean = id.length in 6..16 && id.all { it in '0'..'9' }
    }
}

/** One pending session, in memory only, taken once. */
object ConnexionEnAttente {
    private var id: String? = null
    private var motDePasse: String? = null

    @Synchronized
    fun deposer(i: String, m: String) {
        id = i
        motDePasse = m
    }

    @Synchronized
    fun prendre(): Map<String, String>? {
        val i = id ?: return null
        val m = motDePasse ?: return null
        vider()
        return mapOf("id" to i, "motDePasse" to m)
    }

    @Synchronized
    fun vider() {
        id = null
        motDePasse = null
    }
}
