package com.piyak.english.ui

import com.piyak.english.R
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.databinding.ActivityAlphabetBinding
import com.piyak.english.db.Db
import com.piyak.english.engine.Letters

/** A~Z 카드 목록. 대문자/소문자를 골라 연습한다. */
class AlphabetActivity : AppCompatActivity() {

    private lateinit var b: ActivityAlphabetBinding
    private var uppercase = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityAlphabetBinding.inflate(layoutInflater)
        setContentView(b.root)
        b.btnBack.setOnClickListener { finish() }
        b.btnUpper.setOnClickListener { uppercase = true; build() }
        b.btnLower.setOnClickListener { uppercase = false; build() }
    }

    override fun onResume() {
        super.onResume()
        build()
    }

    private fun build() {
        val db = Db.get(this)
        b.btnUpper.backgroundTintList = ColorStateList.valueOf(
            Color.parseColor(if (uppercase) "#FFD54F" else "#FFF0CC")
        )
        b.btnLower.backgroundTintList = ColorStateList.valueOf(
            Color.parseColor(if (uppercase) "#FFF0CC" else "#FFD54F")
        )

        var doneCount = 0
        for (d in Letters.ALL) {
            if (db.letterStars(Letters.key(d, true)) > 0) doneCount++
            if (db.letterStars(Letters.key(d, false)) > 0) doneCount++
        }
        b.txtDone.text = "$doneCount/${Letters.ALL.size * 2}"

        b.lettersGrid.removeAllViews()
        Letters.ALL.forEachIndexed { i, d ->
            val done = db.letterStars(Letters.key(d, uppercase)) > 0
            val card = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(0, dp(12), 0, dp(12))
                background = android.graphics.drawable.GradientDrawable().apply {
                    cornerRadius = dp(18).toFloat()
                    setColor(Color.parseColor(if (done) "#FFE7A8" else "#FFFFFF"))
                    setStroke(dp(2), Color.parseColor(if (done) "#FFB300" else "#FFE082"))
                }
                layoutParams = GridLayout.LayoutParams().apply {
                    width = 0
                    columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f)
                    setMargins(dp(5), dp(5), dp(5), dp(5))
                }
                setOnClickListener {
                    startActivity(
                        Intent(this@AlphabetActivity, TraceActivity::class.java)
                            .putExtra("index", i)
                            .putExtra("upper", uppercase)
                    )
                }
            }
            val cardArt = resources.getIdentifier(
                "word_" + d.word.lowercase(), "drawable", packageName
            )
            if (cardArt != 0) card.addView(android.widget.ImageView(this).apply {
                setImageResource(cardArt)
                layoutParams = LinearLayout.LayoutParams(dp(38), dp(38))
            }) else card.addView(TextView(this).apply {
                text = d.emoji
                textSize = 26f
                gravity = Gravity.CENTER
            })
            card.addView(TextView(this).apply {
                text = d.glyph(uppercase).toString()
                textSize = 30f
                gravity = Gravity.CENTER
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(Color.parseColor("#4E342E"))
            })
            val writes = db.letterWrites(Letters.key(d, uppercase))
            card.addView(TextView(this).apply {
                text = if (done) getString(R.string.tr_times, "⭐".repeat(db.letterStars(Letters.key(d, uppercase))), writes)
                else d.word
                textSize = 11f
                gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#8D6E63"))
            })
            b.lettersGrid.addView(card)
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
