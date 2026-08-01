package com.piyak.english.ui

import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.widget.GridLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.DrawableCompat
import com.piyak.english.R
import com.piyak.english.databinding.ActivityStatsBinding
import com.piyak.english.db.Db
import com.piyak.english.engine.Badges
import com.piyak.english.engine.Economy
import java.time.LocalDate

class StatsActivity : AppCompatActivity() {

    private lateinit var b: ActivityStatsBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityStatsBinding.inflate(layoutInflater)
        setContentView(b.root)
        b.btnBack.setOnClickListener { finish() }
    }

    override fun onResume() {
        super.onResume()
        val db = Db.get(this)
        val xp = db.xp()
        val level = Economy.levelFor(xp)
        b.txtLevelBig.text = "레벨 $level"
        b.xpBar.progress = (Economy.levelProgress(xp) * 100).toInt()
        b.txtXpDetail.text = "누적 ${xp} XP · 다음 레벨까지 ${Economy.xpForLevel(level + 1) - xp} XP"

        val days = db.studyDays()
        val (current, best) = Economy.streak(days, Db.today())
        b.txtStreakInfo.text = "현재 ${current}일 연속 · 최고 ${best}일"
        b.txtCounters.text =
            "완료한 레슨  ${db.lessonsDoneCount()}개\n" +
                "퍼펙트 레슨  ${db.metaInt("perfect_count")}개\n" +
                "복습 완료  ${db.metaInt("review_cleared")}개\n" +
                "공부한 날  ${days.size}일"

        buildSkills(db)
        buildCalendar(days)
        buildBadges(db.earnedBadges())
    }

    private fun buildSkills(db: Db) {
        val states = db.skillStates(
            com.piyak.english.engine.Skills.ALL + com.piyak.english.engine.Skills.MATH,
        )
        val overall = com.piyak.english.engine.Skills.overallLevel(db.skillStates())
        val rank = com.piyak.english.engine.Ranks.of(overall)
        val next = com.piyak.english.engine.Ranks.next(overall)
        b.txtRankLine.text = String.format("%s · 종합 Lv.%.1f", rank.title, overall) +
            if (next != null) "  ·  다음 ${next.title} Lv.${next.minOverall}" else "  ·  최고 칭호"

        b.skillDetailBox.removeAllViews()
        val mathIds = com.piyak.english.engine.Skills.MATH.map { it.id }.toSet()
        var mathHeaderShown = false
        states.forEachIndexed { index, state ->
            if (index == 0 || (!mathHeaderShown && state.def.id in mathIds)) {
                val isMath = state.def.id in mathIds
                if (isMath) mathHeaderShown = true
                b.skillDetailBox.addView(TextView(this).apply {
                    text = if (isMath) "수학 영역" else "영어 영역"
                    textSize = 14f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(ContextCompat.getColor(this@StatsActivity, R.color.ink_muted))
                    setPadding(dp(4), dp(14), 0, dp(3))
                })
            }

            val box = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(14), dp(12), dp(14), dp(12))
                background = ContextCompat.getDrawable(this@StatsActivity, R.drawable.bg_question_surface)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { topMargin = dp(7) }
            }
            box.addView(TextView(this).apply {
                text = "${state.def.title}  ·  Lv.${state.level}"
                textSize = 16f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(ContextCompat.getColor(this@StatsActivity, R.color.ink))
            })
            box.addView(android.widget.ProgressBar(
                this,
                null,
                android.R.attr.progressBarStyleHorizontal,
            ).apply {
                max = 100
                progress = (state.progress * 100).toInt()
                progressTintList = ColorStateList.valueOf(Color.parseColor(state.def.color))
                progressBackgroundTintList = ColorStateList.valueOf(
                    ContextCompat.getColor(this@StatsActivity, R.color.paper_alt),
                )
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dp(10),
                ).apply { topMargin = dp(7) }
            })
            box.addView(TextView(this).apply {
                text = if (state.attempts == 0) {
                    "아직 풀어본 문제가 없어요"
                } else {
                    "정답 ${state.correct} / 시도 ${state.attempts}  ·  정답률 ${state.accuracy}%" +
                        if (state.level < com.piyak.english.engine.Skills.MAX_LEVEL) {
                            "  ·  다음 레벨까지 ${state.nextLevelNeed}문제"
                        } else {
                            "  ·  최고 레벨"
                        }
                }
                textSize = 12f
                setTextColor(ContextCompat.getColor(this@StatsActivity, R.color.ink_muted))
                setPadding(0, dp(6), 0, 0)
            })
            b.skillDetailBox.addView(box)
        }
    }

    private fun buildCalendar(days: Set<Long>) {
        b.calGrid.removeAllViews()
        val today = LocalDate.now()
        val first = today.withDayOfMonth(1)
        val startColumn = first.dayOfWeek.value % 7

        for (header in listOf("일", "월", "화", "수", "목", "금", "토")) {
            b.calGrid.addView(calendarCell(header, header = true))
        }
        repeat(startColumn) { b.calGrid.addView(calendarCell("")) }
        for (day in 1..today.lengthOfMonth()) {
            val date = first.withDayOfMonth(day)
            b.calGrid.addView(
                calendarCell(
                    day.toString(),
                    studied = date.toEpochDay() in days,
                    today = date == today,
                    future = date.isAfter(today),
                ),
            )
        }
    }

    private fun calendarCell(
        value: String,
        header: Boolean = false,
        studied: Boolean = false,
        today: Boolean = false,
        future: Boolean = false,
    ): TextView = TextView(this).apply {
        text = value
        textSize = if (header) 12f else 14f
        gravity = Gravity.CENTER
        minHeight = dp(40)
        if (header || studied || today) setTypeface(typeface, Typeface.BOLD)
        setTextColor(
            ContextCompat.getColor(
                this@StatsActivity,
                if (future) R.color.outline_strong else R.color.ink,
            ),
        )
        if (!header && value.isNotEmpty()) {
            background = GradientDrawable().apply {
                cornerRadius = dp(12).toFloat()
                setColor(
                    ContextCompat.getColor(
                        this@StatsActivity,
                        when {
                            today -> R.color.primary_soft
                            studied -> R.color.mint_soft
                            else -> android.R.color.transparent
                        },
                    ),
                )
            }
            contentDescription = "$value 일" + if (studied) ", 공부함" else ", 공부 기록 없음"
        }
        layoutParams = GridLayout.LayoutParams().apply {
            width = 0
            height = dp(42)
            columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
            setMargins(dp(1), dp(2), dp(1), dp(2))
        }
    }

    private fun buildBadges(earned: Set<String>) {
        b.badgesGrid.removeAllViews()
        for (badge in Badges.ALL) {
            val hasBadge = badge.id in earned
            val box = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(dp(5), dp(12), dp(5), dp(12))
                alpha = if (hasBadge) 1f else 0.38f
                background = ContextCompat.getDrawable(this@StatsActivity, R.drawable.bg_question_surface)
                contentDescription = "${badge.title}. ${badge.desc}. " +
                    if (hasBadge) "획득함" else "아직 획득하지 못함"
                layoutParams = GridLayout.LayoutParams().apply {
                    width = 0
                    columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                    setMargins(dp(3), dp(3), dp(3), dp(3))
                }
            }
            box.addView(ImageView(this).apply {
                val icon = ContextCompat.getDrawable(this@StatsActivity, R.drawable.ic_star_rounded)?.mutate()
                if (icon != null) {
                    DrawableCompat.setTint(
                        icon,
                        ContextCompat.getColor(
                            this@StatsActivity,
                            if (hasBadge) R.color.primary_deep else R.color.outline_strong,
                        ),
                    )
                    setImageDrawable(icon)
                }
                layoutParams = LinearLayout.LayoutParams(dp(36), dp(36))
                importantForAccessibility = android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO
            })
            box.addView(TextView(this).apply {
                text = badge.title
                textSize = 13f
                gravity = Gravity.CENTER
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(ContextCompat.getColor(this@StatsActivity, R.color.ink))
                setPadding(0, dp(4), 0, 0)
            })
            box.addView(TextView(this).apply {
                text = badge.desc
                textSize = 11f
                gravity = Gravity.CENTER
                maxLines = 2
                setTextColor(ContextCompat.getColor(this@StatsActivity, R.color.ink_muted))
            })
            b.badgesGrid.addView(box)
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
