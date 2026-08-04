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
import com.piyak.english.R
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
    private var sfx: com.piyak.english.audio.Sfx? = null
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

        // 살아있는 마스코트 — 천천히 숨쉬고, 톡 치면 삐약! 하고 점프
        sfx = com.piyak.english.audio.Sfx(this)
        PoseAnim.applyTo(b.imgMascot, R.drawable.ck_idle)   // 가끔 눈을 깜빡인다
        android.animation.ObjectAnimator.ofPropertyValuesHolder(
            b.imgMascot,
            android.animation.PropertyValuesHolder.ofFloat(View.SCALE_X, 1f, 1.045f),
            android.animation.PropertyValuesHolder.ofFloat(View.SCALE_Y, 1f, 1.045f),
        ).apply {
            duration = 1300L
            repeatCount = android.animation.ValueAnimator.INFINITE
            repeatMode = android.animation.ValueAnimator.REVERSE
            interpolator = android.view.animation.AccelerateDecelerateInterpolator()
            start()
        }
        b.imgMascot.setOnClickListener {
            sfx?.piyak()
            b.imgMascot.animate().translationY(-dp(10f)).setDuration(140L)
                .withEndAction {
                    b.imgMascot.animate().translationY(0f).setDuration(260L)
                        .setInterpolator(android.view.animation.BounceInterpolator()).start()
                }.start()
        }
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
        // 시간대에 따라 풍경이 바뀐다 — 아침 하늘, 낮 풀밭, 저녁 교실, 밤엔 별
        val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
        val banner = when (hour) {
            in 6..10 -> R.drawable.banner_sky
            in 11..16 -> R.drawable.banner_grass
            in 17..20 -> R.drawable.banner_class
            else -> R.drawable.banner_night
        }
        b.imgBanner.setImageResource(banner)
        b.imgBanner.clipToOutline = true
        b.imgBanner.outlineProvider = object : android.view.ViewOutlineProvider() {
            override fun getOutline(v: View, o: android.graphics.Outline) =
                o.setRoundRect(0, 0, v.width, v.height, dp(18f))
        }
        refresh()
    }

    private fun refresh() {
        val db = Db.get(this)
        val xp = db.xp()
        val lv = Economy.levelFor(xp)
        b.txtHearts.text = if (db.heartsEnabled()) "${db.hearts()}" else ""
        b.txtHearts.setCompoundDrawablesRelativeWithIntrinsicBounds(
            if (db.heartsEnabled()) R.drawable.ic_heart else 0, 0, 0, 0
        )
        val (streak, _) = Economy.streak(db.studyDays(), Db.today())
        b.txtStreak.text = "$streak"
        b.txtLevel.text = "Lv.$lv"
        b.xpBar.progress = (Economy.levelProgress(xp) * 100).toInt()
        b.txtReview.text = "오답 ${db.wrongCount()}"
        // 배치고사 배너: 과목별로 아직 안 본 경우에만
        val placedKey = if (subject == com.piyak.english.model.Subject.MATH)
            "math_placement_done" else "placement_done"
        b.bannerPlacement.visibility = if (db.meta(placedKey) == "1") View.GONE else View.VISIBLE
        b.txtPlacement.text = if (subject == com.piyak.english.model.Subject.MATH)
            "수학 레벨테스트로 내 학년 찾기!\n25문제로 딱 맞는 단계를 정해줘요"
        else "레벨테스트로 내 위치 찾기!\n25문제로 딱 맞는 레벨을 정해줘요"

        // 상점에서 산 테마 배경 적용
        val theme = Color.parseColor(db.themeColor())
        b.root.setBackgroundColor(theme)
        window.statusBarColor = theme

        b.txtCoins.text = com.piyak.english.engine.Wallet.format(this, db.coins())
        // 알파벳·놀이터는 "유치원 영어" 단계 안으로 이사 — 홈을 가볍게
        b.cardAlphabet.visibility = View.GONE
        b.cardPlayground.visibility = View.GONE
        // '내 실력' 카드가 제목만 있고 속이 비어 보여서 영역 줄을 다시 보여준다
        b.skillsBox.visibility = View.VISIBLE
        b.txtWeakest.visibility = View.VISIBLE
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
        b.txtGoal.text = "오늘의 목표  $todayXp / $goal XP" + if (done) "   ✅ 달성!" else ""
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

    /** 홈의 단계 카드 5장 — 유치원/초등/중등·고등/성인·실전/영역별 */
    private fun buildTrackCards(db: Db) {
        b.tracksBox.removeAllViews()
        data class Stage(val emoji: String, val title: String, val sub: String, val color: String, val id: String)
        val stages = listOf(
            Stage("🐣", "유치원 영어", "알파벳 쓰기 · 놀이터", "#FFF3D6", "kinder"),
            Stage("📗", "초등 영어", "초등영어 코스 · 기초 1~6학년", "#E8F6EA", "elementary"),
            Stage("📘", "중등 · 고등 영어", "학년별 기초 · 문법 · 독해", "#E3F4FD", "middle"),
            Stage("✈️", "성인 · 실전 영어", "회화 · 토익 · 토플", "#F3EDFB", "adult"),
            Stage("🎯", "영역별 훈련", "듣기 · 말하기 · 쓰기 · 문법 · 독해", "#FDE2E2", "skills"),
        )
        // codex 단계 일러스트 (발주서 #04) — 없으면 이모지 동그라미로
        fun stageArt(id: String): Int =
            resources.getIdentifier("stage_$id", "drawable", packageName)
        for (s in stages) {
            val card = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(18f).toInt(), dp(18f).toInt(), dp(16f).toInt(), dp(18f).toInt())
                background = GradientDrawable().apply {
                    cornerRadius = dp(26f)
                    setColor(Color.WHITE)
                    setStroke(dp(3f).toInt(), Color.parseColor(s.color).let { c ->
                        Color.rgb((Color.red(c) * 0.82f).toInt(), (Color.green(c) * 0.82f).toInt(), (Color.blue(c) * 0.82f).toInt())
                    })
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = dp(12f).toInt() }
                setOnClickListener {
                    startActivity(Intent(this@MainActivity, StageActivity::class.java).putExtra("stage", s.id))
                }
            }
            val art = stageArt(s.id)
            if (art != 0) card.addView(android.widget.ImageView(this).apply {
                setImageResource(art)
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor(s.color))
                }
                val pad = dp(3f).toInt()
                setPadding(pad, pad, pad, pad)
                layoutParams = LinearLayout.LayoutParams(dp(80f).toInt(), dp(80f).toInt())
            }) else card.addView(TextView(this).apply {
                text = s.emoji
                textSize = 28f
                gravity = Gravity.CENTER
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor(s.color))
                }
                layoutParams = LinearLayout.LayoutParams(dp(58f).toInt(), dp(58f).toInt())
            })
            val col = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                setPadding(dp(14f).toInt(), 0, 0, 0)
            }
            col.addView(TextView(this).apply {
                text = s.title
                textSize = 18f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(Color.parseColor("#4E342E"))
            })
            col.addView(TextView(this).apply {
                text = s.sub
                textSize = 13f
                setTextColor(Color.parseColor("#8D6E63"))
            })
            card.addView(col)
            card.addView(TextView(this).apply { text = "▶"; textSize = 16f; setTextColor(Color.parseColor("#C9A25E")) })
            b.tracksBox.addView(card)
        }
    }

    override fun onDestroy() { super.onDestroy(); sfx?.release() }

    private fun dp(v: Float): Float = v * resources.displayMetrics.density
}
