package com.piyak.english.ui

import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.databinding.ActivityMainBinding
import com.piyak.english.db.Db
import com.piyak.english.engine.Economy
import com.piyak.english.model.ContentRepo

class MainActivity : AppCompatActivity() {

    private lateinit var b: ActivityMainBinding
    private val greetings = listOf(
        "오늘도 삐약삐약 공부해요!", "꾸준함이 최고의 재능이에요 🐥",
        "한 문제라도 풀면 오늘은 성공!", "삐약! 영어가 무서우면 저를 봐요!",
        "어제의 나보다 한 단어 더!", "여행 가서 써먹을 그날까지 ✈️",
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityMainBinding.inflate(layoutInflater)
        setContentView(b.root)

        b.txtGreeting.text = greetings.random()
        b.bannerPlacement.setOnClickListener {
            startActivity(Intent(this, PlacementActivity::class.java))
        }
        b.btnReview.setOnClickListener {
            val db = Db.get(this)
            if (db.wrongCount() == 0) {
                android.widget.Toast.makeText(this, "복습할 오답이 없어요! 삐약 🐥", android.widget.Toast.LENGTH_SHORT).show()
            } else {
                startActivity(Intent(this, LessonActivity::class.java).putExtra("mode", "review"))
            }
        }
        b.btnStats.setOnClickListener { startActivity(Intent(this, StatsActivity::class.java)) }
        b.btnSettings.setOnClickListener { startActivity(Intent(this, SettingsActivity::class.java)) }
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    private fun refresh() {
        val db = Db.get(this)
        val xp = db.xp()
        val lv = Economy.levelFor(xp)
        b.txtHearts.text = "❤️ ${db.hearts()}"
        val (streak, _) = Economy.streak(db.studyDays(), Db.today())
        b.txtStreak.text = "🔥 $streak"
        b.txtLevel.text = "⭐ Lv.$lv"
        b.xpBar.progress = (Economy.levelProgress(xp) * 100).toInt()
        b.btnReview.text = "💊 오답 ${db.wrongCount()}"
        b.bannerPlacement.visibility =
            if (db.meta("placement_done") == "1") android.view.View.GONE else android.view.View.VISIBLE

        buildTrackCards(db)
    }

    private fun buildTrackCards(db: Db) {
        b.tracksBox.removeAllViews()
        val done = db.completedLessonIds()
        for (tid in ContentRepo.TRACK_IDS) {
            val t = ContentRepo.track(this, tid) ?: continue
            val doneCount = t.units.sumOf { u -> u.lessons.count { it.id in done } }

            val card = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(18f).toInt(), dp(16f).toInt(), dp(18f).toInt(), dp(16f).toInt())
                background = GradientDrawable().apply {
                    cornerRadius = dp(20f)
                    setColor(Color.parseColor(t.color))
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = dp(10f).toInt() }
                setOnClickListener {
                    startActivity(
                        Intent(this@MainActivity, TrackActivity::class.java).putExtra("track", tid)
                    )
                }
            }
            val row = card
            row.addView(TextView(this).apply { text = t.emoji; textSize = 34f })
            val col = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                setPadding(dp(12f).toInt(), 0, 0, 0)
            }
            col.addView(TextView(this).apply {
                text = t.title; textSize = 18f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(Color.parseColor("#4E342E"))
            })
            col.addView(TextView(this).apply {
                text = t.subtitle; textSize = 13f
                setTextColor(Color.parseColor("#6D4C41"))
            })
            row.addView(col)
            row.addView(TextView(this).apply {
                text = "$doneCount/${t.lessonCount}"
                textSize = 15f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(Color.parseColor("#4E342E"))
            })
            b.tracksBox.addView(card)
        }
    }

    private fun dp(v: Float): Float = v * resources.displayMetrics.density
}
