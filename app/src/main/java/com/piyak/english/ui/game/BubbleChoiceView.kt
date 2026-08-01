package com.piyak.english.ui.game

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.MotionEvent
import com.piyak.english.R
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.random.Random

/**
 * 짧은 4지선다를 시간 제한 없이 천천히 떠다니는 버블로 보여 준다.
 * 움직임은 놀이 감각만 더하고, 선택 위치와 판정 영역은 고정한다.
 */
class BubbleChoiceView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : GameView(ctx, attrs) {

    companion object {
        const val MAX_WIDTH_SCORE = 12

        fun widthScore(s: String): Int {
            var i = 0
            var score = 0
            while (i < s.length) {
                val cp = s.codePointAt(i)
                score += when {
                    cp in 0x1100..0x11FF ||
                        cp in 0x3040..0x30FF ||
                        cp in 0x3130..0x318F ||
                        cp in 0x4E00..0x9FFF ||
                        cp in 0xAC00..0xD7A3 ||
                        cp >= 0x2000 -> 2
                    else -> 1
                }
                i += Character.charCount(cp)
            }
            return score
        }

        fun fits(choices: List<String>): Boolean =
            choices.size == 4 && choices.all { widthScore(it) <= MAX_WIDTH_SCORE }
    }

    private class Bubble(
        val text: String,
        val index: Int,
        var cx: Float = 0f,
        var cy: Float = 0f,
        var baseY: Float = 0f,
        var phase: Float = 0f,
        var pop: Float = 0f,
        var color: Int = 0,
        var ringColor: Int = 0,
    )

    private val rnd = Random(System.currentTimeMillis())
    private val bubbles = ArrayList<Bubble>()
    private var selected = -1
    private var revealedAnswer = -1
    private var radius = 0f

    private val palette = listOf(
        ctx.getColor(R.color.coral_soft) to ctx.getColor(R.color.coral_deep),
        ctx.getColor(R.color.primary_soft) to ctx.getColor(R.color.primary_deep),
        ctx.getColor(R.color.mint_soft) to ctx.getColor(R.color.mint_deep),
        ctx.getColor(R.color.sky_soft) to ctx.getColor(R.color.sky_deep),
        ctx.getColor(R.color.lavender_soft) to ctx.getColor(R.color.lavender_deep),
        ctx.getColor(R.color.green_bg) to ctx.getColor(R.color.green_ok),
    )

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
    }

    var onPick: ((Int) -> Unit)? = null

    init {
        isClickable = true
        isFocusable = true
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
    }

    fun setChoices(choices: List<String>) {
        bubbles.clear()
        selected = -1
        revealedAnswer = -1
        isEnabled = true
        val colors = palette.shuffled(rnd)
        choices.forEachIndexed { i, choice ->
            val (fillColor, ringColor) = colors[i % colors.size]
            bubbles.add(
                Bubble(
                    choice,
                    i,
                    phase = rnd.nextFloat() * 6.28f,
                    color = fillColor,
                    ringColor = ringColor,
                )
            )
        }
        contentDescription = "선택지: ${choices.joinToString(", ")}"
        placeBubbles()
        startLoop()
        invalidate()
    }

    fun lock() {
        stopLoop()
        isEnabled = false
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        placeBubbles()
    }

    private fun placeBubbles() {
        if (width == 0 || height == 0 || bubbles.isEmpty()) return
        radius = minOf(width / 4.6f, height / 4.6f)
        val cols = 2
        val cellW = width / cols.toFloat()
        val rows = (bubbles.size + cols - 1) / cols
        val cellH = height / rows.toFloat()
        bubbles.forEachIndexed { i, bubble ->
            val row = i / cols
            val col = i % cols
            bubble.cx = cellW * (col + 0.5f)
            bubble.baseY = cellH * (row + 0.5f)
            bubble.cy = bubble.baseY
        }
    }

    override fun update(dt: Float) {
        for (bubble in bubbles) {
            bubble.phase += dt * 1.6f
            bubble.cy = bubble.baseY + sin(bubble.phase.toDouble()).toFloat() * radius * 0.10f
            if (bubble.pop > 0f) bubble.pop = (bubble.pop - dt * 3.2f).coerceAtLeast(0f)
        }
    }

    override fun render(canvas: Canvas) {
        for (bubble in bubbles) {
            val chosen = bubble.index == selected
            val answer = bubble.index == revealedAnswer
            val wrongSelection = revealedAnswer >= 0 && chosen && !answer
            val r = radius * (1f + bubble.pop * 0.10f) * (if (chosen) 1.06f else 1f)

            fill.color = Color.parseColor("#18000000")
            canvas.drawCircle(bubble.cx, bubble.cy + r * 0.10f, r, fill)

            fill.color = when {
                answer -> context.getColor(R.color.green_bg)
                wrongSelection -> context.getColor(R.color.red_bg)
                chosen -> bubble.color
                else -> context.getColor(R.color.surface)
            }
            canvas.drawCircle(bubble.cx, bubble.cy, r, fill)

            ring.color = when {
                answer -> context.getColor(R.color.green_ok)
                wrongSelection -> context.getColor(R.color.coral_deep)
                else -> bubble.ringColor
            }
            ring.strokeWidth = dp(if (chosen || answer) 5f else 3.5f)
            canvas.drawCircle(bubble.cx, bubble.cy, r, ring)

            fill.color = Color.parseColor("#55FFFFFF")
            canvas.drawCircle(
                bubble.cx - r * 0.34f,
                bubble.cy - r * 0.36f,
                r * 0.20f,
                fill,
            )

            val isWideGlyph = bubble.text.isNotEmpty() && bubble.text[0].code > 0x2000
            var size = if (isWideGlyph) r * 0.95f else r * 0.62f
            textPaint.textSize = size
            var guard = 0
            while (textPaint.measureText(bubble.text) > r * 1.68f && guard++ < 20) {
                size *= 0.9f
                textPaint.textSize = size
            }
            textPaint.color = context.getColor(R.color.ink)
            canvas.drawText(bubble.text, bubble.cx, bubble.cy + size * 0.35f, textPaint)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!isEnabled) return false
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> return true
            MotionEvent.ACTION_UP -> {
                for (bubble in bubbles) {
                    if (hypot(event.x - bubble.cx, event.y - bubble.cy) <= radius * 1.05f) {
                        selected = bubble.index
                        bubble.pop = 1f
                        performClick()
                        invalidate()
                        return true
                    }
                }
            }
        }
        return true
    }

    override fun performClick(): Boolean {
        super.performClick()
        val bubble = bubbles.firstOrNull { it.index == selected } ?: return false
        contentDescription = "${bubble.text} 선택됨. 선택지 ${bubbles.joinToString(", ") { it.text }}"
        announceForAccessibility("${bubble.text} 선택")
        onPick?.invoke(bubble.index)
        return true
    }

    fun reveal(answerIndex: Int) {
        revealedAnswer = answerIndex
        val answer = bubbles.firstOrNull { it.index == answerIndex }?.text.orEmpty()
        contentDescription = "정답은 $answer"
        invalidate()
    }
}
