package com.piyak.english.ui

import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.databinding.ActivitySubjectBinding
import com.piyak.english.db.Db
import com.piyak.english.engine.Economy
import com.piyak.english.engine.Wallet
import com.piyak.english.model.ContentRepo
import com.piyak.english.model.Subject

/** 대문 — 영어 / 수학 고르기 */
class SubjectActivity : AppCompatActivity() {

    private lateinit var b: ActivitySubjectBinding

    private val hellos = listOf(
        "오늘은 뭘 공부할까요?", "삐약! 준비됐나요?", "한 문제라도 풀면 성공이에요",
        "오늘도 조금씩 자라요 🌱", "어제의 나보다 한 걸음 더!",
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivitySubjectBinding.inflate(layoutInflater)
        setContentView(b.root)
        b.txtHello.text = hellos.random()
    }

    override fun onResume() {
        super.onResume()
        val db = Db.get(this)
        val theme = Color.parseColor(db.themeColor())
        b.root.setBackgroundColor(theme)
        window.statusBarColor = theme

        b.txtCoins.text = "💰 ${Wallet.format(db.coins())}"
        b.txtHearts.text = "❤️ ${db.hearts()}"
        val (streak, _) = Economy.streak(db.studyDays(), Db.today())
        b.txtStreak.text = "🔥 $streak"

        build(db)
    }

    private fun build(db: Db) {
        b.subjectsBox.removeAllViews()
        // 완료한 레슨 id 는 접두사로 과목을 구분한다 (팩을 열지 않아도 세어진다)
        val done = db.completedLessonIds()
        for (s in Subject.entries) {
            val total = ContentRepo.lessonCountOf(this, s)
            val cleared = done.count { id ->
                if (s == Subject.MATH) id.startsWith("ml") else !id.startsWith("ml")
            }

            val card = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(20), dp(24), dp(20), dp(24))
                background = GradientDrawable().apply {
                    cornerRadius = dp(26).toFloat()
                    setColor(Color.parseColor(s.color))
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = dp(12) }
                setOnClickListener { open(s) }
            }
            card.addView(TextView(this).apply { text = s.emoji; textSize = 44f })
            val col = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                setPadding(dp(16), 0, 0, 0)
            }
            col.addView(TextView(this).apply {
                text = s.title
                textSize = 26f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(Color.parseColor("#3E2723"))
            })
            col.addView(TextView(this).apply {
                text = s.subtitle
                textSize = 13f
                setTextColor(Color.parseColor("#5D4037"))
            })
            col.addView(TextView(this).apply {
                text = if (total == 0) "준비 중이에요" else "$cleared / $total 레슨"
                textSize = 12f
                setTextColor(Color.parseColor("#6D4C41"))
                setPadding(0, dp(4), 0, 0)
            })
            card.addView(col)
            card.addView(TextView(this).apply {
                text = "▶"
                textSize = 22f
                setTextColor(Color.parseColor("#3E2723"))
            })
            b.subjectsBox.addView(card)
        }
    }

    private fun open(s: Subject) {
        Db.get(this).setMeta("subject_last", s.id)
        startActivity(Intent(this, MainActivity::class.java).putExtra("subject", s.id))
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
