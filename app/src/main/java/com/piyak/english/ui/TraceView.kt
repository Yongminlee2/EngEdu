package com.piyak.english.ui

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import com.piyak.english.engine.Pt
import kotlin.math.hypot
import kotlin.random.Random

/**
 * 알파벳 따라쓰기 판.
 * 획(중심선)을 "길"처럼 그려 주고, 손가락·펜이 그 길의 체크포인트를 순서대로 지나가면 획이 완성된다.
 * 순서·방향을 익히도록 병아리가 길을 따라 걸어가는 시범 애니메이션을 제공한다.
 */
class TraceView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : View(ctx, attrs) {

    // ---- 입력 데이터 ----
    private var strokes: List<List<Pt>> = emptyList()
    private var glyph: String = ""

    /** 획 완성 콜백 (0부터) */
    var onStrokeDone: ((Int) -> Unit)? = null

    /** 글자 전체 완성 콜백 */
    var onAllDone: (() -> Unit)? = null

    /** 길에서 벗어나 실패했을 때 (다시 그리기) */
    var onStrokeFail: (() -> Unit)? = null

    // ---- 진행 상태 ----
    private var strokeIdx = 0
    private var checkIdx = 0
    private var checkpoints: List<List<PointF>> = emptyList()
    private val userPaths = ArrayList<Path>()
    private var currentPath: Path? = null
    private var drawing = false

    val isFinished: Boolean get() = strokes.isNotEmpty() && strokeIdx >= strokes.size

    /** 지금까지 완성한 획 수 */
    val doneStrokes: Int get() = strokeIdx

    /** 이 글자의 전체 획 수 */
    val totalStrokes: Int get() = strokes.size

    // ---- 시범 애니메이션 ----
    private var demoAnim: ValueAnimator? = null
    private var demoPos: PointF? = null
    private var demoTrail = ArrayList<PointF>()

    // ---- 축하 애니메이션 ----
    private class Confetti(
        var x: Float, var y: Float, var vx: Float, var vy: Float,
        val color: Int, val size: Float, var rot: Float, val spin: Float,
    )

    private val confetti = ArrayList<Confetti>()
    private var confettiAnim: ValueAnimator? = null

