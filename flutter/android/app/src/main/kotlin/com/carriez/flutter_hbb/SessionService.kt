// InformaTech (OPMD Android, A1/A11, D17): keeps the viewer's process and network alive while a session is open, so
// the session survives screen off, the app in the background and a 4G <-> Wi-Fi switch (the engine reconnects by
// itself). Started when the remote page opens, stopped when it closes; never started otherwise. It holds no secret.
package com.carriez.flutter_hbb

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

class SessionService : Service() {
    private var verrou: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(NotificationChannel(CANAL, "Session en cours", NotificationManager.IMPORTANCE_LOW))
        }
        val ouvrir = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, CANAL) else Notification.Builder(this)
        val n = b.setContentTitle("Session InformaTech en cours")
            .setContentText("Touchez pour revenir à la session.")
            .setSmallIcon(R.drawable.ic_stat_logo)
            .setOngoing(true)
            .setContentIntent(ouvrir)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(ID, n)
        }
        if (verrou == null) {
            verrou = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "informatech:session")
                .apply { acquire(MAX_MS) }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        verrou?.let { if (it.isHeld) it.release() }
        verrou = null
        super.onDestroy()
    }

    companion object {
        private const val CANAL = "informatech_session"
        private const val ID = 4711
        /** A session lasts 6 h + 2 h at most (D18/D19): the CPU lock never outlives that. */
        private const val MAX_MS = 8L * 60 * 60 * 1000

        fun demarrer(c: Context) {
            val i = Intent(c, SessionService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) c.startForegroundService(i) else c.startService(i)
        }

        fun arreter(c: Context) {
            c.stopService(Intent(c, SessionService::class.java))
        }
    }
}
