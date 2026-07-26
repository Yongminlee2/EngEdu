package com.piyak.english.ui

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup

/** 단어 타일용 간단한 플로우 레이아웃 (왼→오, 넘치면 다음 줄) */
class FlowLayout @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : ViewGroup(ctx, attrs) {

    var hGap = dp(8)
    var vGap = dp(8)

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val maxW = MeasureSpec.getSize(widthMeasureSpec) - paddingLeft - paddingRight
        var x = 0
        var y = 0
        var rowH = 0
        for (i in 0 until childCount) {
            val c = getChildAt(i)
            if (c.visibility == View.GONE) continue
            c.measure(
                MeasureSpec.makeMeasureSpec(maxW, MeasureSpec.AT_MOST),
                MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
            )
            if (x + c.measuredWidth > maxW && x > 0) {
                x = 0; y += rowH + vGap; rowH = 0
            }
            x += c.measuredWidth + hGap
            rowH = maxOf(rowH, c.measuredHeight)
        }
        val h = y + rowH + paddingTop + paddingBottom
        setMeasuredDimension(
            MeasureSpec.getSize(widthMeasureSpec),
            resolveSize(h, heightMeasureSpec)
        )
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        val maxW = r - l - paddingLeft - paddingRight
        var x = 0
        var y = paddingTop
        var rowH = 0
        for (i in 0 until childCount) {
            val c = getChildAt(i)
            if (c.visibility == View.GONE) continue
            if (x + c.measuredWidth > maxW && x > 0) {
                x = 0; y += rowH + vGap; rowH = 0
            }
            c.layout(paddingLeft + x, y, paddingLeft + x + c.measuredWidth, y + c.measuredHeight)
            x += c.measuredWidth + hGap
            rowH = maxOf(rowH, c.measuredHeight)
        }
    }
}
