package com.piyak.english.ui

import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.databinding.ActivityMainBinding
import com.piyak.english.db.Db
import com.piyak.english.engine.DailyGoal
import com.piyak.english.engine.Economy
import com.piyak.english.engine.Ranks
import com.piyak.english.engine.SkillState
import com.piyak.english.engine.Skills
import com.piyak.english.model.ContentRepo

class MainActivity : AppCompatActivity() {

    private lateinit var b: ActivityMainBinding
    private var subject: com.piyak.english.model.Subject = com.piyak.english.model.Subject.ENGLISH
    private val greetings = listOf(
        "오늘도 삐약삐약 공부해요!", "꾸준함이 최고의 재능이에요 🐥",
        "한 문제라도 풀면 오늘은 성공!", "삐약! 영어가 무서우면 저를 봐요!",
        "어제의 나보다 한 단어 더!", "여행 가서 써먹을 그날까지 ✈️",
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityMainBinding.inflate(layoutInflater)
        setContentView(b.root)
        // 삐약영어는 영어 전용 앱 — 과목 대문 없이 항상 영어
        subject = com.piyak.english.model.Subject.ENGLISH

        b.txtGreeting.text = greetings.random()
        b.btnSwitchSubject.visibility = View.GONE
        b.bannerPlacement.setOnClickListener {
            startActivity(
                Intent(this, PlacementActivity::class.java).putExtra("subject", subject.id)
            )
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
        b.txtGoalEdit.setOnClickListener { pickDailyGoal() }
        b.cardAlphabet.setOnClickListener {
            startActivity(Intent(this, AlphabetActivity::class.java))
        }
        b.cardWallet.setOnClickListener {
            startActivity(Intent(this, WalletActivity::class.java))
        }
        b.cardPlayground.setOnClickListener {
            startActivity(
                Intent(this, PlaygroundActivity::class.java).putExtra("subject", subject.id)
            )
        }
    }

    private fun pickDailyGoal() {
        val db = Db.get(this)
        val labels = DailyGoal.OPTIONS.map { xp ->
            val note = when (xp) {
                20 -> "가볍게 (레슨 1개쯤)"
                50 -> "보통 (레슨 2~3개)"
                100 -> "열심히 (레슨 5개쯤)"
                else -> "빡세게 (레슨 10개쯤)"
            }
            "$xp XP — $note"
        }.toTypedArray()
        androidx.appcompat.app.AlertDialog.Builder(this)
            .setTitle("🎯 오늘의 목표 정하기")
            .setItems(labels) { _, i ->
                db.setDailyGoal(DailyGoal.OPTIONS[i])
                refresh()
            }
            .setNegativeButton("취소", null)
            .show()
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
        // 배치고사 배너: 과목별로 아직 안 본 경우에만
        val placedKey = if (subject == com.piyak.english.model.Subject.MATH)
            "math_placement_done" else "placement_done"
        b.bannerPlacement.visibility = if (db.meta(placedKey) == "1") View.GONE else View.VISIBLE
        b.txtPlacement.text = if (subject == com.piyak.english.model.Subject.MATH)
            "🎯 수학 레벨테스트로 내 학년 찾기!\n25문제로 딱 맞는 단계를 정해줘요"
        else "🎯 레벨테스트로 내 위치 찾기!\n25문제로 딱 맞는 레벨을 정해줘요"

        // 상점에서 산 테마 배경 적용
        val theme = Color.parseColor(db.themeColor())
        b.root.setBackgroundColor(theme)
        window.statusBarColor = theme

        b.txtCoins.text = com.piyak.english.engine.Wallet.format(db.coins())
        b.txtAlphabetCount.text = "${db.lettersDoneCount()}/${com.piyak.english.engine.Letters.ALL.size * 2}"
        // 알파벳 쓰기는 영어 전용
        b.cardAlphabet.visibility =
            if (subject == com.piyak.english.model.Subject.ENGLISH) View.VISIBLE else View.GONE
        b.txtPlayground.text =
            com.piyak.english.engine.MiniGames.forSubject(subject).joinToString(" · ") {
                "${it.emoji} ${it.title}"
            }
        buildGrowth(db)
        buildTrackCards(db)
    }

    /** 칭호 · 오늘의 목표 · 영역별 실력 바 */
    private fun buildGrowth(db: Db) {
        val states = db.skillStates(Skills.forSubject(subject))
        val overall = Skills.overallLevel(states)
        val rank = Ranks.of(overall)
        val sticker = db.equippedSticker()
        b.txtRank.text = "${rank.emoji} ${rank.title}" + if (sticker.isNotEmpty()) " $sticker" else ""
        b.rankBar.progress = (Ranks.progress(overall) * 100).toInt()
        val next = Ranks.next(overall)
        b.txtOverall.text = String.format("종합 실력 Lv.%.1f", overall) +
            if (next != null) "  →  다음 칭호 ${next.emoji} ${next.title}" else "  (최고 칭호!)"

        val goal = db.dailyGoal()
        val todayXp = db.xpToday()
        val done = DailyGoal.isDone(todayXp, goal)
        b.txtGoal.text = "🎯 오늘의 목표  $todayXp / $goal XP" + if (done) "   ✅ 달성!" else ""
        b.goalBar.progress = (DailyGoal.progress(todayXp, goal) * 100).toInt()
        b.goalBar.progressTintList = ColorStateList.valueOf(
            Color.parseColor(if (done) "#66BB6A" else "#FF8A80")
        )

        val weak = Skills.weakest(states)
        b.txtWeakest.text = if (weak != null && weak.attempts >= 0)
            "약한 영역: ${weak.def.emoji} ${weak.def.title}" else ""

        b.skillsBox.removeAllViews()
        for (st in states) b.skillsBox.addView(skillRow(st))
    }

    /** 실력 한 줄: 🎧 듣기  Lv.3  [====----]  정답률 82% */
    private fun skillRow(st: SkillState): LinearLayout {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(5f).toInt(), 0, dp(5f).toInt())
        }
        row.addView(TextView(this).apply {
            text = "${st.def.emoji} ${st.def.title}"
            textSize = 14f
            width = dp(78f).toInt()
        })
        row.addView(TextView(this).apply {
            text = "Lv.${st.level}"
            textSize = 14f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            width = dp(46f).toInt()
        })
        row.addView(android.widget.ProgressBar(
            this, null, android.R.attr.progressBarStyleHorizontal
        ).apply {
            max = 100
            progress = (st.progress * 100).toInt()
            progressTintList = ColorStateList.valueOf(Color.parseColor(st.def.color))
            progressBackgroundTintList = ColorStateList.valueOf(Color.parseColor("#FFF0CC"))
            layoutParams = LinearLayout.LayoutParams(0, dp(10f).toInt(), 1f)
        })
        row.addView(TextView(this).apply {
            text = if (st.attempts == 0) "  시작 전" else "  ${st.accuracy}%"
            textSize = 12f
            setTextColor(Color.parseColor("#8D6E63"))
            width = dp(58f).toInt()
            gravity = Gravity.END
        })
        return row
    }

    private fun buildTrackCards(db: Db) {
        b.tracksBox.removeAllViews()
        val done = db.completedLessonIds()
        var lastStage: String? = null
        for (tid in subject.tracks) {
            val t = ContentRepo.track(this, tid) ?: continue
            val doneCount = t.units.sumOf { u -> u.lessons.count { it.id in done } }

            // 수학은 학년이 많아 유치원·초등 / 중학교 / 고등학교로 묶어 보여준다
            val stage = com.piyak.english.model.MathGrades.of(tid)?.stage
            if (stage != null && stage != lastStage) {
                lastStage = stage
                b.tracksBox.addView(TextView(this).apply {
                    text = stage
                    textSize = 14f
                    setTypeface(typeface, android.graphics.Typeface.BOLD)
                    setTextColor(Color.parseColor("#8D6E63"))
                    setPadding(dp(6f).toInt(), dp(14f).toInt(), 0, dp(2f).toInt())
                })
            }

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
