package com.mohalla.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Reschedules Azan notifications after a phone restart, without
 * opening the app UI. Runs the `bootReschedule` Dart entrypoint
 * (lib/boot_reschedule.dart) in a headless FlutterEngine, then
 * shuts the engine down. If there is no cached GPS location it
 * does nothing — the next app launch reschedules as usual.
 *
 * Never throws: a boot receiver must never crash the boot sequence.
 * goAsync() keeps the broadcast alive while the Dart code runs.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val pending = goAsync()
        try {
            val engine = FlutterEngine(context)
            val entrypoint = DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "bootReschedule",
            )
            engine.dartExecutor.executeDartEntrypoint(entrypoint)
            // Give the Dart code time to read settings + reschedule,
            // then shut the engine down and finish the broadcast.
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    engine.destroy()
                } catch (_) {
                }
                try {
                    pending.finish()
                } catch (_) {
                }
            }, 20000)
        } catch (_) {
            try {
                pending.finish()
            } catch (_) {
            }
        }
    }
}
