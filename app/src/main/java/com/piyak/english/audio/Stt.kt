package com.piyak.english.audio

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

/** 영어 음성인식 래퍼 (말하기 채점용) */
class Stt(private val ctx: Context) {

    private var recognizer: SpeechRecognizer? = null
    var listening = false
        private set

    fun available(): Boolean = SpeechRecognizer.isRecognitionAvailable(ctx)

    fun start(onResult: (String) -> Unit, onError: (Int) -> Unit, onLevel: (Float) -> Unit = {}) {
        stop()
        if (!available()) { onError(-1); return }
        val r = SpeechRecognizer.createSpeechRecognizer(ctx)
        recognizer = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) { onLevel(rmsdB) }
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() { listening = false }
            override fun onError(error: Int) { listening = false; onError(error) }
            override fun onResults(results: Bundle?) {
                listening = false
                val list = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                onResult(list?.firstOrNull() ?: "")
            }
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
        }
        listening = true
        r.startListening(intent)
    }

    fun stop() {
        listening = false
        recognizer?.destroy()
        recognizer = null
    }
}
