package com.piyak.english.ui

import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
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
        val lv = Economy.levelFor(xp)
        b.txtLevelBig.text = getString(R.string.stats_level_big, lv)
        b.xpBar.progress = (Economy.levelProgress(xp) * 100).toInt()
        b.txtXpDetail.text = getString(R.string.stats_xp_detail, xp, Economy.xpForLevel(lv + 1) - xp)

        val days = db.studyDays()
        val (cur, best) = Economy.streak(days, Db.today())
        b.txtStreakInfo.text = getString(R.string.stats_streak_info, cur, best)

        b.txtCounters.text = getString(R.string.stats_counters,
            db.lessonsDoneCount(), db.metaInt("perfect_count"), db.metaInt("review_cleared"), days.size)

        buildSkills(db)
        buildCalendar(days)
        buildBadges(db.earnedBadges())
    }

    /**
     * 영역별 실력 상세: 레벨 · 진행바 · 정답수/시도수 · 다음 레벨까지.
     *
     * **영어 앱은 영어 영역만 보여 준다.** 앱을 둘로 나눌 때 여기만 `ALL + MATH` 로
     * 남아 있어서, 삐약영어 통계에 수학 영역(계산·도형·측정…)이 계속 따라 나왔다.
     * 과목 구분 제목도 이제 필요 없다 — 한 과목만 나오니까.
     */
    private fun buildSkills(db: Db) {
        val states = db.skillStates(com.piyak.english.engine.Skills.ALL)
        val overall = com.piyak.english.engine.Skills.overallLevel(states)
        val rank = com.piyak.english.engine.Ranks.of(overall)
        val next = com.piyak.english.engine.Ranks.next(overall)
        b.txtRankLine.text = String.format("%s %s · Lv.%.1f", rank.emoji, getString(rank.titleRes), overall) +
            if (next != null) getString(R.string.rank_next_short, getString(next.titleRes), next.minOverall) else getString(R.string.rank_top)

        b.skillDetailBox.removeAllViews()
        for (st in states) {
            val box = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(12), dp(10), dp(12), dp(10))
                background = getDrawable(com.piyak.english.R.drawable.bg_tile_ghost)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = dp(6) }
            }
            box.addView(TextView(this).apply {
                text = "${st.def.emoji} ${getString(st.def.titleRes)}   Lv.${st.level}"
                textSize = 16f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
            })
            box.addView(android.widget.ProgressBar(
                this, null, android.R.attr.progressBarStyleHorizontal
            ).apply {
                max = 100
                progress = (st.progress * 100).toInt()
                progressTintList = android.content.res.ColorStateList.valueOf(Color.parseColor(st.def.color))
                progressBackgroundTintList = android.content.res.ColorStateList.valueOf(Color.parseColor("#FFF0CC"))
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, dp(10)
                ).apply { topMargin = dp(6) }
            })
            box.addView(TextView(this).apply {
                text = if (st.attempts == 0) getString(R.string.stats_none_yet)
                else getString(R.string.stats_skill_line, st.correct, st.attempts, st.accuracy) +
                    if (st.level < com.piyak.english.engine.Skills.MAX_LEVEL)
                        getString(R.string.stats_next_level, st.nextLevelNeed) else getString(R.string.stats_max_level)
                textSize = 12f
                setTextColor(Color.parseColor("#8D6E63"))
                setPadding(0, dp(5), 0, 0)
            })
            b.skillDetailBox.addView(box)
        }
    }

    private fun buildCalendar(days: Set<Long>) {
        b.calGrid.removeAllViews()
        val today = LocalDate.now()
        val first = today.withDayOfMonth(1)
        val startCol = first.dayOfWeek.value % 7 // 일요일 시작

        for (h in resources.getStringArray(R.array.weekday_short)) {
            b.calGrid.addView(cell(h, bold = true))
        }
        repeat(startCol) { b.calGrid.addView(cell("")) }
        for (d in 1..today.lengthOfMonth()) {
            val date = first.withDayOfMonth(d)
            val studied = date.toEpochDay() in days
            val isToday = date == today
            val t = cell(if (studied) "🐥" else d.toString())
            if (isToday) t.setBackgroundColor(Color.parseColor("#FFE082"))
            if (!studied && date.isAfter(today)) t.setTextColor(Color.parseColor("#BDBDBD"))
            b.calGrid.addView(t)
        }
    }

    private fun cell(text: String, bold: Boolean = false): TextView = TextView(this).apply {
        this.text = text
        textSize = 15f
        gravity = Gravity.CENTER
        if (bold) setTypeface(typeface, android.graphics.Typeface.BOLD)
        layoutParams = GridLayout.LayoutParams().apply {
            width = 0
            columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
            setMargins(0, dp(4), 0, dp(4))
        }
    }

    private fun buildBadges(earned: Set<String>) {
        b.badgesGrid.removeAllViews()
        for (bd in Badges.ALL) {
            val has = bd.id in earned
            val box = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(dp(6), dp(10), dp(6), dp(10))
                alpha = if (has) 1f else 0.35f
                layoutParams = GridLayout.LayoutParams().apply {
                    width = 0
                    columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                }
            }
            box.addView(TextView(this).apply { text = bd.emoji; textSize = 30f; gravity = Gravity.CENTER })
            box.addView(TextView(this).apply {
                text = getString(bd.titleRes); textSize = 12f; gravity = Gravity.CENTER
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                // 칸이 화면 1/3 이라 한 줄로는 "Estudiante ejemplar" 같은 이름이 잘린다
                maxLines = 2
                ellipsize = android.text.TextUtils.TruncateAt.END
            })
            box.addView(TextView(this).apply {
                text = getString(bd.descRes); textSize = 10.5f; gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#8D6E63"))
                // 러시아어·인니어 설명은 두 줄로는 안 들어간다
                maxLines = 3
                ellipsize = android.text.TextUtils.TruncateAt.END
                setLineSpacing(0f, 1.05f)
            })
            b.badgesGrid.addView(box)
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
