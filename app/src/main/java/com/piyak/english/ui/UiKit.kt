package com.piyak.english.ui

import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.animation.StateListAnimator
import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.view.View
import androidx.annotation.ColorRes
import androidx.core.content.ContextCompat
import com.piyak.english.R

/**
 * Code-side companions for dynamic parts of the sticker-book UI.
 */
object UiKit {
    fun dp(context: Context, value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()

    fun choice(
        context: Context,
        selected: Boolean = false,
        correct: Boolean? = null
    ): GradientDrawable {
        @ColorRes val fill = when (correct) {
            true -> R.color.green_bg
            false -> R.color.red_bg
            null -> if (selected) R.color.primary_soft else R.color.surface
        }
        @ColorRes val stroke = when (correct) {
            true -> R.color.green_ok
            false -> R.color.coral_deep
            null -> if (selected) R.color.primary_deep else R.color.outline
        }
        return rounded(context, fill, stroke, 18, if (selected || correct != null) 3 else 2)
    }

    fun rounded(
        context: Context,
        @ColorRes fill: Int,
        @ColorRes stroke: Int = R.color.outline,
        radiusDp: Int = 18,
        strokeDp: Int = 1
    ) = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(ContextCompat.getColor(context, fill))
        setStroke(dp(context, strokeDp), ContextCompat.getColor(context, stroke))
        cornerRadius = dp(context, radiusDp).toFloat()
    }

    fun addPressMotion(view: View) {
        val down = ObjectAnimator.ofPropertyValuesHolder(
            view,
            PropertyValuesHolder.ofFloat(View.SCALE_X, 0.97f),
            PropertyValuesHolder.ofFloat(View.SCALE_Y, 0.97f)
        ).setDuration(90)
        val up = ObjectAnimator.ofPropertyValuesHolder(
            view,
            PropertyValuesHolder.ofFloat(View.SCALE_X, 1f),
            PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f)
        ).setDuration(120)
        view.stateListAnimator = StateListAnimator().apply {
            addState(intArrayOf(android.R.attr.state_pressed), down)
            addState(intArrayOf(), up)
        }
    }
}
