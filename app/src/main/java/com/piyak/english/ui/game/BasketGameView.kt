package com.piyak.english.ui.game

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.MotionEvent
import com.piyak.english.engine.GameRound
import kotlin.math.hypot
import kotlin.random.Random

/**
 * 바구니에 담기.
 * 위에 흩어진 사물을 손가락으로 끌어 바구니에 넣는다. 목표 개수만큼 담고 "다 담았어요"를 누른다.
 * 잘못 담았으면 다시 꺼낼 수도 있다(바구니에서 위로 끌기).
 */
class BasketGameView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : GameView(ctx, attrs) {

    private class Item(
        var x: Float, var y: Float,
        var homeX: Float, var homeY: Float,
        var inBasket: Boolean = false,
        var scale: Float = 1f,
    )

    private val rnd = Random(System.currentTimeMillis())
    private val items = ArrayList<Item>()
    private var dragging: Item? = null
    private var dragDx = 0f
    private var dragDy = 0f

    private var emoji = "🍎"
    private var target = 5
    private var pool = 12

    private val emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
    private val basketPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.parseColor("#A1887F")
    }
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        color = Color.parseColor("#4E342E")
        isFakeBoldText = true
    }

    private var itemSize = 0f
    private var basket = RectF()

    /** 지금 바구니에 담긴 개수 */
    val countInBasket: Int get() = items.count { it.inBasket }

    /** 목표 개수 */
    val targetCount: Int get() = target

    fun setRound(r: GameRound) {
        emoji = r.emoji ?: "🍎"
        target = r.answer.toIntOrNull() ?: 5
        pool = (target + 4).coerceAtMost(16)
        layoutItems()
        r.speak?.let { onSpeak?.invoke(it) }
        invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        itemSize = minOf(w, h) * 0.115f
        emojiPaint.textSize = itemSize
        textPaint.textSize = itemSize * 0.62f
        linePaint.strokeWidth = dp(3f)
        val bw = w * 0.62f
        val bh = h * 0.26f
        basket = RectF((w - bw) / 2f, h - bh - dp(12f), (w + bw) / 2f, h - dp(12f))
        layoutItems()
    }

    private fun layoutItems() {
        if (width == 0 || height == 0) return
        items.clear()
        val perRow = 5
        val topArea = basket.top - dp(20f)
        val cellW = width / perRow.toFloat()
        val rows = (pool + perRow - 1) / perRow
        val cellH = (topArea * 0.75f) / rows
        for (i in 0 until pool) {
            val r = i / perRow
            val c = i % perRow
            val x = cellW * (c + 0.5f) + (rnd.nextFloat() - 0.5f) * cellW * 0.2f
            val y = dp(20f) + cellH * (r + 0.6f)
            items.add(Item(x, y, x, y))
        }
    }

    override fun update(dt: Float) {
        // 담긴 항목이 살짝 작아지는 연출
        for (it in items) {
            val want = if (it.inBasket) 0.78f else 1f
            it.scale += (want - it.scale) * (dt * 8f).coerceAtMost(1f)
        }
    }

    override fun render(canvas: Canvas) {
        // 바구니
        basketPaint.color = Color.parseColor("#D7A86E")
        canvas.drawRoundRect(basket, dp(18f), dp(18f), basketPaint)
        basketPaint.color = Color.parseColor("#C08B4E")
        canvas.drawRoundRect(
            RectF(basket.left, basket.top, basket.right, basket.top + dp(14f)),
            dp(8f), dp(8f), basketPaint
        )
        // 바구니 무늬
        var gx = basket.left + dp(14f)
        while (gx < basket.right - dp(6f)) {
            canvas.drawLine(gx, basket.top + dp(16f), gx, basket.bottom - dp(8f), linePaint)
            gx += dp(22f)
        }

        // 담긴 개수 / 목표
        textPaint.color = Color.parseColor("#4E342E")
        canvas.drawText(
            "$countInBasket / $target",
            basket.centerX(), basket.bottom - dp(14f), textPaint
        )

        // 사물
        for (it in items) {
            emojiPaint.textSize = itemSize * it.scale
            canvas.drawText(emoji, it.x, it.y + emojiPaint.textSize * 0.35f, emojiPaint)
        }
        // 끌고 있는 것은 맨 위에 다시 그린다
        dragging?.let {
            emojiPaint.textSize = itemSize * 1.15f
            canvas.drawText(emoji, it.x, it.y + emojiPaint.textSize * 0.35f, emojiPaint)
        }
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                dragging = items.lastOrNull { hypot(event.x - it.x, event.y - it.y) < itemSize * 0.75f }
                dragging?.let {
                    dragDx = it.x - event.x
                    dragDy = it.y - event.y
                }
                parent?.requestDisallowInterceptTouchEvent(true)
                invalidate()
                return true
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
                val inside = basket.contains(d.x, d.y)
                if (inside) {
                    if (!d.inBasket) {
                        d.inBasket = true
                        // 바구니 안에서 겹치지 않게 자리 잡기
                        val n = items.count { it.inBasket } - 1
                        val perRow = 5
                        val cw = basket.width() / perRow
                        val ch = (basket.height() - dp(30f)) / 3f
                        d.x = basket.left + cw * (n % perRow + 0.5f)
                        d.y = basket.top + dp(22f) + ch * (n / perRow + 0.4f)
                    }
                } else {
                    // 바구니 밖으로 꺼내면 원래 자리로
                    d.inBasket = false
                    d.x = d.homeX
                    d.y = d.homeY
                }
                invalidate()
                return true
            }
        }
        return true
    }

    /** "다 담았어요"를 눌렀을 때 채점 */
    fun check(): Boolean {
        val ok = countInBasket == target
        if (ok) onHit?.invoke() else onMiss?.invoke()
        return ok
    }
}
