package com.piyak.english.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import kotlin.math.hypot
import kotlin.math.min

/**
 * 사물을 손으로 끌어다 바구니에 담는 판. 두 가지로 쓴다.
 *
 * - **나눠 담기**(`setRound`) : 같은 사물을 바구니에 **똑같은 개수**로 나눠 담는다 (나눗셈).
 * - **분류하기**(`setSort`) : 사물마다 들어갈 바구니가 정해져 있다 (도형 분류).
 *
 * 어느 쪽이든 머리로 계산하거나 고르기 전에 **직접 옮겨 보는** 것이 핵심이다.
 */
class GroupDragView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : View(ctx, attrs) {

    private class Item(
        val emoji: String,
        /** 들어가야 할 바구니. -1 이면 아무 데나 (나눠 담기 모드) */
        val kind: Int,
        var x: Float, var y: Float,
        var homeX: Float, var homeY: Float,
        /** 지금 담긴 바구니. -1 이면 아직 안 담김 */
        var group: Int = -1,
    )

    private val items = ArrayList<Item>()
    private var groupRects = ArrayList<RectF>()
    private var dragging: Item? = null
    private var dragDx = 0f
    private var dragDy = 0f

    private var specs = ArrayList<Pair<String, Int>>()   // (이모지, 들어갈 바구니)
    private var groups = 3
    private var labels = emptyList<String>()

    /** 분류 모드인가 (아니면 똑같이 나눠 담기) */
    private var sortMode = false

    /** 바구니 하나에 정해진 개수만 담는 모드 (모으기·덜어내기). -1 이면 안 씀 */
    private var needCount = -1

