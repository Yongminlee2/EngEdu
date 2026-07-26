package com.piyak.english.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.VibrationEffect
import android.os.Vibrator

/** 효과음 + 진동. res/raw 의 ogg 를 재생. */
class Sfx(ctx: Context) {

    private val pool = SoundPool.Builder()
        .setMaxStreams(2)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
        ).build()

    private val vib = ctx.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator

    private fun load(ctx: Context, name: String): Int {
        val resId = ctx.resources.getIdentifier(name, "raw", ctx.packageName)
        return if (resId != 0) pool.load(ctx, resId, 1) else 0
    }

    private val sCorrect = load(ctx, "sfx_correct")
    private val sWrong = load(ctx, "sfx_wrong")
    private val sDone = load(ctx, "sfx_done")
    private val sPiyak = load(ctx, "sfx_piyak")

    fun correct() { if (sCorrect != 0) pool.play(sCorrect, 1f, 1f, 1, 0, 1f) }
    fun wrong() {
        if (sWrong != 0) pool.play(sWrong, 0.9f, 0.9f, 1, 0, 1f)
        vib?.vibrate(VibrationEffect.createOneShot(120, VibrationEffect.DEFAULT_AMPLITUDE))
    }
    fun done() { if (sDone != 0) pool.play(sDone, 1f, 1f, 1, 0, 1f) }
    fun piyak() { if (sPiyak != 0) pool.play(sPiyak, 1f, 1f, 1, 0, 1f) }

    fun release() = pool.release()
}
