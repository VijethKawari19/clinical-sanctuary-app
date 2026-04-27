package com.clinicalsanc.clinical_sanctuary_app

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayOutputStream
import java.util.concurrent.ConcurrentHashMap
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import org.videolan.libvlc.util.VLCVideoLayout

class M83VlcPlayerViewFactory(
    private val binaryMessenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val url = params?.get("url") as? String ?: ""
        return M83VlcPlayerView(
            context,
            viewId,
            url,
            MethodChannel(binaryMessenger, CHANNEL_NAME),
        )
    }

    companion object {
        const val VIEW_TYPE = "clinical_sanctuary/m83_vlc_player"
        const val CHANNEL_NAME = "clinical_sanctuary/m83_vlc_player"
    }
}

object M83VlcPlayerRegistry {
    private val views = ConcurrentHashMap<Int, M83VlcPlayerView>()

    fun register(viewId: Int, view: M83VlcPlayerView) {
        views[viewId] = view
    }

    fun unregister(viewId: Int) {
        views.remove(viewId)
    }

    fun takeSnapshot(viewId: Int, result: MethodChannel.Result) {
        val view = views[viewId]
        if (view == null) {
            result.error("vlc_view_missing", "VLC preview is not ready.", null)
            return
        }
        view.takeSnapshot(result)
    }
}

class M83VlcPlayerView(
    context: Context,
    private val viewId: Int,
    private val streamUrl: String,
    private val channel: MethodChannel,
) : PlatformView {
    private val appContext: Context = context.applicationContext
    private val root = FrameLayout(context)
    private val handler = Handler(Looper.getMainLooper())

    private var libVlc: LibVLC? = null
    private var mediaPlayer: MediaPlayer? = null
    private var videoLayout: VLCVideoLayout? = null
    private var disposed = false

    init {
        root.setBackgroundColor(0xFF000000.toInt())
        M83VlcPlayerRegistry.register(viewId, this)

        try {
            videoLayout = VLCVideoLayout(context).also { layout ->
                root.addView(
                    layout,
                    FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT,
                    ),
                )
            }

            val vlc = LibVLC(
                appContext,
                arrayListOf(
                    "--no-audio",
                    "--network-caching=300",
                    "--clock-jitter=0",
                    "--drop-late-frames",
                    "--skip-frames",
                ),
            )
            val player = MediaPlayer(vlc)
            libVlc = vlc
            mediaPlayer = player

            start(vlc, player)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to initialise LibVLC", t)
            reportError(t)
        }
    }

    private fun start(vlc: LibVLC, player: MediaPlayer) {
        if (streamUrl.isBlank()) return
        val layout = videoLayout ?: return

        try {
            // useTextureView = true keeps the surface inside Flutter's AndroidView
            // virtual display and avoids the SurfaceView crash on some chipsets.
            player.attachViews(layout, null, false, true)

            val media = Media(vlc, Uri.parse(streamUrl))
            media.setHWDecoderEnabled(true, false)
            media.addOption(":network-caching=300")
            media.addOption(":http-reconnect")
            media.addOption(":no-audio")
            media.addOption(":drop-late-frames")
            media.addOption(":skip-frames")
            player.media = media
            media.release()

            player.play()
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to start VLC playback", t)
            reportError(t)
        }
    }

    private fun reportError(t: Throwable) {
        if (disposed) return
        val message = t.message ?: t.javaClass.simpleName
        handler.post {
            if (disposed) return@post
            try {
                channel.invokeMethod(
                    "vlcError",
                    mapOf("viewId" to viewId, "message" to message),
                )
            } catch (_: Throwable) {
            }
        }
    }

    fun takeSnapshot(result: MethodChannel.Result) {
        handler.post {
            try {
                val textureView = findTextureView(root)
                if (textureView != null && textureView.width > 0 && textureView.height > 0) {
                    val bitmap = textureView.bitmap
                    if (bitmap != null) {
                        result.success(encodePng(bitmap))
                        return@post
                    }
                }

                val surfaceView = findSurfaceView(root)
                if (
                    surfaceView != null &&
                    surfaceView.width > 0 &&
                    surfaceView.height > 0 &&
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ) {
                    val bitmap = Bitmap.createBitmap(
                        surfaceView.width,
                        surfaceView.height,
                        Bitmap.Config.ARGB_8888,
                    )
                    PixelCopy.request(
                        surfaceView,
                        bitmap,
                        { copyResult ->
                            if (copyResult == PixelCopy.SUCCESS) {
                                result.success(encodePng(bitmap))
                            } else {
                                bitmap.recycle()
                                result.error(
                                    "snapshot_failed",
                                    "Could not copy the VLC video frame.",
                                    null,
                                )
                            }
                        },
                        handler,
                    )
                    return@post
                }

                val bitmap = captureBitmap(root)
                if (bitmap == null || bitmap.width <= 0 || bitmap.height <= 0) {
                    result.error("snapshot_empty", "VLC preview frame is not ready yet.", null)
                    return@post
                }
                result.success(encodePng(bitmap))
            } catch (e: Exception) {
                result.error("snapshot_error", e.message, null)
            }
        }
    }

    private fun captureBitmap(view: View): Bitmap? {
        if (view.width <= 0 || view.height <= 0) return null
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        view.draw(canvas)
        return bitmap
    }

    private fun findTextureView(view: View): TextureView? {
        if (view is TextureView) return view
        if (view !is ViewGroup) return null
        for (i in 0 until view.childCount) {
            val child = findTextureView(view.getChildAt(i))
            if (child != null) return child
        }
        return null
    }

    private fun findSurfaceView(view: View): SurfaceView? {
        if (view is SurfaceView) return view
        if (view !is ViewGroup) return null
        for (i in 0 until view.childCount) {
            val child = findSurfaceView(view.getChildAt(i))
            if (child != null) return child
        }
        return null
    }

    private fun encodePng(bitmap: Bitmap): ByteArray {
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        bitmap.recycle()
        return out.toByteArray()
    }

    override fun getView(): View = root

    override fun dispose() {
        disposed = true
        M83VlcPlayerRegistry.unregister(viewId)
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.detachViews()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {
        }
        try {
            libVlc?.release()
        } catch (_: Exception) {
        }
        mediaPlayer = null
        libVlc = null
        videoLayout = null
    }

    companion object {
        private const val TAG = "M83VlcPlayerView"
    }
}
