package com.piyak.english.ui

import android.content.Intent
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.DrawableCompat
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
        val track = ContentRepo.track(this, trackId) ?: run { finish(); return }
        b.txtTitle.text = track.title
        build(track)
    }

    private fun build(track: TrackData) {
        val db = Db.get(this)
        val done = db.completedLessonIds()
        val freeMode = db.meta("free_mode") == "1"
        val placed = db.metaInt("placement_level", 0)

        b.unitsBox.removeAllViews()
        var doneCount = 0
        var prevAllDone = true

        track.units.forEachIndexed { index, unit ->
            val unitDone = unit.lessons.count { it.id in done }
            doneCount += unitDone

            val card = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(16), dp(16), dp(16), dp(18))
                background = ContextCompat.getDrawable(this@TrackActivity, R.drawable.bg_card_paper)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { bottomMargin = dp(14) }
            }

            val heading = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
            }
            heading.addView(TextView(this).apply {
                text = "UNIT ${index + 1}"
                textSize = 11f
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(ContextCompat.getColor(this@TrackActivity, R.color.mint_deep))
                gravity = Gravity.CENTER
                minHeight = dp(32)
                setPadding(dp(10), 0, dp(10), 0)
                background = ContextCompat.getDrawable(this@TrackActivity, R.drawable.bg_chip_mint)
            })
            heading.addView(LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(12), 0, 0, 0)
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                addView(TextView(this@TrackActivity).apply {
                    text = unit.title
                    textSize = 18f
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(ContextCompat.getColor(this@TrackActivity, R.color.ink))
                })
                addView(TextView(this@TrackActivity).apply {
                    text = "$unitDone / ${unit.lessons.size} 모험 완료"
                    textSize = 12f
                    setTextColor(ContextCompat.getColor(this@TrackActivity, R.color.ink_muted))
                })
            })
            card.addView(heading)

            val journey = JourneyLayout(this).apply {
                setPadding(dp(4), dp(18), dp(4), dp(6))
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                )
            }

            val mathLevel = com.piyak.english.model.MathGrades.of(trackId)
                ?.let { com.piyak.english.model.MathGrades.levelOf(trackId) }
            val unitUnlockedByPlacement = when {
                mathLevel != null -> mathLevel <= db.metaInt("math_placement_level", 0)
                trackId == "basic" -> unit.level <= placed
                else -> false
            }

            for (lesson in unit.lessons) {
                val isDone = lesson.id in done
                val unlocked = freeMode || unitUnlockedByPlacement || isDone || prevAllDone
                if (!isDone) prevAllDone = false
                val stars = db.lessonStars(lesson.id).coerceIn(1, 3)

                val node = Button(this).apply {
                    layoutParams = ViewGroup.LayoutParams(dp(72), dp(72))
                    minWidth = 0
                    minimumWidth = 0
                    minHeight = 0
                    minimumHeight = 0
                    isAllCaps = false
                    gravity = Gravity.CENTER
                    setPadding(0, dp(5), 0, dp(3))
                    setTypeface(typeface, Typeface.BOLD)
                    textSize = 10f
                    background = ContextCompat.getDrawable(
                        this@TrackActivity,
                        when {
                            isDone -> R.drawable.bg_node_complete
                            unlocked -> R.drawable.bg_node_current
                            else -> R.drawable.bg_node_locked
                        },
                    )
                    val iconRes = when {
                        isDone -> R.drawable.ic_star_rounded
                        unlocked -> R.drawable.ic_play_arrow_rounded
                        else -> R.drawable.ic_lock_rounded
                    }
                    val icon = ContextCompat.getDrawable(this@TrackActivity, iconRes)?.mutate()
                    if (icon != null) {
                        DrawableCompat.setTint(
                            icon,
                            ContextCompat.getColor(
                                this@TrackActivity,
                                if (unlocked || isDone) R.color.ink else R.color.ink_muted,
                            ),
                        )
                        icon.setBounds(0, 0, dp(27), dp(27))
                        setCompoundDrawables(null, icon, null, null)
                    }
                    text = when {
                        isDone -> "$stars"
                        unlocked -> "시작"
                        else -> ""
                    }
                    alpha = if (unlocked) 1f else 0.72f
                    contentDescription = when {
                        isDone -> "${lesson.title}, 완료, 별 ${stars}개"
                        unlocked -> "${lesson.title}, 시작할 수 있음"
                        else -> "${lesson.title}, 잠김"
                    }
                    setOnClickListener {
                        if (!unlocked) {
                            Toast.makeText(
                                this@TrackActivity,
                                "앞의 레슨을 먼저 완료해 주세요!",
                                Toast.LENGTH_SHORT,
                            ).show()
                        } else {
                            animate().scaleX(0.92f).scaleY(0.92f).setDuration(70).withEndAction {
                                animate().scaleX(1f).scaleY(1f).setDuration(90).start()
                                startActivity(
                                    Intent(this@TrackActivity, LessonActivity::class.java)
                                        .putExtra("track", trackId)
                                        .putExtra("lesson", lesson.id),
                                )
                            }.start()
                        }
                    }
                }
                journey.addView(node)
            }
            card.addView(journey)
            b.unitsBox.addView(card)
        }
        b.txtTrackProgress.text = "$doneCount / ${track.lessonCount}"
        b.txtTrackProgress.contentDescription = "전체 ${track.lessonCount}개 중 ${doneCount}개 완료"
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
