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
import kotlin.random.Random

/**
 * 정답 축하 오버레이 — 색종이 + 콤보 배지.
 * 전체 화면 위에 떠 있지만 터치는 전부 아래로 통과한다 (onTouchEvent 없음).
 *
 * 색종이 물리는 알파벳 따라쓰기(TraceView) 축하와 같은 방식:
 * 위로 쏘아 올리고 중력으로 떨어뜨리며 회전.
 */
class CelebrateOverlayView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : View(ctx, attrs) {

    private class Confetti(
        var x: Float, var y: Float, var vx: Float, var vy: Float,
        val color: Int, val size: Float, var rot: Float, val spin: Float,
    )

    private val confetti = ArrayList<Confetti>()
    private var confettiAnim: ValueAnimator? = null

    private var comboText = ""
    private var comboT = 0f
    private var comboAnim: ValueAnimator? = null

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val comboPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
        color = Color.parseColor("#FF7043")
    }
    private val comboOutline = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
        style = Paint.Style.STROKE
        strokeWidth = dp(3f)
        color = Color.WHITE
    }

    private val colors = listOf(
        "#FFD54F", "#FF8A80", "#80CBC4", "#81D4FA", "#B39DDB", "#66BB6A",
    ).map { Color.parseColor(it) }

    /**
     * 정답 축하. [combo] 가 2 이상이면 "🔥 N연속!" 배지도 띄운다.
     * 5연속부터는 색종이가 많아진다.
     */
    fun correct(combo: Int) {
        burst(if (combo >= 5) 32 else 18)
        if (combo >= 2) showCombo("🔥 ${combo}연속!")
    }

    private fun burst(count: Int) {
        val cx = width / 2f
        val cy = height * 0.42f
        repeat(count) {
            confetti.add(
                Confetti(
                    x = cx + (Random.nextFloat() - 0.5f) * width * 0.4f,
                    y = cy,
                    vx = (Random.nextFloat() - 0.5f) * dp(5f),
                    vy = -Random.nextFloat() * dp(6f) - dp(2f),
                    color = colors[Random.nextInt(colors.size)],
                    size = dp(4f) + Random.nextFloat() * dp(4f),
                    rot = Random.nextFloat() * 360f,
                    spin = (Random.nextFloat() - 0.5f) * 22f,
                )
            )
        }
        if (confettiAnim?.isRunning != true) {
            confettiAnim = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 1300L
                addUpdateListener {
                    for (c in confetti) {
                        c.x += c.vx
                        c.y += c.vy
                        c.vy += dp(0.28f)
                        c.rot += c.spin
                    }
                    invalidate()
                }
                addListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        confetti.clear(); invalidate()
                    }
                })
                start()
            }
        }
    }

    private fun showCombo(text: String) {
        comboText = text
        comboAnim?.cancel()
        comboAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1100L
            interpolator = OvershootInterpolator(2.2f)
            addUpdateListener { comboT = it.animatedValue as Float; invalidate() }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    comboText = ""; invalidate()
                }
            })
            start()
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        for (c in confetti) {
            paint.color = c.color
            canvas.save()
            canvas.rotate(c.rot, c.x, c.y)
            canvas.drawRoundRect(
                c.x - c.size, c.y - c.size * 0.6f, c.x + c.size, c.y + c.size * 0.6f,
                c.size * 0.3f, c.size * 0.3f, paint
            )
            canvas.restore()
        }

        if (comboText.isNotEmpty()) {
            // 앞 70%: 팝인, 뒤 30%: 페이드아웃
            val scale = 0.5f + 0.5f * comboT.coerceAtMost(1f)
            val alpha = if (comboT > 0.75f) ((1f - comboT) / 0.25f * 255).toInt() else 255
            comboPaint.textSize = dp(30f) * scale
            comboOutline.textSize = comboPaint.textSize
            comboPaint.alpha = alpha.coerceIn(0, 255)
            comboOutline.alpha = alpha.coerceIn(0, 255)
            val x = width / 2f
            val y = height * 0.30f
            canvas.drawText(comboText, x, y, comboOutline)
            canvas.drawText(comboText, x, y, comboPaint)
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        confettiAnim?.cancel()
        comboAnim?.cancel()
    }

    private fun dp(v: Float): Float = v * resources.displayMetrics.density
}
