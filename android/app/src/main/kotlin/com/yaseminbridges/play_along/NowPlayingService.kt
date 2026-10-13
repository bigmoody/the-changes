// The band in the notification shade, and on the lock screen.
//
// Android needs more than iOS does for the same thing. There, saying
// what is playing is enough and the system draws the card. Here it takes
// a media session, so the system knows there is something to control,
// and a foreground service, so the app is allowed to go on making a
// sound once it is no longer the thing on screen. Without the service
// the band would stop a few seconds after the phone was pocketed, which
// is the opposite of what this is for.
//
// The service holds no audio of its own. The sound is made in the app's
// own process by the audio engine, exactly as it was; this is only the
// part that tells the system about it and passes the buttons back.

package com.yaseminbridges.play_along

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
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat

class NowPlayingService : Service() {
  companion object {
    const val CHANNEL_ID = "the_changes_band"
    const val NOTIFICATION_ID = 1

    const val ACTION_SHOW = "com.yaseminbridges.play_along.SHOW"
    const val ACTION_PLAY = "com.yaseminbridges.play_along.PLAY"
    const val ACTION_PAUSE = "com.yaseminbridges.play_along.PAUSE"
    const val ACTION_STOP = "com.yaseminbridges.play_along.STOP"

    const val EXTRA_TITLE = "title"
    const val EXTRA_LINE = "line"
    const val EXTRA_PLAYING = "playing"

    /// Where a pressed button goes: set by the bridge while the app is
    /// alive, and cleared when it is not. Nothing is sent to a Flutter
    /// engine that has gone away.
    var commands: ((String) -> Unit)? = null
  }

  private lateinit var session: MediaSessionCompat
  private var playing = true
  private var title = ""
  private var line = ""

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    makeChannel()
    session = MediaSessionCompat(this, "TheChanges").apply {
      setCallback(object : MediaSessionCompat.Callback() {
        override fun onPlay() = send("play")
        override fun onPause() = send("pause")
        override fun onStop() = send("stop")
      })
      isActive = true
    }
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_SHOW -> {
        title = intent.getStringExtra(EXTRA_TITLE) ?: ""
        line = intent.getStringExtra(EXTRA_LINE) ?: ""
        playing = intent.getBooleanExtra(EXTRA_PLAYING, true)
        publish()
      }
      // The buttons on the notification itself, which come back here
      // rather than through the session.
      ACTION_PLAY -> send("play")
      ACTION_PAUSE -> send("pause")
      ACTION_STOP -> send("stop")
    }
    return START_NOT_STICKY
  }

  override fun onDestroy() {
    takeItDown()
    session.isActive = false
    session.release()
    super.onDestroy()
  }

  private fun send(command: String) {
    commands?.invoke(command)
  }

  private fun publish() {
    session.setMetadata(
      MediaMetadataCompat.Builder()
        .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
        .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, line)
        .build()
    )
    session.setPlaybackState(
      PlaybackStateCompat.Builder()
        .setActions(
          PlaybackStateCompat.ACTION_PLAY or
            PlaybackStateCompat.ACTION_PAUSE or
            PlaybackStateCompat.ACTION_PLAY_PAUSE or
            PlaybackStateCompat.ACTION_STOP
        )
        // No position and no length. The band is a loop that runs until
        // you stop it, and a progress bar would have to invent an end.
        .setState(
          if (playing) PlaybackStateCompat.STATE_PLAYING
          else PlaybackStateCompat.STATE_PAUSED,
          PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN,
          1f
        )
        .build()
    )
    val notification = build()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      startForeground(
        NOTIFICATION_ID,
        notification,
        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
      )
    } else {
      startForeground(NOTIFICATION_ID, notification)
    }
  }

  /// Drops the notification. Called on the way out, since the service
  /// is stopped rather than asked to stop.
  private fun takeItDown() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      stopForeground(STOP_FOREGROUND_REMOVE)
    } else {
      @Suppress("DEPRECATION")
      stopForeground(true)
    }
  }

  private fun build(): Notification {
    val open = PendingIntent.getActivity(
      this,
      0,
      Intent(this, MainActivity::class.java),
      PendingIntent.FLAG_IMMUTABLE
    )
    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setSmallIcon(android.R.drawable.ic_media_play)
      .setContentTitle(title)
      .setContentText(line)
      .setContentIntent(open)
      .setOngoing(playing)
      .setShowWhen(false)
      .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
      .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
      .addAction(
        if (playing) android.R.drawable.ic_media_pause
        else android.R.drawable.ic_media_play,
        if (playing) "Pause" else "Play",
        self(if (playing) ACTION_PAUSE else ACTION_PLAY)
      )
      .addAction(
        android.R.drawable.ic_menu_close_clear_cancel,
        "Stop",
        self(ACTION_STOP)
      )
      .setStyle(
        androidx.media.app.NotificationCompat.MediaStyle()
          .setMediaSession(session.sessionToken)
          .setShowActionsInCompactView(0, 1)
      )
      .build()
  }

  private fun self(action: String): PendingIntent = PendingIntent.getService(
    this,
    action.hashCode(),
    Intent(this, NowPlayingService::class.java).setAction(action),
    PendingIntent.FLAG_IMMUTABLE
  )

  private fun makeChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (manager.getNotificationChannel(CHANNEL_ID) != null) return
    val channel = NotificationChannel(
      CHANNEL_ID,
      "The Band",
      // Low: it is a control panel rather than news. A practice session
      // that pinged every time you pressed play would be unbearable.
      NotificationManager.IMPORTANCE_LOW
    ).apply {
      description = "Controls for the band while it plays"
      setShowBadge(false)
    }
    manager.createNotificationChannel(channel)
  }
}
