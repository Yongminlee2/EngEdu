package com.piyak.english.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import kotlin.math.min

/**
 * 표를 보고 **막대를 직접 끌어 올려** 그래프를 완성하는 판.
 *
 * 완성된 그래프를 읽는 문제만 풀면 "그래프 = 읽는 것"으로 남는데,
 * 한 번 세워 보면 막대 높이가 곧 수라는 걸 몸으로 알게 된다.
 */
class BarBuildView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : View(ctx, attrs) {

    private var labels = listOf<String>()
    private var target = listOf<Int>()
    private val current = ArrayList<Int>()
    private var maxV = 5

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        color = Color.parseColor("#4E342E")
    }

    private val palette = listOf(
        Color.parseColor("#FF8A65"), Color.parseColor("#4DB6AC"),
        Color.parseColor("#BA68C8"), Color.parseColor("#FFD54F"),
        Color.parseColor("#7986CB"), Color.parseColor("#AED581"),
    )

    private var plotLeft = 0f
    private var plotRight = 0f
    private var plotTop = 0f
    private var plotBottom = 0f

    var onChanged: ((List<Int>) -> Unit)? = null
    var onBarMoved: (() -> Unit)? = null

    fun setTarget(labels: List<String>, values: List<Int>) {
        this.labels = labels
        this.target = values
        maxV = ((values.maxOrNull() ?: 5) + 1).coerceAtLeast(5)
        current.clear()
        repeat(values.size) { current.add(0) }
        onChanged?.invoke(current.toList())
        invalidate()
    }

    fun values(): List<Int> = current.toList()

    fun isCorrect(): Boolean = current.size == target.size && current == target

    /** 아직 높이가 안 맞는 막대 수 */
    fun wrongBars(): Int = current.indices.count { current[it] != target.getOrNull(it) }

    fun reset() {
        for (i in current.indices) current[i] = 0
        onChanged?.invoke(current.toList())
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0f || current.isEmpty()) return

        plotLeft = dp(34f)
        plotRight = w - dp(12f)
        plotTop = dp(14f)
        plotBottom = h - dp(34f)

        stroke.color = Color.parseColor("#8D6E63")
        stroke.strokeWidth = dp(2.5f)
        canvas.drawLine(plotLeft, plotTop, plotLeft, plotBottom, stroke)
        canvas.drawLine(plotLeft, plotBottom, plotRight, plotBottom, stroke)

        // 가로 눈금선 — 높이를 눈으로 셀 수 있어야 한다
        text.textSize = dp(11f)
        text.isFakeBoldText = false
        stroke.strokeWidth = dp(1f)
        stroke.color = Color.parseColor("#33795548")
        for (i in 1..maxV) {
            val y = plotBottom - (plotBottom - plotTop) * i / maxV
            canvas.drawLine(plotLeft, y, plotRight, y, stroke)
            text.color = Color.parseColor("#8D6E63")
            canvas.drawText("$i", plotLeft - dp(12f), y + text.textSize * 0.35f, text)
        }

        val slot = (plotRight - plotLeft) / current.size
        val barW = slot * 0.56f
        for (i in current.indices) {
            val cx = plotLeft + slot * (i + 0.5f)
            val bh = (plotBottom - plotTop) * current[i] / maxV
            if (current[i] > 0) {
                fill.color = palette[i % palette.size]
                canvas.drawRoundRect(
                    RectF(cx - barW / 2f, plotBottom - bh, cx + barW / 2f, plotBottom),
                    dp(5f), dp(5f), fill
                )
                // 막대 꼭대기의 손잡이 — 여기를 잡아 올린다
                fill.color = Color.parseColor("#FFFFFF")
                canvas.drawCircle(cx, plotBottom - bh, dp(5f), fill)
            } else {
                stroke.color = Color.parseColor("#BCAAA4")
                stroke.strokeWidth = dp(2f)
                stroke.pathEffect = android.graphics.DashPathEffect(
                    floatArrayOf(dp(6f), dp(5f)), 0f
                )
                canvas.drawRoundRect(
                    RectF(cx - barW / 2f, plotBottom - dp(10f), cx + barW / 2f, plotBottom),
                    dp(5f), dp(5f), stroke
                )
                stroke.pathEffect = null
            }

            text.isFakeBoldText = true
            // 막대가 5개면 칸이 좁아진다 — 이름이 옆 칸을 침범하지 않게 칸 폭에 맞춘다
            text.textSize = min(dp(13f), slot * 0.19f)
            text.color = if (current[i] == target.getOrNull(i))
                Color.parseColor("#2E7D32") else Color.parseColor("#8D6E63")
            canvas.drawText(
                "${labels.getOrElse(i) { "" }} ${current[i]}",
                cx, plotBottom + dp(20f), text
            )
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> return true
        }
        if (current.isEmpty() || plotRight <= plotLeft) return false
        if (event.x < plotLeft - dp(20f) || event.y > plotBottom + dp(30f)) return false
        parent?.requestDisallowInterceptTouchEvent(true)

        val slot = (plotRight - plotLeft) / current.size
        val i = (((event.x - plotLeft) / slot).toInt()).coerceIn(0, current.size - 1)
        // 손가락 높이가 곧 막대 높이 (칸에 딱 붙는다)
        val t = ((plotBottom - event.y) / (plotBottom - plotTop)).coerceIn(0f, 1f)
        val v = Math.round(t * maxV).coerceIn(0, maxV)
        if (v != current[i]) {
            current[i] = v
            onBarMoved?.invoke()
            onChanged?.invoke(current.toList())
            invalidate()
        }
        return true
    }

    private fun dp(v: Float): Float = v * resources.displayMetrics.density
}
