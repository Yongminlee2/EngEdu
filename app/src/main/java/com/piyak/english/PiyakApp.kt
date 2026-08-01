package com.piyak.english

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.WeakHashMap

/**
 * 앱이 죽으면 그 이유를 파일에 남긴다.
 *
 * 폰이 USB 로 계속 붙어 있지 않아 `adb logcat` 으로 스택을 못 잡는 일이 잦았다.
 * 앱이 스스로 적어 두면 나중에 설정 화면에서 꺼내 볼 수 있다.
 */
class PiyakApp : Application() {

    override fun onCreate() {
        super.onCreate()
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            runCatching { save(thread, error) }
            // 원래 처리(앱 종료·시스템 보고)는 그대로 이어 준다
            previous?.uncaughtException(thread, error)
        }
        registerActivityLifecycleCallbacks(insetCallbacks)
    }

    private val insetViews = java.util.Collections.newSetFromMap(WeakHashMap<View, Boolean>())

    private val insetCallbacks = object : ActivityLifecycleCallbacks {
        override fun onActivityCreated(activity: Activity, state: Bundle?) {
            WindowCompat.setDecorFitsSystemWindows(activity.window, false)
            val content = activity.findViewById<View>(android.R.id.content) ?: return
            if (!insetViews.add(content)) return
            val initial = intArrayOf(
                content.paddingLeft, content.paddingTop,
                content.paddingRight, content.paddingBottom
            )
            ViewCompat.setOnApplyWindowInsetsListener(content) { view, insets ->
                val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
                view.setPadding(
                    initial[0] + bars.left, initial[1] + bars.top,
                    initial[2] + bars.right, initial[3] + bars.bottom
                )
                insets
            }
            ViewCompat.requestApplyInsets(content)
        }

        override fun onActivityStarted(activity: Activity) = Unit
        override fun onActivityResumed(activity: Activity) = Unit
        override fun onActivityPaused(activity: Activity) = Unit
        override fun onActivityStopped(activity: Activity) = Unit
        override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit
        override fun onActivityDestroyed(activity: Activity) = Unit
    }

    private fun save(thread: Thread, error: Throwable) {
        val sw = StringWriter()
        error.printStackTrace(PrintWriter(sw))
        val when_ = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.KOREA).format(Date())
        val version = runCatching {
            packageManager.getPackageInfo(packageName, 0).versionName
        }.getOrNull() ?: "?"
        crashFile(this).writeText(
            "때: $when_\n스레드: ${thread.name}\n앱: $version\n\n$sw"
        )
    }

    companion object {
        fun crashFile(app: android.content.Context): File = File(app.filesDir, "last_crash.txt")

        /** 마지막으로 죽은 기록 (없으면 null) */
        fun lastCrash(app: android.content.Context): String? =
            crashFile(app).takeIf { it.isFile }?.readText()?.ifBlank { null }

        fun clearCrash(app: android.content.Context) {
            crashFile(app).delete()
        }
    }
}
