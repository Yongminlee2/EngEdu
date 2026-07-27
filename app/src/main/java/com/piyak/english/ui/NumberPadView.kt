package com.piyak.english.ui

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Color
import android.util.AttributeSet
import android.widget.Button
import android.widget.LinearLayout

/** 아이도 누르기 쉬운 큰 숫자 키패드 */
class NumberPadView @JvmOverloads constructor(
    ctx: Context, attrs: AttributeSet? = null,
) : LinearLayout(ctx, attrs) {

    var onChange: ((String) -> Unit)? = null

    private val sb = StringBuilder()

    /** 분수·음수를 쓰는 학년에서만 켠다 */
    var allowFraction = false
        set(v) { field = v; rebuild() }
    var allowMinus = false
        set(v) { field = v; rebuild() }
    var allowDecimal = true
        set(v) { field = v; rebuild() }

    val value: String get() = sb.toString()

    init {
        orientation = VERTICAL
        rebuild()
    }

    fun clear() {
        sb.clear()
        onChange?.invoke("")
    }

    private fun rebuild() {
        removeAllViews()
        val rows = listOf(
            listOf("1", "2", "3"),
            listOf("4", "5", "6"),
            listOf("7", "8", "9"),
            buildList {
                add(if (allowMinus) "-" else if (allowDecimal) "." else " ")
                add("0")
                add("⌫")
            },
        )
        for (r in rows) addView(row(r))
        if (allowFraction || (allowMinus && allowDecimal)) {
            val extra = buildList {
                if (allowDecimal && allowMinus) add(".")
                if (allowFraction) add("/")
                add("지우기")
            }
            addView(row(extra))
        }
    }

    private fun row(keys: List<String>): LinearLayout {
        val row = LinearLayout(context).apply {
            orientation = HORIZONTAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT)
                .apply { topMargin = dp(6) }
        }
        for (k in keys) {
            val btn = Button(context).apply {
                text = k
                textSize = if (k.length > 1) 15f else 22f
                isAllCaps = false
                setTextColor(Color.parseColor("#4E342E"))
                backgroundTintList = ColorStateList.valueOf(
                    Color.parseColor(
                        when (k) {
                            "⌫", "지우기" -> "#FFCCBC"
                            " " -> "#00000000"
                            else -> "#FFFFFF"
                        }
                    )
                )
                isEnabled = k != " "
                layoutParams = LayoutParams(0, dp(52), 1f).apply {
                    marginStart = dp(4); marginEnd = dp(4)
                }
                setOnClickListener { press(k) }
            }
            row.addView(btn)
        }
        return row
    }

    private fun press(k: String) {
        when (k) {
            " " -> return
            "지우기" -> sb.clear()
            "⌫" -> if (sb.isNotEmpty()) sb.deleteCharAt(sb.length - 1)
            "-" -> if (sb.isEmpty()) sb.append("-")
            "." -> if (sb.isNotEmpty() && !currentPartHas('.')) sb.append(".")
            "/" -> if (sb.isNotEmpty() && !sb.contains("/")) sb.append("/")
            else -> if (sb.length < 12) sb.append(k)
        }
        onChange?.invoke(sb.toString())
    }

    /** 분수의 각 항마다 소수점은 하나까지 */
    private fun currentPartHas(c: Char): Boolean =
        sb.toString().substringAfterLast('/').contains(c)

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
