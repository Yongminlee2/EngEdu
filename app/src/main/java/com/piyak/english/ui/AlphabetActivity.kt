package com.piyak.english.ui

import android.content.Intent
import android.os.Bundle
import android.view.Gravity
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.piyak.english.R
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
        listOf(b.btnBack, b.btnUpper, b.btnLower).forEach(UiKit::addPressMotion)
    }

    override fun onResume() {
        super.onResume()
        build()
    }

    private fun build() {
        val db = Db.get(this)
        b.btnUpper.background = UiKit.rounded(
            this, if (uppercase) R.color.primary else R.color.surface,
            if (uppercase) R.color.primary_deep else R.color.outline, 18, 2
        )
        b.btnLower.background = UiKit.rounded(
            this, if (uppercase) R.color.surface else R.color.primary,
            if (uppercase) R.color.outline else R.color.primary_deep, 18, 2
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
                minimumHeight = dp(104)
                background = UiKit.rounded(
                    this@AlphabetActivity,
                    if (done) R.color.primary_soft else R.color.surface,
                    if (done) R.color.primary_deep else R.color.outline,
                    18, 2
                )
                contentDescription = "알파벳 ${d.glyph(uppercase)}, ${d.word}"
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
            UiKit.addPressMotion(card)
            card.addView(TextView(this).apply {
                text = d.glyph(uppercase).toString()
                textSize = 34f
                gravity = Gravity.CENTER
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(ContextCompat.getColor(this@AlphabetActivity, R.color.ink))
            })
            val writes = db.letterWrites(Letters.key(d, uppercase))
            card.addView(TextView(this).apply {
                val stars = db.letterStars(Letters.key(d, uppercase))
                text = if (done) "별 ${stars} · ${writes}번"
                else d.word
                textSize = 12f
                gravity = Gravity.CENTER
                setTextColor(ContextCompat.getColor(this@AlphabetActivity, R.color.ink_muted))
            })
            b.lettersGrid.addView(card)
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
