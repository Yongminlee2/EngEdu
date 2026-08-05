package com.piyak.english.ui

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.view.ViewGroup

/** 단어 타일용 간단한 플로우 레이아웃 (왼→오, 넘치면 다음 줄) */
class FlowLayout @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : ViewGroup(ctx, attrs) {

    init {
        // 자식(레슨 원·낱말 타일)의 **그림자는 뷰 바깥에 그려진다.**
        // 기본값이면 부모 경계에서 잘려 아랫줄만 "살짝 가려진" 것처럼 보인다.
        // 여백을 줘도 소용없다 — clipToPadding 이 기본 true 라 여백 안쪽에서 자르기 때문.
        clipChildren = false
        clipToPadding = false
    }

    var hGap = dp(8)
    var vGap = dp(8)

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    /**
     * 자식이 크기를 지정했으면(예: 레슨 노드 72×72) 그 값을 그대로 쓰고,
     * wrap_content 인 것(단어 타일)만 내용에 맞춰 잰다.
     * 이걸 빼먹으면 정사각형이어야 할 노드가 가로로 늘어나 타원이 된다.
     */
    private fun measureChildForFlow(c: View, maxW: Int) {
        val lp = c.layoutParams
        val wSpec = if (lp != null && lp.width > 0)
            MeasureSpec.makeMeasureSpec(lp.width, MeasureSpec.EXACTLY)
        else MeasureSpec.makeMeasureSpec(maxW, MeasureSpec.AT_MOST)
        val hSpec = if (lp != null && lp.height > 0)
            MeasureSpec.makeMeasureSpec(lp.height, MeasureSpec.EXACTLY)
        else MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        c.measure(wSpec, hSpec)
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val maxW = MeasureSpec.getSize(widthMeasureSpec) - paddingLeft - paddingRight
        var x = 0
        var y = 0
        var rowH = 0
        for (i in 0 until childCount) {
            val c = getChildAt(i)
            if (c.visibility == View.GONE) continue
            measureChildForFlow(c, maxW)
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
