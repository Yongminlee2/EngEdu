package com.piyak.english.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PointF
import android.util.AttributeSet
import android.view.ViewGroup
import androidx.core.content.ContextCompat
import com.piyak.english.R
import kotlin.math.min

/**
 * 스티커북의 점선을 따라 레슨 노드를 배치하는 지그재그 경로.
 * 자식 뷰가 실제 터치와 접근성을 담당하고, 이 뷰는 경로만 장식으로 그린다.
 */
class JourneyLayout @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : ViewGroup(context, attrs, defStyleAttr) {

    private val points = ArrayList<PointF>()
    private val route = Path()
    private val routeBase = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(7).toFloat()
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = ContextCompat.getColor(context, R.color.paper_alt)
    }
    private val routeDash = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = dp(2).toFloat()
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        color = ContextCompat.getColor(context, R.color.primary_deep)
        pathEffect = DashPathEffect(floatArrayOf(dp(7).toFloat(), dp(8).toFloat()), 0f)
    }

    private val preferredNode = dp(72)
    private val rowGap = dp(36)

    init {
        setWillNotDraw(false)
        clipToPadding = false
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val contentWidth = (width - paddingLeft - paddingRight).coerceAtLeast(0)
        val node = min(preferredNode, ((contentWidth - dp(24)) / 3).coerceAtLeast(dp(56)))
        val childSpec = MeasureSpec.makeMeasureSpec(node, MeasureSpec.EXACTLY)
        for (i in 0 until childCount) getChildAt(i).measure(childSpec, childSpec)

        val rows = (childCount + 2) / 3
        val wantedHeight = paddingTop + paddingBottom +
            rows * node + (rows - 1).coerceAtLeast(0) * rowGap
        setMeasuredDimension(
            resolveSize(width, widthMeasureSpec),
            resolveSize(wantedHeight, heightMeasureSpec),
        )
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        points.clear()
        val available = width - paddingLeft - paddingRight
        for (i in 0 until childCount) {
            val child = getChildAt(i)
            val row = i / 3
            val place = i % 3
            val column = if (row % 2 == 0) place else 2 - place
            val centerX = paddingLeft + available * (column * 2 + 1) / 6f
            val childTop = paddingTop + row * (child.measuredHeight + rowGap)
            val childLeft = (centerX - child.measuredWidth / 2f).toInt()
            child.layout(
                childLeft,
                childTop,
                childLeft + child.measuredWidth,
                childTop + child.measuredHeight,
            )
            points += PointF(centerX, childTop + child.measuredHeight / 2f)
        }
        rebuildRoute()
    }

    private fun rebuildRoute() {
        route.reset()
        if (points.isEmpty()) return
        route.moveTo(points.first().x, points.first().y)
        for (i in 1 until points.size) {
            val from = points[i - 1]
            val to = points[i]
            val bend = (to.x - from.x) * 0.45f
            route.cubicTo(from.x + bend, from.y, to.x - bend, to.y, to.x, to.y)
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (points.size > 1) {
            canvas.drawPath(route, routeBase)
            canvas.drawPath(route, routeDash)
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
