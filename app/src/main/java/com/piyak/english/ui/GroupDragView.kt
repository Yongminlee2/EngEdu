package com.piyak.english.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import kotlin.math.hypot
import kotlin.math.min

/**
 * 나눗셈 "똑같이 나누기"를 손으로 해 보는 판.
 * 위에 흩어진 사물을 아래 묶음(바구니)으로 끌어다 담는다.
 * 모든 사물을 담고 묶음마다 개수가 같아지면 정답.
 *
 * 12 ÷ 3 을 머리로 계산하는 대신 **실제로 나눠 담아 보는** 경험을 준다.
 */
class GroupDragView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : View(ctx, attrs) {

    private class Item(
        var x: Float, var y: Float,
        var homeX: Float, var homeY: Float,
        /** -1 이면 아직 안 담김 */
        var group: Int = -1,
    )

    private val items = ArrayList<Item>()
    private var groupRects = ArrayList<RectF>()
    private var dragging: Item? = null
    private var dragDx = 0f
    private var dragDy = 0f

    private var emoji = "🐧"
    private var total = 12
    private var groups = 3

    private val emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
    private val boxPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
    }

    private var itemSize = 0f

    /** 담긴 개수가 바뀔 때 (묶음별 개수) */
    var onChanged: ((List<Int>) -> Unit)? = null
    var onPlace: (() -> Unit)? = null

    fun setRound(emoji: String, total: Int, groups: Int) {
        this.emoji = emoji
        this.total = total
        this.groups = groups.coerceAtLeast(1)
        layoutAll()
        invalidate()
    }

    /** 묶음별 담긴 개수 */
    fun counts(): List<Int> = (0 until groups).map { g -> items.count { it.group == g } }

    /** 다 담았고 묶음마다 개수가 같은가 */
    fun isCorrect(): Boolean {
        if (items.any { it.group < 0 }) return false
        val c = counts()
        return c.isNotEmpty() && c.all { it == c[0] } && c[0] > 0
    }

    /** 한 묶음에 담긴 개수 (정답일 때의 몫) */
    fun perGroup(): Int = counts().firstOrNull() ?: 0

    fun reset() {
        for (it in items) {
            it.group = -1
            it.x = it.homeX
            it.y = it.homeY
        }
        onChanged?.invoke(counts())
        invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        layoutAll()
    }

    private fun layoutAll() {
        if (width == 0 || height == 0) return
        val w = width.toFloat()
        val h = height.toFloat()

        // 아래쪽 절반을 묶음 바구니로
        val zoneTop = h * 0.52f
        groupRects = ArrayList()
        val gw = (w - dp(10f) * (groups + 1)) / groups
        for (g in 0 until groups) {
            val left = dp(10f) + (gw + dp(10f)) * g
            groupRects.add(RectF(left, zoneTop, left + gw, h - dp(24f)))
        }

        // 위쪽에 사물 배치
        val perRow = min(6, total)
        val rows = (total + perRow - 1) / perRow
        itemSize = min(w / (perRow + 1.2f), (zoneTop - dp(16f)) / (rows + 0.6f))
        emojiPaint.textSize = itemSize
        textPaint.textSize = itemSize * 0.55f

        // 화면이 다시 재어질 때 이미 담아 놓은 걸 잃지 않도록 자리만 다시 잡는다
        val keep = items.size == total
        for (i in 0 until total) {
            val r = i / perRow
            val c = i % perRow
            val cols = min(perRow, total - r * perRow)
            val rowW = cols * itemSize * 1.15f
            val x = (w - rowW) / 2f + itemSize * 1.15f * (c + 0.5f)
            val y = dp(14f) + itemSize * 1.05f * (r + 0.5f)
            if (keep) {
                val it = items[i]
                it.homeX = x; it.homeY = y
                if (it.group < 0) { it.x = x; it.y = y }
            } else {
                if (i == 0) items.clear()
                items.add(Item(x, y, x, y))
            }
        }
        if (keep) for (g in 0 until groups) {
            items.filter { it.group == g }.forEach { placeInGroup(it, g) }
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        // 묶음 바구니
        for ((g, rect) in groupRects.withIndex()) {
            val n = items.count { it.group == g }
            boxPaint.color = Color.parseColor(if (n > 0) "#FFF3E0" else "#FAFAFA")
            canvas.drawRoundRect(rect, dp(16f), dp(16f), boxPaint)
            strokePaint.color = Color.parseColor("#FFB300")
            strokePaint.strokeWidth = dp(3f)
            strokePaint.pathEffect = android.graphics.DashPathEffect(
                floatArrayOf(dp(10f), dp(8f)), 0f
            )
            canvas.drawRoundRect(rect, dp(16f), dp(16f), strokePaint)
            strokePaint.pathEffect = null

            textPaint.color = Color.parseColor("#8D6E63")
            canvas.drawText(
                "${g + 1}번  ($n)",
                rect.centerX(), rect.bottom - dp(6f), textPaint
            )
        }

        // 사물
        for (it in items) {
            if (it === dragging) continue
            emojiPaint.textSize = if (it.group >= 0) itemSize * 0.78f else itemSize
            canvas.drawText(emoji, it.x, it.y + emojiPaint.textSize * 0.35f, emojiPaint)
        }
        dragging?.let {
            emojiPaint.textSize = itemSize * 1.18f
            canvas.drawText(emoji, it.x, it.y + emojiPaint.textSize * 0.35f, emojiPaint)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                dragging = items.lastOrNull {
                    hypot(event.x - it.x, event.y - it.y) < itemSize * 0.7f
                }
                dragging?.let { dragDx = it.x - event.x; dragDy = it.y - event.y }
                parent?.requestDisallowInterceptTouchEvent(true)
                invalidate()
                return dragging != null
            }
            MotionEvent.ACTION_MOVE -> {
                dragging?.let {
                    it.x = event.x + dragDx
                    it.y = event.y + dragDy
                    invalidate()
                }
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                val d = dragging ?: return true
                dragging = null
                val gi = groupRects.indexOfFirst { it.contains(d.x, d.y) }
                if (gi >= 0) {
                    d.group = gi
                    placeInGroup(d, gi)
                    onPlace?.invoke()
                } else {
                    d.group = -1
                    d.x = d.homeX
                    d.y = d.homeY
                }
                onChanged?.invoke(counts())
                invalidate()
                return true
            }
        }
        return false
    }

    /** 바구니 안에서 겹치지 않게 자리 잡기 */
    private fun placeInGroup(item: Item, g: Int) {
        val rect = groupRects[g]
        val idx = items.filter { it.group == g }.indexOf(item).coerceAtLeast(0)
        val perRow = 3
        val cw = rect.width() / perRow
        val ch = (rect.height() - dp(22f)) / 3f
        item.x = rect.left + cw * (idx % perRow + 0.5f)
        item.y = rect.top + dp(8f) + ch * (idx / perRow + 0.5f)
    }

    private fun dp(v: Float): Float = v * resources.displayMetrics.density
}
