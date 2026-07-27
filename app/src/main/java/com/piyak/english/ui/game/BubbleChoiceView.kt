package com.piyak.english.ui.game

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.MotionEvent
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import kotlin.random.Random

/**
 * 일반 문제의 4지선다를 "둥둥 떠다니는 버블"로 보여 준다.
 * 놀이터의 풍선과 달리 **시간 압박이 없다** — 사라지지 않고 제자리에서 천천히 흔들릴 뿐이라
 * 생각할 시간은 그대로 두면서 화면에 움직임과 만지는 재미만 더한다.
 *
 * 글자가 길면 버블이 답답하므로, 짧은 보기일 때만 쓰는 것을 전제로 한다([fits] 참고).
 */
class BubbleChoiceView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : GameView(ctx, attrs) {

    companion object {
        /**
         * 버블에 들어갈 수 있는 최대 "폭 점수".
         * 글자 수로 재면 안 된다 — 한글·이모지는 알파벳보다 두 배 넓어서
         * "나는 사과를 좋아해요."(11자)가 짧은 보기로 잘못 판정된다.
         */
        const val MAX_WIDTH_SCORE = 12

        /**
         * 한글·한자·가나·이모지는 2칸, 나머지는 1칸.
         * 이모지는 char 두 개(서로게이트 페어)로 저장되므로 **코드포인트 단위로** 세야
         * 🍎 하나가 4칸으로 잘못 계산되지 않는다.
         */
        fun widthScore(s: String): Int {
            var i = 0
            var score = 0
            while (i < s.length) {
                val cp = s.codePointAt(i)
                score += when {
                    cp in 0x1100..0x11FF ||   // 한글 자모
                        cp in 0x3040..0x30FF || // 가나
                        cp in 0x3130..0x318F || // 한글 호환 자모
                        cp in 0x4E00..0x9FFF || // 한자
                        cp in 0xAC00..0xD7A3 || // 한글 음절
                        cp >= 0x2000            // 이모지·기호
                    -> 2
                    else -> 1
                }
                i += Character.charCount(cp)
            }
            return score
        }

        /** 보기 4개가 모두 버블에 들어갈 만큼 짧은가 */
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
        var pop: Float = 0f,      // 눌렀을 때 살짝 커졌다 돌아오는 연출
        var color: Int = 0,
    )

    private val rnd = Random(System.currentTimeMillis())
    private val bubbles = ArrayList<Bubble>()
    private var selected = -1
    private var radius = 0f

    private val palette = listOf(
        "#FF8A80", "#FFD54F", "#80CBC4", "#81D4FA", "#B39DDB", "#A5D6A7",
    ).map { Color.parseColor(it) }

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
    }

    /** 보기를 골랐을 때 (인덱스) */
    var onPick: ((Int) -> Unit)? = null

    fun setChoices(choices: List<String>) {
        bubbles.clear()
        selected = -1
        val colors = palette.shuffled(rnd)
        choices.forEachIndexed { i, c ->
            bubbles.add(Bubble(c, i, phase = rnd.nextFloat() * 6.28f, color = colors[i % colors.size]))
        }
        placeBubbles()
        startLoop()
        invalidate()
    }

    /** 정답·오답이 정해진 뒤 더 이상 못 고르게 */
    fun lock() = stopLoop()

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        placeBubbles()
    }

    private fun placeBubbles() {
        if (width == 0 || height == 0 || bubbles.isEmpty()) return
        // 2 x 2 배치
        radius = minOf(width / 4.6f, height / 4.6f)
        val cols = 2
        val cellW = width / cols.toFloat()
        val rows = (bubbles.size + cols - 1) / cols
        val cellH = height / rows.toFloat()
        bubbles.forEachIndexed { i, b ->
            val r = i / cols
            val c = i % cols
            b.cx = cellW * (c + 0.5f)
            b.baseY = cellH * (r + 0.5f)
            b.cy = b.baseY
        }
    }

    override fun update(dt: Float) {
        for (b in bubbles) {
            b.phase += dt * 1.6f
            // 위아래로 천천히 둥둥
            b.cy = b.baseY + sin(b.phase.toDouble()).toFloat() * radius * 0.10f
            if (b.pop > 0f) b.pop = (b.pop - dt * 3.2f).coerceAtLeast(0f)
        }
    }

    override fun render(canvas: Canvas) {
        for (b in bubbles) {
            val chosen = b.index == selected
            val r = radius * (1f + b.pop * 0.10f) * (if (chosen) 1.06f else 1f)

            // 그림자
            fill.color = Color.parseColor("#14000000")
            canvas.drawCircle(b.cx, b.cy + r * 0.10f, r, fill)

            fill.color = if (chosen) b.color else Color.WHITE
            canvas.drawCircle(b.cx, b.cy, r, fill)

            ring.color = if (chosen) Color.parseColor("#66BB6A") else b.color
            ring.strokeWidth = dp(if (chosen) 5f else 3.5f)
            canvas.drawCircle(b.cx, b.cy, r, ring)

            // 반짝임
            fill.color = Color.parseColor("#40FFFFFF")
            canvas.drawCircle(
                b.cx - r * 0.34f, b.cy - r * 0.36f, r * 0.20f, fill
            )

            // 글자 (버블 안에 들어가도록 크기를 줄인다)
            val isEmoji = b.text.isNotEmpty() && b.text[0].code > 0x2000
            var size = if (isEmoji) r * 0.95f else r * 0.62f
            textPaint.textSize = size
            var guard = 0
            while (textPaint.measureText(b.text) > r * 1.68f && guard++ < 20) {
                size *= 0.9f
                textPaint.textSize = size
            }
            textPaint.color = if (chosen) Color.WHITE else Color.parseColor("#4E342E")
            canvas.drawText(b.text, b.cx, b.cy + size * 0.35f, textPaint)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (event.actionMasked != MotionEvent.ACTION_DOWN) return true
        for (b in bubbles) {
            if (hypot(event.x - b.cx, event.y - b.cy) <= radius * 1.05f) {
                selected = b.index
                b.pop = 1f
                onPick?.invoke(b.index)
                invalidate()
                return true
            }
        }
        return true
    }

    /** 채점 후 정답·오답을 색으로 알려 준다 */
    fun reveal(answerIndex: Int) {
        for (b in bubbles) {
            b.color = when {
                b.index == answerIndex -> Color.parseColor("#66BB6A")
                b.index == selected -> Color.parseColor("#EF5350")
                else -> Color.parseColor("#E0E0E0")
            }
        }
        invalidate()
    }
}