    // ---- 페인트 ----
    private val bgGlyphPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#22FFB300")
        textAlign = Paint.Align.CENTER
        typeface = android.graphics.Typeface.create(android.graphics.Typeface.SANS_SERIF, android.graphics.Typeface.BOLD)
    }
    private val roadPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.parseColor("#FFF0CC")
    }
    private val roadActivePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.parseColor("#FFE082")
    }
    private val dashPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        color = Color.parseColor("#66FFB300")
    }
    private val donePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.parseColor("#FFB300")
    }
    private val inkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = Color.parseColor("#FF7043")
    }
    private val startPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#66BB6A") }
    private val startTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textAlign = Paint.Align.CENTER
        typeface = android.graphics.Typeface.DEFAULT_BOLD
    }
    private val emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
    private val confettiPaint = Paint(Paint.ANTI_ALIAS_FLAG)

    // ---- 좌표 변환 ----
    private var box = 0f
    private var offX = 0f
    private var offY = 0f

    private fun toPx(pt: Pt) = PointF(offX + pt.x * box, offY + pt.y * box)

    fun setLetter(newStrokes: List<List<Pt>>, glyphText: String) {
        strokes = newStrokes
        glyph = glyphText
        reset()
    }

    fun reset() {
        cancelDemo()
        strokeIdx = 0
        checkIdx = 0
        userPaths.clear()
        currentPath = null
        drawing = false
        confetti.clear()
        confettiAnim?.cancel()
        rebuild()
        invalidate()
    }

    /** 지금 획만 다시 */
    private fun resetCurrentStroke() {
        checkIdx = 0
        currentPath = null
        invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        rebuild()
    }

    private fun rebuild() {
        if (width == 0 || height == 0) return
        val pad = 0.10f
        box = minOf(width, height) * (1f - pad * 2)
        offX = (width - box) / 2f
        offY = (height - box) / 2f

        roadPaint.strokeWidth = box * 0.16f
        roadActivePaint.strokeWidth = box * 0.16f
        donePaint.strokeWidth = box * 0.11f
        inkPaint.strokeWidth = box * 0.10f
        dashPaint.strokeWidth = box * 0.012f
        dashPaint.pathEffect = android.graphics.DashPathEffect(
            floatArrayOf(box * 0.035f, box * 0.045f), 0f
        )
        bgGlyphPaint.textSize = box * 1.15f
        startTextPaint.textSize = box * 0.075f
        emojiPaint.textSize = box * 0.16f

        // 체크포인트: 획을 일정 간격으로 리샘플링
        val spacing = box * 0.035f
        checkpoints = strokes.map { resample(it.map { pt -> toPx(pt) }, spacing) }
    }

    private fun resample(pts: List<PointF>, spacing: Float): List<PointF> {
        if (pts.size < 2) return pts
        val out = ArrayList<PointF>()
        out.add(pts[0])
        var carry = 0f
        for (i in 0 until pts.size - 1) {
            val a = pts[i]
            val bb = pts[i + 1]
            val seg = hypot(bb.x - a.x, bb.y - a.y)
            if (seg <= 0.0001f) continue
            var d = spacing - carry
            while (d <= seg) {
                val t = d / seg
                out.add(PointF(a.x + (bb.x - a.x) * t, a.y + (bb.y - a.y) * t))
                d += spacing
            }
            carry = seg - (d - spacing)
        }
        if (out.last() != pts.last()) out.add(pts.last())
        return out
    }

    private fun pathOf(pts: List<PointF>): Path {
        val path = Path()
        if (pts.isEmpty()) return path
        path.moveTo(pts[0].x, pts[0].y)
        for (i in 1 until pts.size) path.lineTo(pts[i].x, pts[i].y)
        return path
    }

    // ---- 시범 애니메이션 (병아리가 길을 걸어감) ----
    fun playDemo() {
        if (isFinished || checkpoints.isEmpty()) return
        cancelDemo()
        val pts = checkpoints.getOrNull(strokeIdx) ?: return
        demoTrail = ArrayList()
        demoAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = (900L + pts.size * 18L).coerceAtMost(2600L)
            addUpdateListener { va ->
                val t = va.animatedValue as Float
                val idx = ((pts.size - 1) * t).toInt().coerceIn(0, pts.size - 1)
                demoPos = pts[idx]
                demoTrail = ArrayList(pts.subList(0, idx + 1))
                invalidate()
            }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    demoPos = null
                    demoTrail.clear()
                    invalidate()
                }
            })
            start()
        }
    }

    private fun cancelDemo() {
        demoAnim?.cancel()
        demoAnim = null
        demoPos = null
        demoTrail.clear()
    }

    // ---- 축하 ----
    private fun celebrate() {
        val colors = listOf("#FFD54F", "#FF8A80", "#80CBC4", "#81D4FA", "#B39DDB", "#66BB6A")
        confetti.clear()
        repeat(28) {
            confetti.add(
                Confetti(
                    x = width / 2f + Random.nextFloat() * box * 0.4f - box * 0.2f,
                    y = height / 2f,
                    vx = (Random.nextFloat() - 0.5f) * box * 0.06f,
                    vy = -Random.nextFloat() * box * 0.05f - box * 0.01f,
                    color = Color.parseColor(colors[Random.nextInt(colors.size)]),
                    size = box * (0.018f + Random.nextFloat() * 0.022f),
                    rot = Random.nextFloat() * 360f,
                    spin = (Random.nextFloat() - 0.5f) * 24f,
                )
            )
        }
        confettiAnim?.cancel()
        confettiAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1400L
            addUpdateListener {
                for (c in confetti) {
                    c.x += c.vx
                    c.y += c.vy
                    c.vy += box * 0.0022f
                    c.rot += c.spin
                }
                invalidate()
            }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    confetti.clear(); invalidate()
                }
            })
            start()
        }
    }

    // ---- 터치 ----
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (isFinished || checkpoints.isEmpty()) return false
        // 시범 중에 손을 대면 시범을 멈추고 바로 쓰기 시작
        if (demoAnim?.isRunning == true) cancelDemo()

        val pts = checkpoints.getOrNull(strokeIdx) ?: return false
        val tol = box * 0.13f

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                drawing = true
                currentPath = Path().apply { moveTo(event.x, event.y) }
                advance(pts, event.x, event.y, tol)
                parent?.requestDisallowInterceptTouchEvent(true)
                invalidate()
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                if (!drawing) return false
                // 손가락이 빠르게 움직여도 놓치지 않도록 중간 지점(history)까지 확인
                for (h in 0 until event.historySize) {
                    val hx = event.getHistoricalX(h)
                    val hy = event.getHistoricalY(h)
                    currentPath?.lineTo(hx, hy)
                    advance(pts, hx, hy, tol)
                }
                currentPath?.lineTo(event.x, event.y)
                advance(pts, event.x, event.y, tol)
                if (checkIdx >= pts.size) finishStroke()
                invalidate()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                drawing = false
                if (checkIdx >= pts.size * 0.92f) finishStroke()
                else {
                    // 길을 다 못 지났으면 이 획만 다시
                    if (checkIdx > 0) onStrokeFail?.invoke()
                    resetCurrentStroke()
                }
                invalidate()
                return true
            }
        }
        return false
    }

    private fun advance(pts: List<PointF>, x: Float, y: Float, tol: Float) {
        if (checkIdx >= pts.size) return
        // 앞쪽 몇 개까지 훑어보며 가장 멀리 닿은 지점으로 전진 (되돌아가진 않음)
        var best = -1
        val look = minOf(pts.size - 1, checkIdx + 6)
        for (i in checkIdx..look) {
            if (hypot(pts[i].x - x, pts[i].y - y) < tol) best = i
        }
        if (best >= 0) checkIdx = best + 1
    }

    private fun finishStroke() {
        val pts = checkpoints.getOrNull(strokeIdx) ?: return
        userPaths.add(pathOf(pts))
        currentPath = null
        val done = strokeIdx
        strokeIdx++
        checkIdx = 0
        drawing = false
        onStrokeDone?.invoke(done)
        if (strokeIdx >= strokes.size) {
            celebrate()
            onAllDone?.invoke()
        }
    }

    // ---- 그리기 ----
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (checkpoints.isEmpty()) return

        // 배경에 흐린 글자
        if (glyph.isNotEmpty()) {
            val fm = bgGlyphPaint.fontMetrics
            canvas.drawText(
                glyph, offX + box / 2f,
                offY + box / 2f - (fm.ascent + fm.descent) / 2f, bgGlyphPaint
            )
        }

        // 아직 안 쓴 획들 = 길
        for (i in checkpoints.indices) {
            if (i < strokeIdx) continue
            val paint = if (i == strokeIdx) roadActivePaint else roadPaint
            val path = pathOf(checkpoints[i])
            canvas.drawPath(path, paint)
            canvas.drawPath(path, dashPaint)
        }

        // 완성한 획
        for (path in userPaths) canvas.drawPath(path, donePaint)

        // 시범 궤적 + 병아리
        if (demoTrail.size > 1) {
            canvas.drawPath(pathOf(demoTrail), inkPaint)
        }
        demoPos?.let {
            canvas.drawText("🐥", it.x, it.y + emojiPaint.textSize * 0.35f, emojiPaint)
        }

        // 지금 쓰고 있는 선
        currentPath?.let { canvas.drawPath(it, inkPaint) }

        // 시작점 표시 (번호)
        if (!isFinished) {
            val pts = checkpoints[strokeIdx]
            val s = pts.first()
            canvas.drawCircle(s.x, s.y, box * 0.055f, startPaint)
            canvas.drawText(
                "${strokeIdx + 1}", s.x,
                s.y + startTextPaint.textSize * 0.36f, startTextPaint
            )
        }

        // 축하 조각
        for (c in confetti) {
            confettiPaint.color = c.color
            canvas.save()
            canvas.rotate(c.rot, c.x, c.y)
            canvas.drawRoundRect(
                c.x - c.size, c.y - c.size * 0.6f, c.x + c.size, c.y + c.size * 0.6f,
                c.size * 0.3f, c.size * 0.3f, confettiPaint
            )
            canvas.restore()
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        cancelDemo()
        confettiAnim?.cancel()
    }
}
