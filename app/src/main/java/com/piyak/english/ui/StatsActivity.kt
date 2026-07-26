package com.piyak.english.ui

import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
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
        b.txtLevelBig.text = "⭐ Lv.$lv"
        b.xpBar.progress = (Economy.levelProgress(xp) * 100).toInt()
        b.txtXpDetail.text = "누적 ${xp} XP · 다음 레벨까지 ${Economy.xpForLevel(lv + 1) - xp} XP"

        val days = db.studyDays()
        val (cur, best) = Economy.streak(days, Db.today())
        b.txtStreakInfo.text = "현재 ${cur}일 연속 · 최고 ${best}일"

        b.txtCounters.text =
            "📚 완료한 레슨  ${db.lessonsDoneCount()}개\n" +
            "💯 퍼펙트 레슨  ${db.metaInt("perfect_count")}개\n" +
            "💊 클리어한 오답  ${db.metaInt("review_cleared")}개\n" +
            "🗓 공부한 날  ${days.size}일"

        buildCalendar(days)
        buildBadges(db.earnedBadges())
    }

    private fun buildCalendar(days: Set<Long>) {
        b.calGrid.removeAllViews()
        val today = LocalDate.now()
        val first = today.withDayOfMonth(1)
        val startCol = first.dayOfWeek.value % 7 // 일요일 시작

        for (h in listOf("일", "월", "화", "수", "목", "금", "토")) {
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
                text = bd.title; textSize = 13f; gravity = Gravity.CENTER
                setTypeface(typeface, android.graphics.Typeface.BOLD)
            })
            box.addView(TextView(this).apply {
                text = bd.desc; textSize = 11f; gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#8D6E63"))
            })
            b.badgesGrid.addView(box)
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
