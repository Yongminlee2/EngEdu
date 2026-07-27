package com.piyak.english.ui

import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.databinding.ActivityPlaygroundBinding
import com.piyak.english.db.Db
import com.piyak.english.engine.GameReward
import com.piyak.english.engine.MiniGames
import com.piyak.english.model.Subject

/** 놀이터 — 미니게임 고르기 */
class PlaygroundActivity : AppCompatActivity() {

    private lateinit var b: ActivityPlaygroundBinding
    private var subject = Subject.MATH
    private var level = 2

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityPlaygroundBinding.inflate(layoutInflater)
        setContentView(b.root)
        subject = Subject.of(intent.getStringExtra("subject") ?: "math")
        level = Db.get(this).metaInt("game_level", 2).coerceIn(1, 3)

        b.btnBack.setOnClickListener { finish() }
        b.txtTitle.text = "🎮 ${subject.title} 놀이터"
        b.btnLv1.setOnClickListener { setLevel(1) }
        b.btnLv2.setOnClickListener { setLevel(2) }
        b.btnLv3.setOnClickListener { setLevel(3) }
    }

    override fun onResume() {
        super.onResume()
        val db = Db.get(this)
        val theme = Color.parseColor(db.themeColor())
        b.root.setBackgroundColor(theme)
        window.statusBarColor = theme
        setLevel(level)
    }

    private fun setLevel(v: Int) {
        level = v
        Db.get(this).setMeta("game_level", v.toString())
        val on = Color.parseColor("#FFD54F")
        val off = Color.parseColor("#FFF0CC")
        b.btnLv1.backgroundTintList = ColorStateList.valueOf(if (v == 1) on else off)
        b.btnLv2.backgroundTintList = ColorStateList.valueOf(if (v == 2) on else off)
        b.btnLv3.backgroundTintList = ColorStateList.valueOf(if (v == 3) on else off)
        build()
    }

    private fun build() {
        val db = Db.get(this)
        val paidLeft = (GameReward.DAILY_PAID_ROUNDS - db.bonusCountToday("game")).coerceAtLeast(0)

        b.gamesBox.removeAllViews()
        b.gamesBox.addView(TextView(this).apply {
            text = "오늘 용돈 받을 수 있는 판: $paidLeft 판 남음"
            textSize = 12f
            setTextColor(Color.parseColor("#8D6E63"))
            setPadding(dp(6), 0, 0, dp(8))
        })

        for (g in MiniGames.forSubject(subject)) {
            val card = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(18), dp(20), dp(18), dp(20))
                background = GradientDrawable().apply {
                    cornerRadius = dp(22).toFloat()
                    setColor(Color.parseColor(g.color))
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = dp(10) }
                setOnClickListener {
                    startActivity(
                        Intent(this@PlaygroundActivity, GameActivity::class.java)
                            .putExtra("game", g.id)
                            .putExtra("subject", subject.id)
                            .putExtra("level", level)
                    )
                }
            }
            card.addView(TextView(this).apply { text = g.emoji; textSize = 40f })
            val col = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                setPadding(dp(14), 0, 0, 0)
            }
            col.addView(TextView(this).apply {
                text = g.title
                textSize = 20f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(Color.parseColor("#3E2723"))
            })
            col.addView(TextView(this).apply {
                text = g.desc
                textSize = 13f
                setTextColor(Color.parseColor("#5D4037"))
            })
            card.addView(col)
            card.addView(TextView(this).apply {
                text = "▶"
                textSize = 20f
                setTextColor(Color.parseColor("#3E2723"))
            })
            b.gamesBox.addView(card)
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
