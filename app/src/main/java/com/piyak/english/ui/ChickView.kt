package com.piyak.english.ui

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import android.view.animation.OvershootInterpolator
import kotlin.math.sin
import kotlin.random.Random

/**
 * 문제 화면에 상주하는 병아리.
 *
 * 정지 그림 3장(happy/neutral/sad 벡터)을 상태에 따라 바꿔 끼우고,
 * 스케일·이동·하트 파티클은 이 뷰가 직접 그린다. 아이가 문제를 푸는 동안
 * "옆에서 지켜봐 주는" 존재가 되는 것이 목적 — 그래서 평소에도 가만히 있지 않고
 * 천천히 숨을 쉰다.
 *
 * 상태: 대기(숨쉬기) / 환호(점프+하트) / 아쉬움(처짐, 1초 내 회복) / 응원(말풍선)
 */
class ChickView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : View(ctx, attrs) {

    private enum class Mood { IDLE, CHEER, OOPS, ENCOURAGE }

    private var mood = Mood.IDLE
    private var moodT = 0f          // 현재 무드의 진행도 0~1
    private var breathe = 0f        // 숨쉬기 위상

    private class Heart(var x: Float, var y: Float, var vy: Float, var life: Float, val size: Float)
    private val hearts = ArrayList<Heart>()

    private val happy = context.getDrawable(resIdOf("chick_happy"))
    private val neutral = context.getDrawable(resIdOf("chick_neutral"))
    private val sad = context.getDrawable(resIdOf("chick_sad"))

    private val bubblePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val bubbleStroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(1.5f)
        color = Color.parseColor("#FFB300")
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        color = Color.parseColor("#4E342E")
        isFakeBoldText = true
    }
    private val heartPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }

    private var anim: ValueAnimator? = null
    private var encourageText = "힘내! 🐥"

    private fun resIdOf(name: String): Int =
        resources.getIdentifier(name, "drawable", context.packageName)

    init {
        startIdle()
    }

    // ---------- 상태 전환 ----------

    /** 정답! 점프하며 하트를 뿌린다 */
    fun cheer() {
        hearts.clear()
        repeat(3) {
            hearts.add(
                Heart(
                    x = width * (0.25f + Random.nextFloat() * 0.5f),
                    y = height * 0.35f,
                    vy = -dp(0.9f + Random.nextFloat() * 0.6f),
                    life = 1f,
                    size = dp(10f + Random.nextFloat() * 5f),
                )
            )
        }
        play(Mood.CHEER, 1300L)
    }

    /** 오답 — 잠깐 처졌다가 금방 돌아온다 (아이가 기죽지 않게 짧게) */
    fun oops() = play(Mood.OOPS, 1000L)

    /** 오래 고민 중 — 응원 말풍선 */
    fun encourage() {
        encourageText = listOf("힘내! 🐥", "천천히 해도 돼!", "삐약! 할 수 있어!").random()
        play(Mood.ENCOURAGE, 2600L)
    }

    private fun play(m: Mood, duration: Long) {
        anim?.cancel()
        mood = m
        moodT = 0f
        anim = ValueAnimator.ofFloat(0f, 1f).apply {
            this.duration = duration
            if (m == Mood.CHEER) interpolator = OvershootInterpolator(1.4f)
            addUpdateListener { moodT = it.animatedValue as Float; invalidate() }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) = startIdle()
            })
            start()
        }
    }

    private fun startIdle() {
        anim?.cancel()
        mood = Mood.IDLE
        anim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2400L
            repeatCount = ValueAnimator.INFINITE
            addUpdateListener { breathe = it.animatedValue as Float; invalidate() }
            start()
        }
    }

    // ---------- 그리기 ----------

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val d = when (mood) {
            Mood.CHEER -> happy
            Mood.OOPS -> sad
            else -> neutral
        } ?: return

        // 병아리는 오른쪽에 붙이고, 말풍선이 왼쪽으로 뻗을 자리를 남긴다
        val base = height.toFloat()
        var size = base * 0.78f
        val cx = width - base * 0.5f
        var cy = height * 0.60f

        when (mood) {
            Mood.IDLE -> {
                // 천천히 숨쉬기 — 살아 있다는 느낌만, 시선을 뺏지 않게 아주 작게
                size *= 1f + 0.035f * sin(breathe * Math.PI * 2).toFloat()
            }
            Mood.CHEER -> {
                // 점프 (사인 반 주기) + 살짝 커짐
                cy -= base * 0.16f * sin(moodT * Math.PI).toFloat()
                size *= 1.08f
            }
            Mood.OOPS -> {
                // 처짐: 내려갔다가 스르륵 복귀
                val droop = sin(moodT * Math.PI).toFloat()
                cy += base * 0.08f * droop
                size *= 1f - 0.06f * droop
            }
            Mood.ENCOURAGE -> {
                size *= 1f + 0.03f * sin(moodT * Math.PI * 4).toFloat()
            }
        }

        val half = (size / 2f).toInt()
        d.setBounds((cx - half).toInt(), (cy - half).toInt(), (cx + half).toInt(), (cy + half).toInt())
        d.draw(canvas)

        // 하트 (환호) — 병아리 주변에서 떠오른다
        if (mood == Mood.CHEER) {
            val it2 = hearts.iterator()
            while (it2.hasNext()) {
                val h = it2.next()
                h.y += h.vy
                h.life = 1f - moodT
                if (h.life <= 0f) { it2.remove(); continue }
                heartPaint.textSize = h.size
                heartPaint.alpha = (255 * h.life).toInt()
                canvas.drawText("💛", cx - base * 0.5f + h.x * 0.3f, h.y, heartPaint)
            }
            heartPaint.alpha = 255
        }

        // 응원 말풍선 — 병아리 왼쪽으로 뻗는다 (위는 자리가 없다)
        if (mood == Mood.ENCOURAGE) {
            val fade = when {
                moodT < 0.15f -> moodT / 0.15f
                moodT > 0.85f -> (1f - moodT) / 0.15f
                else -> 1f
            }
            textPaint.textSize = dp(11f)
            val tw = textPaint.measureText(encourageText) + dp(14f)
            val right = cx - size / 2f - dp(4f)
            val left = (right - tw).coerceAtLeast(0f)
            val byTop = cy - dp(11f)
            val byBottom = cy + dp(9f)
            bubblePaint.alpha = (255 * fade).toInt()
            bubbleStroke.alpha = (255 * fade).toInt()
            textPaint.alpha = (255 * fade).toInt()
            canvas.drawRoundRect(left, byTop, right, byBottom, dp(10f), dp(10f), bubblePaint)
            canvas.drawRoundRect(left, byTop, right, byBottom, dp(10f), dp(10f), bubbleStroke)
            canvas.drawText(encourageText, (left + right) / 2f, byBottom - dp(6f), textPaint)
            bubblePaint.alpha = 255; bubbleStroke.alpha = 255; textPaint.alpha = 255
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        anim?.cancel()
    }

    private fun dp(v: Float): Float = v * resources.displayMetrics.density
}
