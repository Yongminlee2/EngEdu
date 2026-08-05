package com.piyak.english.ui

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.R
import com.piyak.english.databinding.ActivityTrackBinding
import com.piyak.english.db.Db
import com.piyak.english.model.ContentRepo
import com.piyak.english.model.TrackData

class TrackActivity : AppCompatActivity() {

    private lateinit var b: ActivityTrackBinding
    private var trackId = "basic"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityTrackBinding.inflate(layoutInflater)
        setContentView(b.root)
        trackId = intent.getStringExtra("track") ?: "basic"
        b.btnBack.setOnClickListener { finish() }
    }

    override fun onResume() {
        super.onResume()
        val t = ContentRepo.track(this, trackId) ?: run { finish(); return }
        val stageTitle = intent.getStringExtra("stageTitle")
        b.txtTitle.text = if (stageTitle != null) "${t.emoji} $stageTitle" else "${t.emoji} ${t.title}"
        build(t)
    }

    private fun build(t: TrackData) {
        val db = Db.get(this)
        val done = db.completedLessonIds()
        val freeMode = db.meta("free_mode") == "1"
        val placed = db.metaInt("placement_level", 0)

        b.unitsBox.removeAllViews()
        var doneCount = 0
        var prevAllDone = true // 트랙 내 순차 해금 포인터

        // 학년별 진입이면 그 레벨의 유닛만 보여준다 (기초 코스 레벨 = 학년)
        val lvMin = intent.getIntExtra("lvMin", 0)
        val lvMax = intent.getIntExtra("lvMax", 99)
        for (u in t.units) {
            if (u.level < lvMin || u.level > lvMax) continue
            val header = TextView(this).apply {
                text = "${u.emoji}  ${u.title}"
                textSize = 17f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setPadding(dp(6), dp(18), 0, dp(6))
            }
            b.unitsBox.addView(header)

            // 맨 아랫줄 원이 "살짝 가려" 보이던 것 — 원의 그림자는 뷰 **바깥**에 그려지는데
            // 안드로이드는 기본으로 자식을 부모 경계에서 잘라낸다(clipChildren).
            // 여백만 줘도 부모가 다시 자를 수 있어서 잘라내기 자체를 꺼 둔다.
            val flow = FlowLayout(this).apply {
                setPadding(dp(4), dp(2), dp(4), dp(10))
                clipChildren = false
                clipToPadding = false
            }
            // 배치고사 결과 이하는 전체 해금 — 영어는 기초 트랙의 레벨, 수학은 학년 단위
            val mathLevel = com.piyak.english.model.MathGrades.of(trackId)
                ?.let { com.piyak.english.model.MathGrades.levelOf(trackId) }
            val unitUnlockedByPlacement = when {
                mathLevel != null -> mathLevel <= db.metaInt("math_placement_level", 0)
                trackId == "basic" -> u.level <= placed
                else -> false
            }

            for (l in u.lessons) {
                val isDone = l.id in done
                if (isDone) doneCount++
                val unlocked = freeMode || unitUnlockedByPlacement || isDone || prevAllDone
                if (!isDone) prevAllDone = false

                val node = Button(this).apply {
                    layoutParams = LinearLayout.LayoutParams(dp(72), dp(72))
                    // 기본 최소 폭이 크면 원이 타원으로 늘어난다
                    minWidth = 0; minimumWidth = 0
                    minHeight = 0; minimumHeight = 0
                    setPadding(0, 0, 0, 0)
                    background = getDrawable(R.drawable.bg_node)
                    val stars = db.lessonStars(l.id)
                    text = when {
                        isDone -> "⭐".repeat(stars.coerceIn(1, 3))
                        unlocked -> ""      // 아래 foreground 의 병아리가 선다
                        else -> "🥚"
                    }
                    if (!isDone && unlocked) {
                        // 다음에 풀 레슨 위에 병아리가 서 있다 (듀오링고처럼)
                        //
                        // 사방 9dp 로 균등하게 넣으면 발과 몸통 양옆이 원 테두리에 닿아
                        // **잘린 것처럼 보인다.** 위를 줄이고 아래를 늘려 살짝 띄운다.
                        // 좌우 합(22)과 상하 합(22)이 같아야 상자가 정사각형이라 안 찌그러진다.
                        foreground = android.graphics.drawable.InsetDrawable(
                            getDrawable(R.drawable.ck_idle), dp(11), dp(7), dp(11), dp(15)
                        )
                    }
                    textSize = if (isDone) 11f else 22f
                    gravity = Gravity.CENTER
                    backgroundTintList = android.content.res.ColorStateList.valueOf(
                        when {
                            isDone -> Color.parseColor("#FFD54F")
                            unlocked -> Color.parseColor("#FFFFFF")
                            else -> Color.parseColor("#EDE7E0")
                        }
                    )
                    alpha = if (unlocked) 1f else 0.55f
                    setOnClickListener {
                        if (!unlocked) {
                            android.widget.Toast.makeText(
                                this@TrackActivity, getString(R.string.locked_lesson), android.widget.Toast.LENGTH_SHORT
                            ).show()
                        } else {
                            startActivity(
                                Intent(this@TrackActivity, LessonActivity::class.java)
                                    .putExtra("track", trackId).putExtra("lesson", l.id)
                            )
                        }
                    }
                }
                flow.addView(node)
            }
            b.unitsBox.addView(flow)
        }
        b.txtTrackProgress.text = "$doneCount/${t.lessonCount}"
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
