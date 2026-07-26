package com.piyak.english.audio

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale

/** 영어 TTS 래퍼. 대화문은 화자별 피치를 바꿔 2인 연출. */
class Tts(ctx: Context, private val onReady: (Boolean) -> Unit = {}) {

    private var tts: TextToSpeech? = null
    var ready = false
        private set
    var rate = 1.0f // 사용자 설정 속도

    private val main = Handler(Looper.getMainLooper())
    private var seq = 0
    private var pending: List<Pair<Float, String>> = emptyList()
    private var pendingIdx = 0
    private var onQueueDone: (() -> Unit)? = null

    init {
        tts = TextToSpeech(ctx.applicationContext) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (ready) {
                val r = tts?.setLanguage(Locale.US)
                if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) ready = false
            }
            if (ready) {
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(id: String?) {}
                    override fun onError(id: String?) { main.post { nextInQueue() } }
                    override fun onDone(id: String?) { main.post { nextInQueue() } }
                })
            }
            main.post { onReady(ready) }
        }
    }

    /** 단문 재생. slow=true 면 절반 속도(거북이 버튼). */
    fun speak(text: String, slow: Boolean = false, pitch: Float = 1.0f) {
        val t = tts ?: return
        pending = emptyList(); onQueueDone = null
        t.stop()
        t.setPitch(pitch)
        t.setSpeechRate(if (slow) rate * 0.55f else rate)
        t.speak(text, TextToSpeech.QUEUE_FLUSH, null, "u${seq++}")
    }

    /** (피치, 문장) 목록을 순서대로 재생 — 대화문용 */
    fun speakLines(lines: List<Pair<Float, String>>, onDone: (() -> Unit)? = null) {
        val t = tts ?: return
        t.stop()
        pending = lines
        pendingIdx = 0
        onQueueDone = onDone
        playPending()
    }

    private fun playPending() {
        val t = tts ?: return
        if (pendingIdx >= pending.size) {
            pending = emptyList()
            onQueueDone?.invoke(); onQueueDone = null
            return
        }
        val (pitch, text) = pending[pendingIdx]
        t.setPitch(pitch)
        t.setSpeechRate(rate)
        t.speak(text, TextToSpeech.QUEUE_FLUSH, null, "u${seq++}")
    }

    private fun nextInQueue() {
        if (pending.isEmpty()) return
        pendingIdx++
        playPending()
    }

    fun stop() {
        pending = emptyList(); onQueueDone = null
        tts?.stop()
    }

    fun shutdown() {
        stop()
        tts?.shutdown()
        tts = null
    }
}
