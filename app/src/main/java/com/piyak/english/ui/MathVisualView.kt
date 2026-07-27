package com.piyak.english.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import com.piyak.english.model.MathVisual
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * 수학 문제의 그림을 그린다. 이미지 파일 없이 이모지와 Canvas 도형만 쓴다.
 * 새 그림 종류는 [MathVisual] 에 kind 를 추가하고 여기 draw 분기만 늘리면 된다.
 */
class MathVisualView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : View(ctx, attrs) {

    private val palette = listOf(
        "#FF8A80", "#FFD54F", "#80CBC4", "#81D4FA", "#B39DDB", "#A5D6A7",
    ).map { Color.parseColor(it) }

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.parseColor("#5D4037")
    }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        color = Color.parseColor("#4E342E")
    }
    private val emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }

    var visual: MathVisual? = null
        set(v) {
            field = v
            requestLayout()
            invalidate()
        }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val w = MeasureSpec.getSize(widthMeasureSpec)
        val v = visual
        val h = when (v?.kind) {
            null -> 0
            MathVisual.EMOJI -> {
                val perRow = if (v.a > 10) 5 else 5
                val rows = (v.a + perRow - 1) / perRow
                (w * 0.18f * rows).toInt().coerceAtLeast(dp(90))
            }
            MathVisual.EMOJI_OP -> (w * 0.42f).toInt()
            MathVisual.ARRAY -> (w * 0.13f * v.a + dp(30)).toInt().coerceAtLeast(dp(110))
            MathVisual.SHAPES, MathVisual.COMPARE -> (w * 0.38f).toInt()
            MathVisual.CLOCK -> (w * 0.62f).toInt()
            MathVisual.FRACTION -> (w * 0.40f).toInt()
            MathVisual.NUMBER_LINE -> dp(96)
            MathVisual.BAR_GRAPH -> (w * 0.58f).toInt()
            MathVisual.ANGLE -> (w * 0.50f).toInt()
            else -> dp(100)
        }
        setMeasuredDimension(w, h)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val v = visual ?: return
        val w = width.toFloat()
        val h = height.toFloat()
        when (v.kind) {
            MathVisual.EMOJI -> drawEmojiGrid(canvas, v.emoji, v.a, w, h)
            MathVisual.EMOJI_OP -> drawEmojiOp(canvas, v, w, h)
            MathVisual.ARRAY -> drawArray(canvas, v, w, h)
            MathVisual.SHAPES -> drawShapes(canvas, v, w, h)
            MathVisual.CLOCK -> drawClock(canvas, v, w, h)
            MathVisual.FRACTION -> drawFraction(canvas, v, w, h)
            MathVisual.NUMBER_LINE -> drawNumberLine(canvas, v, w, h)
            MathVisual.BAR_GRAPH -> drawBarGraph(canvas, v, w, h)
            MathVisual.ANGLE -> drawAngle(canvas, v, w, h)
            MathVisual.COMPARE -> drawCompare(canvas, v, w, h)
        }
    }

    // ---------- 이모지 세기 ----------
    private fun drawEmojiGrid(canvas: Canvas, emoji: String, n: Int, w: Float, h: Float) {
        if (n <= 0) return
        val perRow = min(5, n)
        val rows = (n + perRow - 1) / perRow
        val cell = min(w / (perRow + 0.6f), h / (rows + 0.3f))
        emojiPaint.textSize = cell * 0.78f
        val startX = (w - cell * perRow) / 2f + cell / 2f
        val startY = (h - cell * rows) / 2f + cell * 0.78f
        var i = 0
        for (r in 0 until rows) {
            val cols = min(perRow, n - r * perRow)
            val rowX = startX + (perRow - cols) * cell / 2f
            for (c in 0 until cols) {
                canvas.drawText(emoji, rowX + c * cell, startY + r * cell, emojiPaint)
                i++
            }
        }
    }

    // ---------- 🍎🍎 + 🍎 ----------
    private fun drawEmojiOp(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        val total = v.a + v.bb
        val cell = min(w / (total + 3.2f), h * 0.42f)
        emojiPaint.textSize = cell * 0.85f
        text.textSize = cell * 0.9f
        text.isFakeBoldText = true
        val gap = cell * 0.9f
        val totalW = v.a * cell + gap + v.bb * cell
        var x = (w - totalW) / 2f + cell / 2f
        val y = h / 2f + cell * 0.3f
        repeat(v.a) { canvas.drawText(v.emoji, x, y, emojiPaint); x += cell }
        canvas.drawText(if (v.op == "-") "－" else "＋", x + gap / 2f - cell / 2f, y, text)
        x += gap
        repeat(v.bb) { canvas.drawText(v.emoji, x, y, emojiPaint); x += cell }
    }

    // ---------- 곱셈 배열 ----------
    private fun drawArray(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        val rows = v.a.coerceAtLeast(1)
        val cols = v.bb.coerceAtLeast(1)
        val cell = min((w - dp(40)) / cols, (h - dp(30)) / rows)
        emojiPaint.textSize = cell * 0.72f
        val startX = (w - cell * cols) / 2f + cell / 2f
        val startY = (h - cell * rows) / 2f + cell * 0.75f
        for (r in 0 until rows) for (c in 0 until cols) {
            canvas.drawText(v.emoji, startX + c * cell, startY + r * cell, emojiPaint)
        }
        // 행·열 안내선
        stroke.strokeWidth = dp(1.5f).toFloat()
        stroke.color = Color.parseColor("#33795548")
        val left = (w - cell * cols) / 2f
        val top = (h - cell * rows) / 2f
        for (r in 1 until rows) {
            canvas.drawLine(left, top + r * cell, left + cell * cols, top + r * cell, stroke)
        }
        for (c in 1 until cols) {
            canvas.drawLine(left + c * cell, top, left + c * cell, top + cell * rows, stroke)
        }
        stroke.color = Color.parseColor("#5D4037")
    }

    // ---------- 도형 ----------
    private fun drawShapes(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        val n = v.labels.size.coerceAtLeast(1)
        val cellW = w / n
        val r = min(cellW * 0.32f, h * 0.34f)
        text.textSize = r * 0.42f
        text.isFakeBoldText = false
        for (i in v.labels.indices) {
            val cx = cellW * (i + 0.5f)
            val cy = h * 0.45f
            fill.color = palette[i % palette.size]
            drawShape(canvas, v.labels[i], cx, cy, r)
            canvas.drawText("${i + 1}", cx, h * 0.93f, text)
        }
    }

    private fun drawShape(canvas: Canvas, name: String, cx: Float, cy: Float, r: Float) {
        stroke.strokeWidth = dp(3f).toFloat()
        when (name) {
            "원" -> {
                canvas.drawCircle(cx, cy, r, fill)
                canvas.drawCircle(cx, cy, r, stroke)
            }
            "타원" -> {
                val rect = RectF(cx - r * 1.25f, cy - r * 0.75f, cx + r * 1.25f, cy + r * 0.75f)
                canvas.drawOval(rect, fill); canvas.drawOval(rect, stroke)
            }
            "사각형", "정사각형" -> {
                val rect = RectF(cx - r, cy - r, cx + r, cy + r)
                canvas.drawRect(rect, fill); canvas.drawRect(rect, stroke)
            }
            "직사각형" -> {
                val rect = RectF(cx - r * 1.3f, cy - r * 0.75f, cx + r * 1.3f, cy + r * 0.75f)
                canvas.drawRect(rect, fill); canvas.drawRect(rect, stroke)
            }
            else -> {
                val sides = when (name) {
                    "삼각형" -> 3; "오각형" -> 5; "육각형" -> 6; "팔각형" -> 8
                    else -> 3
                }
                val path = polygonPath(cx, cy, r, sides)
                canvas.drawPath(path, fill); canvas.drawPath(path, stroke)
            }
        }
    }

    private fun polygonPath(cx: Float, cy: Float, r: Float, sides: Int): Path {
        val path = Path()
        for (i in 0 until sides) {
            val a = Math.toRadians(-90.0 + 360.0 * i / sides)
            val x = cx + r * cos(a).toFloat()
            val y = cy + r * sin(a).toFloat()
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        path.close()
        return path
    }

    // ---------- 시계 ----------
    private fun drawClock(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        val cx = w / 2f
        val cy = h / 2f
        val r = min(w, h) * 0.42f
        fill.color = Color.WHITE
        canvas.drawCircle(cx, cy, r, fill)
        stroke.strokeWidth = dp(4f).toFloat()
        stroke.color = Color.parseColor("#FFB300")
        canvas.drawCircle(cx, cy, r, stroke)
        stroke.color = Color.parseColor("#5D4037")

        text.textSize = r * 0.20f
        text.isFakeBoldText = true
        for (i in 1..12) {
            val a = Math.toRadians(-90.0 + 30.0 * i)
            val tx = cx + r * 0.80f * cos(a).toFloat()
            val ty = cy + r * 0.80f * sin(a).toFloat() + text.textSize * 0.35f
            canvas.drawText("$i", tx, ty, text)
        }
        // 분 눈금
        stroke.strokeWidth = dp(1.5f).toFloat()
        for (i in 0 until 60) {
            if (i % 5 == 0) continue
            val a = Math.toRadians(-90.0 + 6.0 * i)
            canvas.drawLine(
                cx + r * 0.93f * cos(a).toFloat(), cy + r * 0.93f * sin(a).toFloat(),
                cx + r * 0.99f * cos(a).toFloat(), cy + r * 0.99f * sin(a).toFloat(), stroke
            )
        }

        val hour = v.p
        val minute = v.q
        // 시침 (분에 따라 조금씩 이동)
        val ha = Math.toRadians(-90.0 + 30.0 * (hour % 12) + 0.5 * minute)
        stroke.strokeWidth = dp(6f).toFloat()
        stroke.color = Color.parseColor("#FF7043")
        canvas.drawLine(
            cx, cy,
            cx + r * 0.48f * cos(ha).toFloat(), cy + r * 0.48f * sin(ha).toFloat(), stroke
        )
        // 분침
        val ma = Math.toRadians(-90.0 + 6.0 * minute)
        stroke.strokeWidth = dp(4f).toFloat()
        stroke.color = Color.parseColor("#42A5F5")
        canvas.drawLine(
            cx, cy,
            cx + r * 0.72f * cos(ma).toFloat(), cy + r * 0.72f * sin(ma).toFloat(), stroke
        )
        fill.color = Color.parseColor("#5D4037")
        canvas.drawCircle(cx, cy, dp(5f).toFloat(), fill)
        stroke.color = Color.parseColor("#5D4037")
    }

    // ---------- 분수 (원을 나눈 그림) ----------
    private fun drawFraction(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        val denom = v.q.toInt().coerceAtLeast(1)
        val numer = v.p.toInt().coerceIn(0, denom)
        val cx = w / 2f
        val cy = h / 2f
        val r = min(w, h) * 0.40f
        val rect = RectF(cx - r, cy - r, cx + r, cy + r)
        val sweep = 360f / denom
        for (i in 0 until denom) {
            fill.color = if (i < numer) Color.parseColor("#FF8A65") else Color.parseColor("#FFF3E0")
            canvas.drawArc(rect, -90f + sweep * i, sweep, true, fill)
        }
        stroke.strokeWidth = dp(3f).toFloat()
        canvas.drawCircle(cx, cy, r, stroke)
        stroke.strokeWidth = dp(2f).toFloat()
        for (i in 0 until denom) {
            val a = Math.toRadians(-90.0 + sweep * i)
            canvas.drawLine(cx, cy, cx + r * cos(a).toFloat(), cy + r * sin(a).toFloat(), stroke)
        }
    }

    // ---------- 수직선 ----------
    private fun drawNumberLine(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        val lo = v.p
        val hi = v.q
        if (hi <= lo) return
        val left = dp(28).toFloat()
        val right = w - dp(28)
        val y = h * 0.55f
        stroke.strokeWidth = dp(3f).toFloat()
        canvas.drawLine(left, y, right, y, stroke)
        // 화살촉
        canvas.drawLine(right, y, right - dp(10), y - dp(6), stroke)
        canvas.drawLine(right, y, right - dp(10), y + dp(6), stroke)

        val steps = (hi - lo).toInt().coerceIn(1, 20)
        text.textSize = h * 0.20f
        text.isFakeBoldText = false
        for (i in 0..steps) {
            val x = left + (right - left) * i / steps
            canvas.drawLine(x, y - dp(8), x, y + dp(8), stroke)
            canvas.drawText("${(lo + i).toInt()}", x, y + h * 0.36f, text)
        }
        // 표시할 값
        fill.color = Color.parseColor("#FF7043")
        for (value in v.values) {
            val x = left + (right - left) * ((value - lo) / (hi - lo)).toFloat()
            canvas.drawCircle(x, y, dp(9f).toFloat(), fill)
        }
    }

    // ---------- 막대그래프 ----------
    private fun drawBarGraph(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        if (v.values.isEmpty()) return
        val maxV = (v.values.maxOrNull() ?: 1.0).coerceAtLeast(1.0)
        val left = dp(34).toFloat()
        val bottom = h - dp(30)
        val top = dp(14).toFloat()
        val right = w - dp(14)
        stroke.strokeWidth = dp(2.5f).toFloat()
        canvas.drawLine(left, top, left, bottom, stroke)
        canvas.drawLine(left, bottom, right, bottom, stroke)

        text.textSize = h * 0.10f
        text.isFakeBoldText = false
        // 눈금
        val gridSteps = 4
        for (i in 1..gridSteps) {
            val yy = bottom - (bottom - top) * i / gridSteps
            val label = (maxV * i / gridSteps)
            canvas.drawText(fmt(label), left - dp(16), yy + text.textSize * 0.35f, text)
        }

        val n = v.values.size
        val slot = (right - left) / n
        val barW = slot * 0.55f
        for (i in v.values.indices) {
            val bh = ((bottom - top) * (v.values[i] / maxV)).toFloat()
            val cx = left + slot * (i + 0.5f)
            fill.color = palette[i % palette.size]
            val rect = RectF(cx - barW / 2f, bottom - bh, cx + barW / 2f, bottom)
            canvas.drawRoundRect(rect, dp(6f).toFloat(), dp(6f).toFloat(), fill)
            v.labels.getOrNull(i)?.let {
                canvas.drawText(it, cx, bottom + text.textSize * 1.4f, text)
            }
        }
    }

    // ---------- 각도 ----------
    private fun drawAngle(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        val cx = w * 0.30f
        val cy = h * 0.72f
        val len = min(w * 0.55f, h * 0.62f)
        stroke.strokeWidth = dp(4f).toFloat()
        canvas.drawLine(cx, cy, cx + len, cy, stroke)
        val a = Math.toRadians(-v.p)
        canvas.drawLine(cx, cy, cx + len * cos(a).toFloat(), cy + len * sin(a).toFloat(), stroke)
        // 각 표시 호
        stroke.strokeWidth = dp(2.5f).toFloat()
        stroke.color = Color.parseColor("#FF7043")
        val r = len * 0.28f
        canvas.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), 0f, -v.p.toFloat(), false, stroke)
        stroke.color = Color.parseColor("#5D4037")
        fill.color = Color.parseColor("#5D4037")
        canvas.drawCircle(cx, cy, dp(4f).toFloat(), fill)
    }

    // ---------- 두 그룹 비교 ----------
    private fun drawCompare(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        val halfW = w / 2f
        drawEmojiGridIn(canvas, v.emoji, v.a, 0f, 0f, halfW - dp(8), h)
        drawEmojiGridIn(canvas, v.labels.getOrNull(0) ?: v.emoji, v.bb, halfW + dp(8), 0f, halfW - dp(8), h)
        stroke.strokeWidth = dp(2f).toFloat()
        stroke.color = Color.parseColor("#33795548")
        canvas.drawLine(halfW, dp(8).toFloat(), halfW, h - dp(8), stroke)
        stroke.color = Color.parseColor("#5D4037")
    }

    private fun drawEmojiGridIn(
        canvas: Canvas, emoji: String, n: Int, x0: Float, y0: Float, w: Float, h: Float,
    ) {
        if (n <= 0) return
        val perRow = min(3, n)
        val rows = (n + perRow - 1) / perRow
        val cell = min(w / (perRow + 0.4f), h / (rows + 0.4f))
        emojiPaint.textSize = cell * 0.76f
        val startX = x0 + (w - cell * perRow) / 2f + cell / 2f
        val startY = y0 + (h - cell * rows) / 2f + cell * 0.78f
        var left = n
        for (r in 0 until rows) {
            val cols = min(perRow, left)
            for (c in 0 until cols) {
                canvas.drawText(emoji, startX + c * cell, startY + r * cell, emojiPaint)
            }
            left -= cols
        }
    }

    private fun fmt(d: Double): String =
        if (d == d.toInt().toDouble()) d.toInt().toString() else "%.1f".format(d)

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
    private fun dp(v: Float): Float = v * resources.displayMetrics.density
}
