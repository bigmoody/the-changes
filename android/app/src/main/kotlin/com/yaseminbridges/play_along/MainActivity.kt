package com.yaseminbridges.play_along

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// The app, and the one channel it owns: the band's controls in the
/// notification shade and on the lock screen.
///
/// The service does the work. This decides when there should be one at
/// all, and carries the buttons back to Dart, where what they mean is
/// decided.
class MainActivity : FlutterActivity() {
  private var channel: MethodChannel? = null

  override fun configureFlutterEngine(engine: FlutterEngine) {
    super.configureFlutterEngine(engine)
    val channel = MethodChannel(
      engine.dartExecutor.binaryMessenger,
      "the_changes/now_playing"
    )
    this.channel = channel
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "show" -> {
          askAboutNotifications()
          val intent = Intent(this, NowPlayingService::class.java)
            .setAction(NowPlayingService.ACTION_SHOW)
            .putExtra(
              NowPlayingService.EXTRA_TITLE,
              call.argument<String>("title") ?: ""
            )
            .putExtra(
              NowPlayingService.EXTRA_LINE,
              call.argument<String>("line") ?: ""
            )
            .putExtra(
              NowPlayingService.EXTRA_PLAYING,
              call.argument<Boolean>("playing") ?: true
            )
          NowPlayingService.commands = { command ->
            runOnUiThread { this.channel?.invokeMethod(command, null) }
          }
          // Android refuses a foreground service started from the
          // background in some states. Refused, there is no card and the
          // band plays on, which is what the app did before any of this.
          runCatching { ContextCompat.startForegroundService(this, intent) }
          result.success(null)
        }
        "hide" -> {
          // Stopped rather than told to stop. Starting a service to ask
          // it to go away is refused outright when the app is in the
          // background, which is exactly when a tune most often ends,
          // and the notification goes with the service anyway.
          stopService(Intent(this, NowPlayingService::class.java))
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }
  }

  override fun onDestroy() {
    // Nothing is sent to an engine that has gone away.
    NowPlayingService.commands = null
    channel = null
    super.onDestroy()
  }

  /// Asked for the first time a card goes up rather than at launch: it
  /// is a question about something you are in the middle of doing, which
  /// is the only time it makes sense.
  ///
  /// Refused, the band still plays and still holds the audio; there is
  /// simply nothing in the shade to press.
  private fun askAboutNotifications() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
    val granted = ContextCompat.checkSelfPermission(
      this,
      Manifest.permission.POST_NOTIFICATIONS
    ) == PackageManager.PERMISSION_GRANTED
    if (granted) return
    ActivityCompat.requestPermissions(
      this,
      arrayOf(Manifest.permission.POST_NOTIFICATIONS),
      1
    )
  }
}
