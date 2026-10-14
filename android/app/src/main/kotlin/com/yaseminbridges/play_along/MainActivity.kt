package com.yaseminbridges.play_along

import android.Manifest
import android.content.Intent
import android.net.Uri
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
  private var shared: MethodChannel? = null

  /// A chart that arrived before Dart was listening, which is every
  /// share that starts the app rather than arriving at a running one.
  private var waiting: String? = null

  /// Whether Dart has asked what opened the app. Before it does, a chart
  /// is held; after, it is sent straight over. Doing both would import
  /// the same thing twice.
  private var asked = false

  override fun configureFlutterEngine(engine: FlutterEngine) {
    super.configureFlutterEngine(engine)
    val shared = MethodChannel(
      engine.dartExecutor.binaryMessenger,
      "the_changes/shared"
    )
    this.shared = shared
    shared.setMethodCallHandler { call, result ->
      when (call.method) {
        // Handed over once and then forgotten, or every trip through the
        // library would open the same import again.
        "initial" -> {
          asked = true
          result.success(waiting)
          waiting = null
        }
        else -> result.notImplemented()
      }
    }
    took(intent)
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

  /// A share arriving at an app that is already running.
  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    took(intent)
  }

  /// The chart in [intent], if it carries one: the text of a share, or
  /// the link itself where one was tapped.
  private fun took(intent: Intent?) {
    val text = when (intent?.action) {
      // A share is either the link as text or a file holding one.
      Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
        ?: intent.parcelable(Intent.EXTRA_STREAM)?.let { contentsOf(it) }
      // And an opened file is a file; an opened link is itself.
      Intent.ACTION_VIEW -> intent.data?.let { uri ->
        if (uri.scheme == "content" || uri.scheme == "file") contentsOf(uri)
        else uri.toString()
      }
      else -> null
    }
    if (text.isNullOrBlank()) return
    val channel = shared
    if (asked && channel != null) {
      channel.invokeMethod("shared", text)
    } else {
      waiting = text
    }
  }

  /// The text of a file somebody chose to open here, read for the links
  /// in it: a page with them in counts.
  private fun contentsOf(uri: Uri): String? = try {
    contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
  } catch (e: Exception) {
    null
  }

  /// The stream a share carries, without the deprecation on newer
  /// Android and without losing it on older.
  private fun Intent.parcelable(name: String): Uri? =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      getParcelableExtra(name, Uri::class.java)
    } else {
      @Suppress("DEPRECATION")
      getParcelableExtra(name)
    }

  override fun onDestroy() {
    // Nothing is sent to an engine that has gone away.
    NowPlayingService.commands = null
    channel = null
    shared = null
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
