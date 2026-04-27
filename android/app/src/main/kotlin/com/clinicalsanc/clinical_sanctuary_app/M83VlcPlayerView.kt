package com.clinicalsanc.clinical_sanctuary_app

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.TextureView
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
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

class M83VlcPlayerViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val url = params?.get("url") as? String ?: ""
        return M83VlcPlayerView(context, viewId, url)
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
    private val context: Context,
    private val viewId: Int,
    private val streamUrl: String,
) : PlatformView {
    private val root = FrameLayout(context)
    private val videoLayout = VLCVideoLayout(context)
    private val handler = Handler(Looper.getMainLooper())
    private val libVlc = LibVLC(
        context,
        arrayListOf(
            "--no-audio",
            "--network-caching=250",
            "--clock-jitter=0",
            "--drop-late-frames",
            "--skip-frames",
        ),
    )
    private val mediaPlayer = MediaPlayer(libVlc)

    init {
        root.addView(
            videoLayout,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
            ),
        )
        M83VlcPlayerRegistry.register(viewId, this)
        start()
    }

    private fun start() {
        if (streamUrl.isBlank()) return

        mediaPlayer.attachViews(videoLayout, null, false, false)
        val media = Media(libVlc, Uri.parse(streamUrl))
        media.setHWDecoderEnabled(true, false)
        media.addOption(":network-caching=250")
        media.addOption(":http-reconnect")
        media.addOption(":rtsp-tcp")
        media.addOption(":no-audio")
        media.addOption(":drop-late-frames")
        media.addOption(":skip-frames")
        mediaPlayer.media = media
        media.release()
        mediaPlayer.play()
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
        M83VlcPlayerRegistry.unregister(viewId)
        try {
            mediaPlayer.stop()
        } catch (_: Exception) {
        }
        try {
            mediaPlayer.detachViews()
        } catch (_: Exception) {
        }
        mediaPlayer.release()
        libVlc.release()
    }
}