    private val emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
    private val boxPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
    }

    private var itemSize = 0f

    /** 담긴 상태가 바뀔 때 (바구니별 개수) */
    var onChanged: ((List<Int>) -> Unit)? = null

    /** 바구니에 하나 담을 때마다 */
    var onPlace: (() -> Unit)? = null

    /** 똑같이 나눠 담기 — 같은 사물 total 개를 바구니 groups 개에 나눈다 */
    fun setRound(emoji: String, total: Int, groups: Int) {
        sortMode = false
        needCount = -1
        this.groups = groups.coerceAtLeast(1)
        labels = (1..this.groups).map { "${it}번" }
        specs = ArrayList((0 until total).map { emoji to -1 })
        rebuild()
    }

    /**
     * 바구니 하나에 손으로 옮겨 담기.
     * 덧셈은 전부 모으고(`need == total`), 뺄셈은 덜어낼 만큼만 담는다.
     * 수를 계산해서 쓰는 대신 **실제로 옮겨 보고 세는** 방식이다.
     */
    fun setGather(emoji: String, total: Int, need: Int, label: String) {
        sortMode = false
        needCount = need
        groups = 1
        labels = listOf(label)
        specs = ArrayList((0 until total).map { emoji to -1 })
        rebuild()
    }

    /** 아직 바구니 밖에 남아 있는 개수 */
    fun outsideCount(): Int = items.count { it.group < 0 }

    /** 바구니에 담긴 개수 */
    fun inBoxCount(): Int = items.count { it.group == 0 }

    /** 분류하기 — items[i] 는 labels[kinds[i]] 바구니에 들어가야 한다 */
    fun setSort(items: List<String>, kinds: List<Int>, labels: List<String>) {
        sortMode = true
        this.groups = labels.size.coerceAtLeast(1)
        this.labels = labels
        specs = ArrayList(items.mapIndexed { i, e -> e to (kinds.getOrNull(i) ?: 0) })
        rebuild()
    }

    private fun rebuild() {
        items.clear()
        layoutAll()
        onChanged?.invoke(counts())
        invalidate()
    }

    /** 바구니별 담긴 개수 */
    fun counts(): List<Int> = (0 until groups).map { g -> items.count { it.group == g } }

    /** 아직 안 담은 개수 */
    fun leftOver(): Int = items.count { it.group < 0 }

    /** 엉뚱한 바구니에 담긴 개수 (분류 모드에서만 의미 있다) */
    fun misplaced(): Int = items.count { it.group >= 0 && it.kind >= 0 && it.group != it.kind }

    fun isCorrect(): Boolean {
        if (items.isEmpty()) return false
        // 모으기·덜어내기는 바구니 밖에 남는 게 정상이다
        if (needCount >= 0) return inBoxCount() == needCount
        if (leftOver() > 0) return false
        return if (sortMode) {
            misplaced() == 0
        } else {
            val c = counts()
            c.isNotEmpty() && c.all { it == c[0] } && c[0] > 0
        }
    }

    /** 한 바구니에 담긴 개수 (나눠 담기 정답일 때의 몫) */
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
        if (width == 0 || height == 0 || specs.isEmpty()) return
        val w = width.toFloat()
        val h = height.toFloat()
        val total = specs.size

        // 아래쪽을 바구니 자리로
        val zoneTop = h * 0.50f
        groupRects = ArrayList()
        val gw = (w - dp(10f) * (groups + 1)) / groups
        for (g in 0 until groups) {
            val left = dp(10f) + (gw + dp(10f)) * g
            groupRects.add(RectF(left, zoneTop, left + gw, h - dp(8f)))
        }

        val perRow = min(6, total)
        val rows = (total + perRow - 1) / perRow
        itemSize = min(w / (perRow + 1.2f), (zoneTop - dp(16f)) / (rows + 0.6f))
        textPaint.textSize = itemSize * 0.48f

        // 이미 담아 놓은 걸 잃지 않도록, 크기만 바뀌면 자리만 다시 잡는다
        val keep = items.size == total
        if (!keep) items.clear()
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
                val (e, kind) = specs[i]
                items.add(Item(e, kind, x, y, x, y))
            }
        }
        if (keep) for (g in 0 until groups) {
            items.filter { it.group == g }.forEach { placeInGroup(it, g) }
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (items.isEmpty()) return

        for ((g, rect) in groupRects.withIndex()) {
            val n = items.count { it.group == g }
            boxPaint.color = Color.parseColor(if (n > 0) "#FFF3E0" else "#FAFAFA")
            canvas.drawRoundRect(rect, dp(16f), dp(16f), boxPaint)
            strokePaint.color = Color.parseColor("#FFB300")
            strokePaint.strokeWidth = dp(3f)
            strokePaint.pathEffect = DashPathEffect(floatArrayOf(dp(10f), dp(8f)), 0f)
            canvas.drawRoundRect(rect, dp(16f), dp(16f), strokePaint)
            strokePaint.pathEffect = null

            // 바구니 이름은 위에 (담은 것과 겹치지 않게)
            textPaint.color = Color.parseColor("#8D6E63")
            canvas.drawText(
                labels.getOrElse(g) { "${g + 1}번" } + if (sortMode) "" else "  ($n)",
                rect.centerX(), rect.top + textPaint.textSize * 1.1f, textPaint
            )
        }

        for (it in items) {
            if (it === dragging) continue
            emojiPaint.textSize = if (it.group >= 0) itemSize * 0.74f else itemSize
            canvas.drawText(it.emoji, it.x, it.y + emojiPaint.textSize * 0.35f, emojiPaint)
        }
        dragging?.let {
            emojiPaint.textSize = itemSize * 1.18f
            canvas.drawText(it.emoji, it.x, it.y + emojiPaint.textSize * 0.35f, emojiPaint)
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
        val rect = groupRects.getOrNull(g) ?: return
        val idx = items.filter { it.group == g }.indexOf(item).coerceAtLeast(0)
        val top = rect.top + textPaint.textSize * 1.5f
        val slot = itemSize * 0.84f
        // 바구니가 넓으면 한 줄에 더 많이 (모으기는 바구니가 하나뿐이라 아주 넓다)
        val perRow = (rect.width() / slot).toInt().coerceIn(2, 8)
        item.x = rect.left + slot * (idx % perRow) + slot * 0.6f
        item.y = top + slot * (idx / perRow) + slot * 0.5f
    }

    private fun dp(v: Float): Float = v * resources.displayMetrics.density
}
