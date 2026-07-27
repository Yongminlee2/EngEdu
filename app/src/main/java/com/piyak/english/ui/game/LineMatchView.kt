package com.piyak.english.ui.game

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.MotionEvent
import kotlin.math.hypot
import kotlin.random.Random

/**
 * 선으로 잇기.
 * 왼쪽 항목에서 손가락을 눌러 오른쪽 항목까지 끌면 선이 그어진다.
 * 짝이 맞으면 선이 남고, 틀리면 선이 사라진다. 네 쌍을 다 이으면 끝.
 */
class LineMatchView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : GameView(ctx, attrs) {

    private class Node(val text: String, val key: Int, var box: RectF = RectF())

    private val rnd = Random(System.currentTimeMillis())
    private val left = ArrayList<Node>()
    private val right = ArrayList<Node>()
    private val matched = LinkedHashMap<Int, Int>()   // key → key (이어진 짝)

    private var dragFrom: Node? = null
    private var dragX = 0f
    private var dragY = 0f
    private var shakeKey = -1
    private var shakeTime = 0f

    private val colors = listOf(
        "#FF8A80", "#FFD54F", "#80CBC4", "#81D4FA", "#B39DDB", "#A5D6A7",
    ).map { Color.parseColor(it) }

    private val boxPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.parseColor("#FFE082")
    }
    private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        color = Color.parseColor("#4E342E")
        isFakeBoldText = true
    }

    val isCleared: Boolean get() = left.isNotEmpty() && matched.size == left.size

    /** (왼쪽, 오른쪽) 짝 목록을 넣는다 */
    fun setPairs(pairs: List<Pair<String, String>>) {
        left.clear(); right.clear(); matched.clear()
        pairs.forEachIndexed { i, (l, _) -> left.add(Node(l, i)) }
        pairs.mapIndexed { i, (_, r) -> Node(r, i) }.shuffled(rnd).forEach { right.add(it) }
        layoutNodes()
        invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        strokePaint.strokeWidth = dp(2.5f)
        linePaint.strokeWidth = dp(6f)
        layoutNodes()
    }

    private fun layoutNodes() {
        if (width == 0 || height == 0 || left.isEmpty()) return
        val n = left.size
        val boxW = width * 0.36f
        val boxH = (height * 0.82f) / n - dp(10f)
        val topPad = height * 0.09f
        textPaint.textSize = (boxH * 0.42f).coerceAtMost(dp(24f))
        for (i in 0 until n) {
            val top = topPad + (boxH + dp(10f)) * i
            left[i].box = RectF(dp(10f), top, dp(10f) + boxW, top + boxH)
            right[i].box = RectF(width - dp(10f) - boxW, top, width - dp(10f), top + boxH)
        }
    }

    override fun update(dt: Float) {
        if (shakeTime > 0f) {
            shakeTime -= dt
            if (shakeTime <= 0f) shakeKey = -1
        }
    }

    override fun render(canvas: Canvas) {
        // 이어진 선
        for ((lk, rk) in matched) {
            val l = left.firstOrNull { it.key == lk } ?: continue
            val r = right.firstOrNull { it.key == rk } ?: continue
            linePaint.color = colors[lk % colors.size]
            canvas.drawLine(l.box.right, l.box.centerY(), r.box.left, r.box.centerY(), linePaint)
        }
        // 끌고 있는 선
        dragFrom?.let {
            linePaint.color = Color.parseColor("#8D6E63")
            canvas.drawLine(it.box.right, it.box.centerY(), dragX, dragY, linePaint)
        }

        drawColumn(canvas, left, true)
        drawColumn(canvas, right, false)
    }

    private fun drawColumn(canvas: Canvas, nodes: List<Node>, isLeft: Boolean) {
        for (node in nodes) {
            val done = if (isLeft) matched.containsKey(node.key) else matched.containsValue(node.key)
            val shaking = shakeKey == node.key && shakeTime > 0f
            val dx = if (shaking) (kotlin.math.sin(shakeTime * 60.0).toFloat() * dp(5f)) else 0f
            val box = RectF(node.box)
            box.offset(dx, 0f)

            boxPaint.color = if (done) colors[node.key % colors.size] else Color.WHITE
            canvas.drawRoundRect(box, dp(16f), dp(16f), boxPaint)
            strokePaint.color = if (done) Color.parseColor("#66BB6A") else Color.parseColor("#FFE082")
            canvas.drawRoundRect(box, dp(16f), dp(16f), strokePaint)

            val isEmoji = node.text.isNotEmpty() && node.text[0].code > 0x2000
            textPaint.textSize = if (isEmoji) box.height() * 0.55f else (box.height() * 0.36f)
                .coerceAtMost(dp(22f))
            textPaint.color = if (done) Color.WHITE else Color.parseColor("#4E342E")
            canvas.drawText(node.text, box.centerX(), box.centerY() + textPaint.textSize * 0.35f, textPaint)

            // 연결점
            boxPaint.color = if (done) Color.parseColor("#66BB6A") else Color.parseColor("#FFB300")
            val cx = if (isLeft) box.right else box.left
            canvas.drawCircle(cx, box.centerY(), dp(7f), boxPaint)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                // 아직 안 이어진 왼쪽 항목에서만 시작
                dragFrom = left.firstOrNull {
                    !matched.containsKey(it.key) && it.box.contains(event.x, event.y)
                }
                dragX = event.x; dragY = event.y
                parent?.requestDisallowInterceptTouchEvent(true)
                invalidate()
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                if (dragFrom != null) {
                    dragX = event.x; dragY = event.y
                    invalidate()
                }
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val from = dragFrom
                dragFrom = null
                if (from != null) {
                    val hit = right.firstOrNull {
                        !matched.containsValue(it.key) && it.box.contains(event.x, event.y)
                    }
                    if (hit != null) {
                        if (hit.key == from.key) {
                            matched[from.key] = hit.key
                            onHit?.invoke()
                            if (isCleared) onFinish?.invoke()
                        } else {
                            shakeKey = hit.key
                            shakeTime = 0.35f
                            onMiss?.invoke()
                        }
                    }
                }
                invalidate()
                return true
            }
        }
        return true
    }

    /** 가장 가까운 오른쪽 항목까지의 거리 (테스트·디버깅용) */
    fun nearestRightDistance(x: Float, y: Float): Float =
        right.minOfOrNull { hypot(x - it.box.centerX(), y - it.box.centerY()) } ?: Float.MAX_VALUE
}
