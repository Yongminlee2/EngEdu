package com.piyak.english.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.VibrationEffect
import android.os.Vibrator

/**
 * 효과음 + 진동.
 * 효과음이 TTS(듣기·말하기) 음성을 덮지 않도록 기본 볼륨을 낮게 잡는다.
 * 설정에서 0~100% 로 조절할 수 있다.
 */
class Sfx(ctx: Context) {

    companion object {
        /** 기본 30% — 이보다 크면 영어 발음이 잘 안 들린다 */
        const val DEFAULT_VOLUME_PERCENT = 30

        /**
         * 톡톡 누르는 소리(삐약)의 배율.
         * 보기를 고를 때·그림을 짚을 때마다 울리므로 정답·오답 소리보다 훨씬 작다.
         */
        const val TAP_VOLUME_SCALE = 0.25f
    }

    private val pool = SoundPool.Builder()
        .setMaxStreams(2)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        ).build()

    private val vib = ctx.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator

    /** 0.0 ~ 1.0 */
    var volume: Float =
        (com.piyak.english.db.Db.get(ctx).metaInt("sfx_volume", DEFAULT_VOLUME_PERCENT) / 100f)
            .coerceIn(0f, 1f)

    private fun load(ctx: Context, name: String): Int {
        val resId = ctx.resources.getIdentifier(name, "raw", ctx.packageName)
        return if (resId != 0) pool.load(ctx, resId, 1) else 0
    }

    private val sCorrect = load(ctx, "sfx_correct")
    private val sWrong = load(ctx, "sfx_wrong")
    private val sDone = load(ctx, "sfx_done")
    private val sPiyak = load(ctx, "sfx_piyak")

    private fun play(id: Int, scale: Float = 1f) {
        if (id == 0 || volume <= 0f) return
        val v = (volume * scale).coerceIn(0f, 1f)
        pool.play(id, v, v, 1, 0, 1f)
    }

    fun correct() = play(sCorrect)
    fun wrong() {
        play(sWrong, 0.9f)
        // 소리를 줄여도 틀린 건 알 수 있도록 진동은 남긴다
        vib?.vibrate(VibrationEffect.createOneShot(110, VibrationEffect.DEFAULT_AMPLITUDE))
    }
    fun done() = play(sDone)

    /** 톡톡 누를 때 나는 소리 */
    fun piyak() = play(sPiyak, TAP_VOLUME_SCALE)

    fun release() = pool.release()
}
