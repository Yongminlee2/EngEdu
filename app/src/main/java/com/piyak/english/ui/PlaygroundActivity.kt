package com.piyak.english.ui

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.piyak.english.R
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
        b.txtTitle.text = "${subject.title} 놀이터"
        b.btnLv1.setOnClickListener { setLevel(1) }
        b.btnLv2.setOnClickListener { setLevel(2) }
        b.btnLv3.setOnClickListener { setLevel(3) }
        listOf(b.btnBack, b.btnLv1, b.btnLv2, b.btnLv3).forEach(UiKit::addPressMotion)
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
        listOf(b.btnLv1, b.btnLv2, b.btnLv3).forEachIndexed { index, button ->
            val selected = index + 1 == v
            button.background = UiKit.rounded(
                this, if (selected) R.color.primary else R.color.surface,
                if (selected) R.color.primary_deep else R.color.outline, 18, 2
            )
        }
        build()
    }

    private fun build() {
        val db = Db.get(this)
        val paidLeft = (GameReward.DAILY_PAID_ROUNDS - db.bonusCountToday("game")).coerceAtLeast(0)

        b.gamesBox.removeAllViews()
        b.gamesBox.addView(TextView(this).apply {
            text = "오늘 용돈 받을 수 있는 판: $paidLeft 판 남음"
            textSize = 12f
            setTextColor(ContextCompat.getColor(this@PlaygroundActivity, R.color.ink_muted))
            setPadding(dp(6), 0, 0, dp(8))
        })

        val fills = intArrayOf(R.color.sky_soft, R.color.mint_soft, R.color.lavender_soft)
        for ((index, g) in MiniGames.forSubject(subject).withIndex()) {
            val card = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(18), dp(20), dp(18), dp(20))
                background = UiKit.rounded(
                    this@PlaygroundActivity, fills[index % fills.size],
                    R.color.outline_strong, 22, 2
                )
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
            UiKit.addPressMotion(card)
            card.addView(ImageView(this).apply {
                setImageResource(R.drawable.ic_sports_esports_rounded)
                imageTintList = ContextCompat.getColorStateList(this@PlaygroundActivity, R.color.ink)
                contentDescription = null
                layoutParams = LinearLayout.LayoutParams(dp(48), dp(48))
                setPadding(dp(8), dp(8), dp(8), dp(8))
            })
            val col = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                setPadding(dp(14), 0, 0, 0)
            }
            col.addView(TextView(this).apply {
                text = g.title
                textSize = 20f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(ContextCompat.getColor(this@PlaygroundActivity, R.color.ink))
            })
            col.addView(TextView(this).apply {
                text = g.desc
                textSize = 13f
                setTextColor(ContextCompat.getColor(this@PlaygroundActivity, R.color.ink_muted))
            })
            card.addView(col)
            card.addView(ImageView(this).apply {
                setImageResource(R.drawable.ic_chevron_right_rounded)
                imageTintList = ContextCompat.getColorStateList(this@PlaygroundActivity, R.color.ink)
                contentDescription = null
                layoutParams = LinearLayout.LayoutParams(dp(32), dp(32))
            })
            b.gamesBox.addView(card)
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
