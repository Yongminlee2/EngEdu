package com.piyak.english.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View

/**
 * 문제 위에 겹쳐 쓰는 연습장.
 * 배경이 투명해서 문제·그림(시계·도형)이 그대로 비치고, 그 위에 식을 쓰거나 표시할 수 있다.
 *
 * 획 목록을 들고 있다가 비트맵에 다시 그리는 방식이라 되돌리기가 간단하고,
 * 지우개는 비트맵에 PorterDuff.CLEAR 로 진짜 지운다.
 */
class ScratchPadView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : View(ctx, attrs) {

    private class Stroke(
        val path: Path,
        val color: Int,
        val width: Float,
        val eraser: Boolean,
    )

    private val strokes = ArrayList<Stroke>()
    private var current: Stroke? = null

    private var bitmap: Bitmap? = null
    private var bitmapCanvas: Canvas? = null

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val clearMode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)

    /** 지금 쓰고 있는 펜 */
    var penColor: Int = Color.parseColor("#3E2723")
    var penWidth: Float = 6f
    var eraserMode: Boolean = false

    /** 획 수가 바뀔 때 (버튼 활성화용) */
    var onChanged: (() -> Unit)? = null

    val isEmpty: Boolean get() = strokes.isEmpty()

    init {
        setLayerType(LAYER_TYPE_SOFTWARE, null) // PorterDuff.CLEAR 는 소프트웨어 레이어에서 안전하다
        isClickable = true
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w <= 0 || h <= 0) return
        bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bitmapCanvas = Canvas(bitmap!!)
        redraw()
    }

    private fun applyPaint(s: Stroke) {
        paint.strokeWidth = s.width * resources.displayMetrics.density
        if (s.eraser) {
            paint.xfermode = clearMode
            paint.color = Color.TRANSPARENT
        } else {
            paint.xfermode = null
            paint.color = s.color
        }
    }

    /** 획 목록을 비트맵에 처음부터 다시 그린다 (되돌리기·지우기 후) */
    private fun redraw() {
        val c = bitmapCanvas ?: return
        c.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
        for (s in strokes) {
            applyPaint(s)
            c.drawPath(s.path, paint)
        }
        invalidate()
    }

    fun undo() {
        if (strokes.isEmpty()) return
        strokes.removeAt(strokes.size - 1)
        redraw()
        onChanged?.invoke()
    }

    fun clearAll() {
        if (strokes.isEmpty()) return
        strokes.clear()
        redraw()
        onChanged?.invoke()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                val path = Path().apply { moveTo(event.x, event.y) }
                // 점 하나만 찍어도 보이도록 아주 짧은 선을 그어 둔다
                path.lineTo(event.x + 0.1f, event.y + 0.1f)
                current = Stroke(path, penColor, if (eraserMode) penWidth * 4 else penWidth, eraserMode)
                strokes.add(current!!)
                drawCurrent()
                parent?.requestDisallowInterceptTouchEvent(true)
                onChanged?.invoke()
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                val s = current ?: return false
                for (h in 0 until event.historySize) {
                    s.path.lineTo(event.getHistoricalX(h), event.getHistoricalY(h))
                }
                s.path.lineTo(event.x, event.y)
                drawCurrent()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                current = null
                return true
            }
        }
        return false
    }

    /** 지금 획만 비트맵에 덧그린다 (매번 전체를 다시 그리면 느리다) */
    private fun drawCurrent() {
        val s = current ?: return
        val c = bitmapCanvas ?: return
        applyPaint(s)
        c.drawPath(s.path, paint)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        bitmap?.let { canvas.drawBitmap(it, 0f, 0f, null) }
    }
}
