package com.piyak.english.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * 양팔 저울로 일차방정식 `a·x + b = c` 를 푸는 판.
 *
 * 왼쪽 접시에 x 상자 a개와 1짜리 추 b개, 오른쪽에 1짜리 추 c개가 놓여 있다.
 * 아래 손잡이를 끌어 **x 상자 하나의 무게를 바꾸면 저울이 실시간으로 기울고**,
 * 딱 맞는 값에서 수평이 된다.
 *
 * 이항·移項을 외우기 전에 "양쪽이 같다"는 등식의 의미를 눈으로 보게 하는 것이 목적이다.
 */
class BalanceScaleView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : View(ctx, attrs) {

    private var coef = 3        // x 상자 개수 (a)
    private var leftConst = 2   // 왼쪽 추 (b)
    private var rightConst = 11 // 오른쪽 추 (c)
    private var maxX = 12

    /** 지금 정해 놓은 x 값 */
    var guess = 1
        private set

    var onChanged: ((Int) -> Unit)? = null

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        isFakeBoldText = true
        color = Color.parseColor("#4E342E")
    }

    private var sliderLeft = 0f
    private var sliderRight = 0f
    private var sliderY = 0f

    fun setEquation(coef: Int, leftConst: Int, rightConst: Int) {
        this.coef = coef.coerceAtLeast(1)
        this.leftConst = leftConst
        this.rightConst = rightConst
        val answer = (rightConst - leftConst) / this.coef
        // 정답이 눈금 한가운데쯤 오도록, 그리고 최소 8칸은 되도록
        maxX = (answer * 2).coerceAtLeast(8).coerceAtMost(20)
        guess = 1
        onChanged?.invoke(guess)
        invalidate()
    }

    private fun leftWeight(x: Int) = coef * x + leftConst
    private fun rightWeight() = rightConst

    /** 지금 값으로 저울이 수평인가 */
    fun isBalanced(): Boolean = leftWeight(guess) == rightWeight()

    fun reset() {
        guess = 1
        onChanged?.invoke(guess)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0f) return

        val cx = w / 2f
        val pivotY = h * 0.52f
        val armLen = w * 0.36f

        // 기울기 — 무게 차이에 비례하되 너무 눕지 않게 잘라 낸다
        val diff = leftWeight(guess) - rightWeight()
        val tilt = (diff.toFloat() * 2.2f).coerceIn(-14f, 14f)
        val rad = Math.toRadians(tilt.toDouble())

        // 받침대
        fill.color = Color.parseColor("#8D6E63")
        val base = android.graphics.Path().apply {
            moveTo(cx, pivotY)
            lineTo(cx - w * 0.10f, h * 0.80f)
            lineTo(cx + w * 0.10f, h * 0.80f)
            close()
        }
        canvas.drawPath(base, fill)
        canvas.drawRect(cx - w * 0.16f, h * 0.80f, cx + w * 0.16f, h * 0.84f, fill)

        // 저울대
        val lx = cx - armLen * cos(rad).toFloat()
        val ly = pivotY - armLen * sin(rad).toFloat()
        val rx = cx + armLen * cos(rad).toFloat()
        val ry = pivotY + armLen * sin(rad).toFloat()
        stroke.color = Color.parseColor("#5D4037")
        stroke.strokeWidth = dp(6f)
        stroke.strokeCap = Paint.Cap.ROUND
        canvas.drawLine(lx, ly, rx, ry, stroke)
        fill.color = Color.parseColor("#5D4037")
        canvas.drawCircle(cx, pivotY, dp(7f), fill)

        // 접시 + 올려진 것들
        drawPan(canvas, lx, ly, w, left = true)
        drawPan(canvas, rx, ry, w, left = false)

        // 균형 표시
        text.textSize = dp(17f)
        text.color = if (isBalanced()) Color.parseColor("#2E7D32") else Color.parseColor("#8D6E63")
        canvas.drawText(
            if (isBalanced()) "⚖️ 평형이에요!"
            else if (diff > 0) "왼쪽이 더 무거워요" else "오른쪽이 더 무거워요",
            cx, h * 0.93f, text
        )

        drawSlider(canvas, w, h)
    }

    private fun drawPan(canvas: Canvas, x: Float, y: Float, w: Float, left: Boolean) {
        val panW = w * 0.30f
        val panY = y + dp(30f)
        stroke.color = Color.parseColor("#A1887F")
        stroke.strokeWidth = dp(2f)
        canvas.drawLine(x, y, x, panY, stroke)
        fill.color = Color.parseColor("#D7CCC8")
        canvas.drawRoundRect(
            RectF(x - panW / 2f, panY, x + panW / 2f, panY + dp(8f)), dp(4f), dp(4f), fill
        )

        // 접시 위에 무엇이 놓였는지
        val box = dp(19f)
        var bx = x - panW / 2f + box * 0.6f
        val by = panY - box * 0.7f
        text.textSize = box * 0.62f

        if (left) {
            for (i in 0 until coef) {
                fill.color = Color.parseColor("#FF8A65")
                canvas.drawRoundRect(
                    RectF(bx - box / 2f, by - box / 2f, bx + box / 2f, by + box / 2f),
                    dp(4f), dp(4f), fill
                )
                text.color = Color.WHITE
                canvas.drawText("x", bx, by + text.textSize * 0.35f, text)
                bx += box * 1.12f
            }
            drawWeights(canvas, leftConst, bx, by, box)
        } else {
            drawWeights(canvas, rightConst, bx, by, box)
        }
    }

    /** 1짜리 추 — 많으면 하나만 그리고 개수를 적는다 */
    private fun drawWeights(canvas: Canvas, n: Int, startX: Float, y: Float, box: Float) {
        if (n <= 0) return
        var bx = startX
        val show = if (n <= 5) n else 1
        for (i in 0 until show) {
            fill.color = Color.parseColor("#FFD54F")
            canvas.drawCircle(bx, y, box * 0.42f, fill)
            text.color = Color.parseColor("#5D4037")
            text.textSize = box * 0.5f
            canvas.drawText("1", bx, y + text.textSize * 0.35f, text)
            bx += box * 1.0f
        }
        if (n > 5) {
            text.color = Color.parseColor("#5D4037")
            text.textSize = box * 0.62f
            canvas.drawText("×$n", bx + box * 0.35f, y + text.textSize * 0.35f, text)
        }
    }

    /** x 값을 정하는 손잡이 */
    private fun drawSlider(canvas: Canvas, w: Float, h: Float) {
        sliderLeft = w * 0.12f
        sliderRight = w * 0.88f
        sliderY = h * 0.06f

        stroke.color = Color.parseColor("#BCAAA4")
        stroke.strokeWidth = dp(4f)
        canvas.drawLine(sliderLeft, sliderY, sliderRight, sliderY, stroke)
        // 눈금
        stroke.strokeWidth = dp(1.5f)
        for (i in 1..maxX) {
            val x = sliderLeft + (sliderRight - sliderLeft) * (i - 1) / (maxX - 1).toFloat()
            canvas.drawLine(x, sliderY - dp(5f), x, sliderY + dp(5f), stroke)
        }

        val kx = sliderLeft + (sliderRight - sliderLeft) * (guess - 1) / (maxX - 1).toFloat()
        fill.color = Color.parseColor("#42A5F5")
        canvas.drawCircle(kx, sliderY, dp(15f), fill)
        fill.color = Color.WHITE
        canvas.drawCircle(kx, sliderY, dp(6f), fill)

        text.color = Color.parseColor("#1565C0")
        text.textSize = dp(18f)
        canvas.drawText("x = $guess", kx, sliderY + dp(36f), text)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> return true
        }
        if (abs(event.y - sliderY) > dp(46f)) return false
        if (sliderRight <= sliderLeft) return false
        parent?.requestDisallowInterceptTouchEvent(true)

        val t = ((event.x - sliderLeft) / (sliderRight - sliderLeft)).coerceIn(0f, 1f)
        val v = 1 + Math.round(t * (maxX - 1))
        if (v != guess) {
            guess = v
            onChanged?.invoke(v)
            invalidate()
        }
        return true
    }

    private fun dp(v: Float): Float = v * resources.displayMetrics.density
}
