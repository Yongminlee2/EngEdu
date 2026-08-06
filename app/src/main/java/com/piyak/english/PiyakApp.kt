package com.piyak.english

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.view.View
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 앱이 죽으면 그 이유를 파일에 남긴다.
 *
 * 폰이 USB 로 계속 붙어 있지 않아 `adb logcat` 으로 스택을 못 잡는 일이 잦았다.
 * 앱이 스스로 적어 두면 나중에 설정 화면에서 꺼내 볼 수 있다.
 */
class PiyakApp : Application() {

    override fun onCreate() {
        super.onCreate()
        fitSystemBarsEverywhere()
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            runCatching { save(thread, error) }
            // 원래 처리(앱 종료·시스템 보고)는 그대로 이어 준다
            previous?.uncaughtException(thread, error)
        }
    }

    /**
     * 모든 화면이 시스템 바(상태바·내비게이션 바)를 피해 그려지게 한다.
     *
     * targetSdk 35 부터 안드로이드는 앱을 **시스템 바 뒤까지** 그리게 강제한다.
     * 여백을 스스로 주지 않으면 위로는 시계·배터리가 앱의 첫 줄과 겹치고,
     * 아래로는 내비게이션 바가 '확인' 버튼을 덮는다.
     * 안드로이드 14 이하에서는 강제가 없어 멀쩡해 보이므로 구형 폰 검증만으로는 못 잡는다.
     *
     * 화면마다 넣지 않고 여기 한 곳에서 건다 — 빠뜨릴 여지를 없애려고.
     */
    private fun fitSystemBarsEverywhere() {
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, saved: Bundle?) {
                // findViewById 가 decor 를 만들어 주므로 setContentView 전에도 잡힌다.
                val content = activity.findViewById<View>(android.R.id.content) ?: return
                ViewCompat.setOnApplyWindowInsetsListener(content) { view, insets ->
                    // 키보드(ime)도 함께 본다 — 안 그러면 쓰기 문제에서 키보드가
                    // 입력칸을 덮는다. edge-to-edge 에서는 adjustResize 가 안 먹는다.
                    val bars = insets.getInsets(
                        WindowInsetsCompat.Type.systemBars() or
                            WindowInsetsCompat.Type.displayCutout() or
                            WindowInsetsCompat.Type.ime()
                    )
                    view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
                    WindowInsetsCompat.CONSUMED
                }
            }

            override fun onActivityStarted(activity: Activity) {}
            override fun onActivityResumed(activity: Activity) {}
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, out: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
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
