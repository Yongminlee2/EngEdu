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
        b.txtTitle.text = "${t.emoji} ${t.title}"
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

        for (u in t.units) {
            val header = TextView(this).apply {
                text = "${u.emoji}  ${u.title}"
                textSize = 17f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setPadding(dp(6), dp(18), 0, dp(6))
            }
            b.unitsBox.addView(header)

            val flow = FlowLayout(this).apply { setPadding(dp(4), 0, dp(4), 0) }
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
                        unlocked -> "🐥"
                        else -> "🥚"
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
                                this@TrackActivity, "앞의 레슨을 먼저 완료해 주세요! 🥚", android.widget.Toast.LENGTH_SHORT
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
