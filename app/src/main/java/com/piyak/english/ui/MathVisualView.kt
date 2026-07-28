package com.piyak.english.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
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
            counted.clear()
            painted.clear()
            setHour = 12; setMinute = 0
            setAngle = 0
            markValue = v?.p ?: 0.0
            draggingClock = false
            requestLayout()
            invalidate()
        }

    // ---------- 손가락으로 짚어 세기 ----------
    /**
     * 그림의 사물을 하나씩 터치하면 번호가 붙는다.
     * 아이가 실제로 손가락으로 짚으며 세는 행동을 그대로 옮긴 것 —
     * 정지된 그림을 보기만 하는 것과 만지며 세는 것은 완전히 다르다.
     */
    private val itemCenters = ArrayList<PointF>()
    private val counted = LinkedHashSet<Int>()

    /** 셀 수 있는 그림인지 (이모지·배열 계열) */
    val countable: Boolean
        get() = visual?.kind in setOf(MathVisual.EMOJI, MathVisual.EMOJI_OP, MathVisual.ARRAY)

    /** 지금까지 짚은 개수가 바뀔 때 */
    var onCountChanged: ((Int) -> Unit)? = null

    val countedSoFar: Int get() = counted.size

    fun clearCount() {
        counted.clear()
        onCountChanged?.invoke(0)
        invalidate()
    }

    // ---------- 시계 바늘 돌리기 ----------
    /**
     * 시각을 "읽는" 것에서 한 걸음 더 나아가 직접 **바늘을 돌려 만들어 보는** 모드.
     * 짧은 바늘 근처를 잡으면 시침이, 그 밖을 잡으면 분침이 손가락을 따라온다.
     */
    private var clockCx = 0f
    private var clockCy = 0f
    private var clockR = 0f
    private var draggingHour = false
    private var draggingClock = false

    var setHour = 12
        private set
    var setMinute = 0
        private set

    /** 맞춰 놓은 시각이 바뀔 때 (시, 분) */
    var onClockChanged: ((Int, Int) -> Unit)? = null

    fun resetClock() {
        setHour = 12; setMinute = 0
        onClockChanged?.invoke(setHour, setMinute)
        invalidate()
    }

    private fun handleClockTouch(event: android.view.MotionEvent): Boolean {
        val dx = event.x - clockCx
        val dy = event.y - clockCy
        val dist = kotlin.math.hypot(dx, dy)
        when (event.actionMasked) {
            android.view.MotionEvent.ACTION_DOWN -> {
                if (dist > clockR * 1.05f) return false
                // 시침은 짧다 — 안쪽을 잡으면 시침, 바깥을 잡으면 분침
                draggingHour = dist < clockR * 0.55f
                draggingClock = true
                parent?.requestDisallowInterceptTouchEvent(true)
            }
            android.view.MotionEvent.ACTION_MOVE -> if (!draggingClock) return false
            else -> { draggingClock = false; return true }
        }
        // 12시 방향이 0도가 되도록 회전
        var deg = Math.toDegrees(kotlin.math.atan2(dy.toDouble(), dx.toDouble())) + 90.0
        if (deg < 0) deg += 360.0
        if (draggingHour) {
            val h = Math.round(deg / 30.0).toInt() % 12
            setHour = if (h == 0) 12 else h
        } else {
            // 5분 단위로 딱 붙게 — 아이 손가락으로 1분 단위를 맞추긴 어렵다
            setMinute = (Math.round(deg / 6.0).toInt() / 5 * 5) % 60
        }
        onClockChanged?.invoke(setHour, setMinute)
        invalidate()
        return true
    }

    override fun onTouchEvent(event: android.view.MotionEvent): Boolean {
        when (visual?.kind) {
            MathVisual.CLOCK_SET -> return handleClockTouch(event)
            MathVisual.FRACTION_PAINT -> return handlePaintTouch(event)
            MathVisual.NUMBER_LINE_DRAG -> return handleLineTouch(event)
            MathVisual.ANGLE_SET -> return handleAngleTouch(event)
        }
        if (!countable || event.actionMasked != android.view.MotionEvent.ACTION_DOWN) return false
        var best = -1
        var bestD = Float.MAX_VALUE
        val limit = itemSpacing * 0.6f
        for (i in itemCenters.indices) {
            val c = itemCenters[i]
            val d = kotlin.math.hypot(event.x - c.x, event.y - c.y)
            if (d < bestD) { bestD = d; best = i }
        }
        if (best >= 0 && bestD <= limit) {
            if (!counted.add(best)) counted.remove(best)   // 다시 누르면 취소
            onCountChanged?.invoke(counted.size)
            invalidate()
            return true
        }
        return false
    }

    /** 항목 사이 간격 (터치 판정 범위 계산용) */
    private var itemSpacing = 0f

    /** 짚은 순서대로 번호를 그린다 */
    private fun drawCountMarks(canvas: Canvas) {
        if (counted.isEmpty()) return
        val r = itemSpacing * 0.20f
        text.textSize = r * 1.5f
        text.isFakeBoldText = true
        counted.forEachIndexed { order, idx ->
            val c = itemCenters.getOrNull(idx) ?: return@forEachIndexed
            fill.color = Color.parseColor("#66BB6A")
            canvas.drawCircle(c.x + itemSpacing * 0.30f, c.y - itemSpacing * 0.30f, r, fill)
            text.color = Color.WHITE
            canvas.drawText(
                "${order + 1}",
                c.x + itemSpacing * 0.30f,
                c.y - itemSpacing * 0.30f + text.textSize * 0.35f, text
            )
        }
        text.color = Color.parseColor("#4E342E")
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
            MathVisual.CLOCK_SET -> (w * 0.78f).toInt()
            MathVisual.GROUP -> 0          // GroupDragView 가 따로 그린다
            MathVisual.FRACTION -> (w * 0.40f).toInt()
            MathVisual.FRACTION_PAINT -> (w * 0.62f).toInt()
            MathVisual.SHAPE_SORT -> 0     // GroupDragView 가 따로 그린다
            MathVisual.NUMBER_LINE -> dp(96)
            MathVisual.NUMBER_LINE_DRAG -> dp(150)      // 손잡이·값 표시 자리
            MathVisual.ANGLE_SET -> (w * 0.62f).toInt()
            MathVisual.BALANCE, MathVisual.BAR_BUILD -> 0   // 전용 뷰가 따로 그린다
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
        itemCenters.clear()
        when (v.kind) {
            MathVisual.EMOJI -> drawEmojiGrid(canvas, v.emoji, v.a, w, h)
            MathVisual.EMOJI_OP -> drawEmojiOp(canvas, v, w, h)
            MathVisual.ARRAY -> drawArray(canvas, v, w, h)
            MathVisual.SHAPES -> drawShapes(canvas, v, w, h)
            MathVisual.CLOCK, MathVisual.CLOCK_SET -> drawClock(canvas, v, w, h)
            MathVisual.FRACTION, MathVisual.FRACTION_PAINT -> drawFraction(canvas, v, w, h)
            MathVisual.NUMBER_LINE, MathVisual.NUMBER_LINE_DRAG -> drawNumberLine(canvas, v, w, h)
            MathVisual.BAR_GRAPH -> drawBarGraph(canvas, v, w, h)
            MathVisual.ANGLE, MathVisual.ANGLE_SET -> drawAngle(canvas, v, w, h)
            MathVisual.COMPARE -> drawCompare(canvas, v, w, h)
        }
        drawCountMarks(canvas)
    }

    // ---------- 이모지 세기 ----------
    private fun drawEmojiGrid(canvas: Canvas, emoji: String, n: Int, w: Float, h: Float) {
        if (n <= 0) return
        val perRow = min(5, n)
        val rows = (n + perRow - 1) / perRow
        val cell = min(w / (perRow + 0.6f), h / (rows + 0.3f))
        itemSpacing = cell
        emojiPaint.textSize = cell * 0.78f
        val startX = (w - cell * perRow) / 2f + cell / 2f
        val startY = (h - cell * rows) / 2f + cell * 0.78f
        for (r in 0 until rows) {
            val cols = min(perRow, n - r * perRow)
            val rowX = startX + (perRow - cols) * cell / 2f
            for (c in 0 until cols) {
                val x = rowX + c * cell
                val y = startY + r * cell
                canvas.drawText(emoji, x, y, emojiPaint)
                itemCenters.add(PointF(x, y - cell * 0.28f))
            }
        }
    }

    // ---------- 🍎🍎 + 🍎 ----------
    private fun drawEmojiOp(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        val total = v.a + v.bb
        val cell = min(w / (total + 3.2f), h * 0.42f)
        itemSpacing = cell
        emojiPaint.textSize = cell * 0.85f
        text.textSize = cell * 0.9f
        text.isFakeBoldText = true
        val gap = cell * 0.9f
        val totalW = v.a * cell + gap + v.bb * cell
        var x = (w - totalW) / 2f + cell / 2f
        val y = h / 2f + cell * 0.3f
        repeat(v.a) {
            canvas.drawText(v.emoji, x, y, emojiPaint)
            itemCenters.add(PointF(x, y - cell * 0.3f))
            x += cell
        }
        canvas.drawText(if (v.op == "-") "－" else "＋", x + gap / 2f - cell / 2f, y, text)
        x += gap
        repeat(v.bb) {
            canvas.drawText(v.emoji, x, y, emojiPaint)
            itemCenters.add(PointF(x, y - cell * 0.3f))
            x += cell
        }
    }

    // ---------- 곱셈 배열 ----------
    private fun drawArray(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        val rows = v.a.coerceAtLeast(1)
        val cols = v.bb.coerceAtLeast(1)
        val cell = min((w - dp(40)) / cols, (h - dp(30)) / rows)
        itemSpacing = cell
        emojiPaint.textSize = cell * 0.72f
        val startX = (w - cell * cols) / 2f + cell / 2f
        val startY = (h - cell * rows) / 2f + cell * 0.75f
        for (r in 0 until rows) for (c in 0 until cols) {
            val x = startX + c * cell
            val y = startY + r * cell
            canvas.drawText(v.emoji, x, y, emojiPaint)
            itemCenters.add(PointF(x, y - cell * 0.26f))
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

        // 마지막으로 그린 판 위치 — 바늘을 끌 때 각도 계산에 쓴다
        clockCx = cx; clockCy = cy; clockR = r

        val hour = if (v.kind == MathVisual.CLOCK_SET) setHour.toDouble() else v.p
        val minute = if (v.kind == MathVisual.CLOCK_SET) setMinute.toDouble() else v.q
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

        if (v.kind == MathVisual.CLOCK_SET) {
            // 지금 맞춰 놓은 시각을 숫자로도 보여 준다
            text.textSize = r * 0.22f
            text.color = Color.parseColor("#4E342E")
            canvas.drawText(
                "${setHour}시 ${setMinute}분",
                cx, cy + r * 1.28f, text
            )
            text.textSize = r * 0.15f
            text.isFakeBoldText = false
            text.color = Color.parseColor("#8D6E63")
            canvas.drawText("바늘을 끌어서 맞춰 보세요", cx, cy + r * 1.48f, text)
            text.isFakeBoldText = true
            text.color = Color.parseColor("#4E342E")
        }
    }

    // ---------- 분수 (원을 나눈 그림) ----------
    private fun drawFraction(canvas: Canvas, v: MathVisual, w: Float, h: Float) {
        val paintMode = v.kind == MathVisual.FRACTION_PAINT
        val denom = v.q.toInt().coerceAtLeast(1)
        val numer = v.p.toInt().coerceIn(0, denom)
        val cx = w / 2f
        val cy = if (paintMode) h * 0.45f else h / 2f
        val r = min(w, h * (if (paintMode) 0.9f else 1f)) * 0.40f
        val rect = RectF(cx - r, cy - r, cx + r, cy + r)
        val sweep = 360f / denom

        // 색칠 모드에서는 "아이가 칠한 칸"이, 아니면 "문제가 정해 준 칸"이 색칠된다
        fun filled(i: Int) = if (paintMode) i in painted else i < numer

        for (i in 0 until denom) {
            fill.color = if (filled(i)) Color.parseColor("#FF8A65") else Color.parseColor("#FFF3E0")
            canvas.drawArc(rect, -90f + sweep * i, sweep, true, fill)
        }
        stroke.strokeWidth = dp(3f).toFloat()
        canvas.drawCircle(cx, cy, r, stroke)
        stroke.strokeWidth = dp(2f).toFloat()
        for (i in 0 until denom) {
            val a = Math.toRadians(-90.0 + sweep * i)
            canvas.drawLine(cx, cy, cx + r * cos(a).toFloat(), cy + r * sin(a).toFloat(), stroke)
        }

        if (paintMode) {
            pieCx = cx; pieCy = cy; pieR = r; pieSlices = denom
            text.textSize = r * 0.24f
            text.isFakeBoldText = true
            text.color = Color.parseColor("#4E342E")
            canvas.drawText("칠한 칸 ${painted.size} / $denom", cx, cy + r * 1.32f, text)
            text.textSize = r * 0.16f
            text.isFakeBoldText = false
            text.color = Color.parseColor("#8D6E63")
            canvas.drawText("조각을 눌러서 색칠해요", cx, cy + r * 1.52f, text)
            text.isFakeBoldText = true
            text.color = Color.parseColor("#4E342E")
        }
    }

    // ---------- 분수 색칠하기 ----------
    /**
     * "3/8 만큼 색칠해 보세요" — 조각을 눌러 칠한다.
     * 색칠된 그림을 읽고 분수를 답하는 것과 반대 방향이라, 분수를 *만들어* 보게 된다.
     */
    private var pieCx = 0f
    private var pieCy = 0f
    private var pieR = 0f
    private var pieSlices = 1
    private val painted = LinkedHashSet<Int>()

    val paintedCount: Int get() = painted.size

    /** 칠한 칸 수가 바뀔 때 */
    var onPaintChanged: ((Int) -> Unit)? = null

    fun clearPaint() {
        painted.clear()
        onPaintChanged?.invoke(0)
        invalidate()
    }

    private fun handlePaintTouch(event: android.view.MotionEvent): Boolean {
        if (event.actionMasked != android.view.MotionEvent.ACTION_DOWN) return false
        val dx = event.x - pieCx
        val dy = event.y - pieCy
        if (kotlin.math.hypot(dx, dy) > pieR) return false
        var deg = Math.toDegrees(kotlin.math.atan2(dy.toDouble(), dx.toDouble())) + 90.0
        if (deg < 0) deg += 360.0
        val idx = ((deg / (360.0 / pieSlices)).toInt()).coerceIn(0, pieSlices - 1)
        if (!painted.add(idx)) painted.remove(idx)   // 다시 누르면 지운다
        onPaintChanged?.invoke(painted.size)
        invalidate()
        return true
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

        // 구간 수가 지정돼 있으면 그대로 (소수·음수 수직선은 눈금 간격이 1이 아니다)
        val steps = if (v.a > 0) v.a.coerceAtMost(20) else (hi - lo).toInt().coerceIn(1, 20)
        text.textSize = h * (if (v.kind == MathVisual.NUMBER_LINE_DRAG) 0.13f else 0.20f)
        text.isFakeBoldText = false
        // 눈금이 촘촘하면 숫자는 띄엄띄엄 적는다 (겹쳐서 못 읽는다)
        val labelEvery = if (steps > 10) 2 else 1
        for (i in 0..steps) {
            val x = left + (right - left) * i / steps
            canvas.drawLine(x, y - dp(8), x, y + dp(8), stroke)
            if (i % labelEvery == 0) {
                val labelY = y + h * (if (v.kind == MathVisual.NUMBER_LINE_DRAG) 0.26f else 0.36f)
                canvas.drawText(fmt(lo + (hi - lo) * i / steps), x, labelY, text)
            }
        }
        // 표시할 값
        fill.color = Color.parseColor("#FF7043")
        for (value in v.values) {
            val x = left + (right - left) * ((value - lo) / (hi - lo)).toFloat()
            canvas.drawCircle(x, y, dp(9f).toFloat(), fill)
        }

        if (v.kind == MathVisual.NUMBER_LINE_DRAG) {
            lineLeft = left; lineRight = right; lineY = y
            val x = left + (right - left) * ((markValue - lo) / (hi - lo)).toFloat()
            // 끌 수 있다는 걸 알 수 있게 큼직한 손잡이로
            fill.color = Color.parseColor("#42A5F5")
            canvas.drawCircle(x, y, dp(16f).toFloat(), fill)
            fill.color = Color.WHITE
            canvas.drawCircle(x, y, dp(7f).toFloat(), fill)

            text.textSize = h * 0.20f
            text.isFakeBoldText = true
            text.color = Color.parseColor("#1565C0")
            canvas.drawText(fmt(markValue), x, y - dp(24), text)
            text.color = Color.parseColor("#4E342E")
        }
    }

    // ---------- 수직선 위의 점 끌기 ----------
    /**
     * 수를 보고 고르는 대신 **수직선 위 어디쯤인지 직접 짚어 본다.**
     * 눈금에 딱 붙게 해서 손가락으로도 정확히 맞출 수 있다.
     */
    private var lineLeft = 0f
    private var lineRight = 0f
    private var lineY = 0f
    private var markValue = 0.0

    /** 지금 짚은 값 */
    val markedValue: Double get() = markValue

    var onMarkChanged: ((Double) -> Unit)? = null

    fun resetMark() {
        markValue = visual?.p ?: 0.0
        onMarkChanged?.invoke(markValue)
        invalidate()
    }

    private fun handleLineTouch(event: android.view.MotionEvent): Boolean {
        val v = visual ?: return false
        if (event.actionMasked == android.view.MotionEvent.ACTION_UP ||
            event.actionMasked == android.view.MotionEvent.ACTION_CANCEL
        ) return true
        if (lineRight <= lineLeft) return false
        // 선에서 너무 멀면 무시 (연습장 필기와 헷갈리지 않게)
        if (kotlin.math.abs(event.y - lineY) > dp(56)) return false
        parent?.requestDisallowInterceptTouchEvent(true)

        val t = ((event.x - lineLeft) / (lineRight - lineLeft)).coerceIn(0f, 1f)
        val steps = v.a.coerceAtLeast(1)
        val raw = v.p + (v.q - v.p) * t
        // 눈금에 딱 붙인다
        val stepSize = (v.q - v.p) / steps
        val snapped = v.p + Math.round((raw - v.p) / stepSize) * stepSize
        val rounded = Math.round(snapped * 1000.0) / 1000.0
        if (rounded != markValue) {
            markValue = rounded
            onMarkChanged?.invoke(markValue)
            invalidate()
        }
        return true
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
        val setMode = v.kind == MathVisual.ANGLE_SET
        val deg = if (setMode) setAngle.toDouble() else v.p
        val cx = w * 0.30f
        val cy = h * 0.72f
        val len = min(w * 0.55f, h * 0.62f)
        angleCx = cx; angleCy = cy; angleLen = len

        stroke.strokeWidth = dp(4f).toFloat()
        canvas.drawLine(cx, cy, cx + len, cy, stroke)
        val a = Math.toRadians(-deg)
        if (setMode) stroke.color = Color.parseColor("#42A5F5")
        canvas.drawLine(cx, cy, cx + len * cos(a).toFloat(), cy + len * sin(a).toFloat(), stroke)
        stroke.color = Color.parseColor("#5D4037")
        // 각 표시 호
        stroke.strokeWidth = dp(2.5f).toFloat()
        stroke.color = Color.parseColor("#FF7043")
        val r = len * 0.28f
        canvas.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), 0f, -deg.toFloat(), false, stroke)
        stroke.color = Color.parseColor("#5D4037")
        fill.color = Color.parseColor("#5D4037")
        canvas.drawCircle(cx, cy, dp(4f).toFloat(), fill)

        if (setMode) {
            // 끝점에 손잡이를 그려서 "여기를 잡아 돌린다"를 알려 준다
            fill.color = Color.parseColor("#42A5F5")
            canvas.drawCircle(
                cx + len * cos(a).toFloat(), cy + len * sin(a).toFloat(),
                dp(14f).toFloat(), fill
            )
            fill.color = Color.WHITE
            canvas.drawCircle(
                cx + len * cos(a).toFloat(), cy + len * sin(a).toFloat(),
                dp(6f).toFloat(), fill
            )
            text.textSize = len * 0.20f
            text.isFakeBoldText = true
            text.color = Color.parseColor("#1565C0")
            canvas.drawText("${setAngle}°", cx + len * 0.55f, cy - len * 0.14f, text)
            text.textSize = len * 0.13f
            text.isFakeBoldText = false
            text.color = Color.parseColor("#8D6E63")
            canvas.drawText("파란 손잡이를 돌려요", w * 0.5f, h - dp(6), text)
            text.isFakeBoldText = true
            text.color = Color.parseColor("#4E342E")
        }
    }

    // ---------- 각도 만들기 ----------
    /**
     * 각도를 **재는** 대신 직접 **만들어 본다.**
     * 5° 단위로 붙게 해서 60°·90° 같은 목표를 손가락으로 맞출 수 있다.
     */
    private var angleCx = 0f
    private var angleCy = 0f
    private var angleLen = 0f

    var setAngle = 0
        private set

    var onAngleChanged: ((Int) -> Unit)? = null

    fun resetAngle() {
        setAngle = 0
        onAngleChanged?.invoke(0)
        invalidate()
    }

    private fun handleAngleTouch(event: android.view.MotionEvent): Boolean {
        if (event.actionMasked == android.view.MotionEvent.ACTION_UP ||
            event.actionMasked == android.view.MotionEvent.ACTION_CANCEL
        ) return true
        val dx = event.x - angleCx
        val dy = event.y - angleCy
        if (kotlin.math.hypot(dx, dy) > angleLen * 1.35f) return false
        parent?.requestDisallowInterceptTouchEvent(true)
        // 위로 열리는 각만 다룬다 (0°~180°)
        var deg = Math.toDegrees(kotlin.math.atan2(-dy.toDouble(), dx.toDouble()))
        if (deg < 0) deg = 0.0
        val snapped = (Math.round(deg / 5.0) * 5).toInt().coerceIn(0, 180)
        if (snapped != setAngle) {
            setAngle = snapped
            onAngleChanged?.invoke(snapped)
            invalidate()
        }
        return true
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
