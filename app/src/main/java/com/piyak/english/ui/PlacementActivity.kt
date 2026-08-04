package com.piyak.english.ui

import com.piyak.english.R
import android.content.res.ColorStateList
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.audio.Tts
import com.piyak.english.databinding.ActivityPlacementBinding
import com.piyak.english.db.Db
import com.piyak.english.engine.Placement
import com.piyak.english.model.ContentRepo
import com.piyak.english.model.Question

class PlacementActivity : AppCompatActivity() {

    private lateinit var b: ActivityPlacementBinding
    private lateinit var db: Db
    private lateinit var tts: Tts

    private var pool: MutableMap<Int, MutableList<Question>> = HashMap()
    private val history = ArrayList<Pair<Int, Boolean>>()
    private var curLevel = Placement.START_LEVEL
    private var count = 0
    private val TOTAL = Placement.TOTAL
    private lateinit var subject: com.piyak.english.model.Subject
    private var maxLevel = Placement.MAX_LEVEL_ENGLISH

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityPlacementBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(this)
        tts = Tts(this)
        tts.rate = db.meta("tts_rate", "1.0").toFloatOrNull() ?: 1.0f

        subject = com.piyak.english.model.Subject.of(intent.getStringExtra("subject") ?: "english")
        maxLevel = Placement.maxLevel(subject)

        val all = ContentRepo.placement(this, subject)
        if (all.isEmpty()) { finish(); return }
        for ((lv, q) in all.shuffled()) pool.getOrPut(lv) { ArrayList() }.add(q)

        b.btnClose.setOnClickListener {
            val den = resources.displayMetrics.density
            val box = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = android.view.Gravity.CENTER_HORIZONTAL
                setPadding((20 * den).toInt(), (20 * den).toInt(), (20 * den).toInt(), (4 * den).toInt())
            }
            box.addView(android.widget.ImageView(this).apply {
                setImageResource(com.piyak.english.R.drawable.ck_cheerup)
                layoutParams = LinearLayout.LayoutParams((96 * den).toInt(), (96 * den).toInt())
            })
            box.addView(android.widget.TextView(this).apply {
                text = getString(R.string.placement_quit_ask)
                textSize = 15f
                gravity = android.view.Gravity.CENTER
                setTextColor(Color.parseColor("#4E342E"))
                setPadding(0, (10 * den).toInt(), 0, 0)
            })
            AlertDialog.Builder(this)
                .setView(box)
                .setPositiveButton(getString(R.string.quit_yes)) { _, _ -> finish() }
                .setNegativeButton(getString(R.string.quit_no), null).show()
        }
        b.btnDone.setOnClickListener { finish() }
        showNext()
    }

    override fun onDestroy() { super.onDestroy(); tts.shutdown() }

    private fun takeQuestion(level: Int): Pair<Int, Question>? {
        // 해당 레벨에 문제가 없으면 가까운 레벨에서 가져온다
        for (d in 0..maxLevel) {
            for (lv in listOf(level - d, level + d)) {
                if (lv in 1..maxLevel) {
                    pool[lv]?.let { if (it.isNotEmpty()) return lv to it.removeAt(it.size - 1) }
                }
            }
        }
        return null
    }

    private fun showNext() {
        if (count >= TOTAL) { showResult(); return }
        val (lv, q) = takeQuestion(curLevel) ?: run { showResult(); return }
        count++
        b.txtCount.text = "$count / $TOTAL"
        b.progressBar.progress = count * 100 / TOTAL
        b.choicesBox.removeAllViews()
        b.btnPlay.visibility = View.GONE
        tts.stop()

        val (prompt, choices, answer, ttsText) = when (q) {
            is Question.Mcq -> Quad(q.prompt, q.choices, q.answer, null)
            is Question.ListenMcq -> Quad(q.prompt, q.choices, q.answer, q.tts)
            else -> { showNext(); return }
        }
        b.txtPrompt.text = prompt
        if (ttsText != null) {
            b.btnPlay.visibility = View.VISIBLE
            b.btnPlay.setOnClickListener { tts.speak(ttsText) }
            b.root.postDelayed({ tts.speak(ttsText) }, 300)
        }

        choices.forEachIndexed { i, c ->
            val btn = Button(this).apply {
                text = c; textSize = 16f; isAllCaps = false
                setTextColor(Color.parseColor("#4E342E"))
                backgroundTintList = ColorStateList.valueOf(Color.WHITE)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = dp(8) }
            }
            btn.setOnClickListener {
                val correct = i == answer
                history.add(lv to correct)
                curLevel = Placement.nextLevel(lv, correct, maxLevel)
                btn.backgroundTintList = ColorStateList.valueOf(
                    Color.parseColor(if (correct) "#C8E6C9" else "#FFCDD2")
                )
                b.choicesBox.postDelayed({ showNext() }, 350)
                // 더블탭 방지
                for (j in 0 until b.choicesBox.childCount) b.choicesBox.getChildAt(j).isEnabled = false
            }
            b.choicesBox.addView(btn)
        }
    }

    private fun showResult() {
        val placed = Placement.placeLevel(history)
        val doneKey = Placement.doneKey(subject)
        val firstTime = db.meta(doneKey) != "1"
        db.setMeta(Placement.levelKey(subject), placed.toString())
        db.setMeta(doneKey, "1")
        db.addXp(30)
        db.markToday()
        var coinLine = ""
        if (firstTime) {
            val c = db.earnCoins(
                com.piyak.english.engine.Wallet.PLACEMENT_BONUS, "PLACEMENT",
                getString(R.string.placement_done, getString(subject.titleRes))
            )
            coinLine = "\n" + getString(R.string.placement_coins, com.piyak.english.engine.Wallet.format(this@PlacementActivity, c))
        }
        b.resultPanel.visibility = View.VISIBLE
        val name = Placement.levelName(this, subject, placed)
        if (subject == com.piyak.english.model.Subject.MATH) {
            b.txtResultTitle.text = name
            b.txtResultDesc.text =
                getString(R.string.placement_msg_math, name) + coinLine
        } else {
            b.txtResultTitle.text = getString(R.string.placement_level, placed)
            b.txtResultDesc.text =
                getString(R.string.placement_msg_en, name, placed) + coinLine
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}

private data class Quad(val a: String, val b: List<String>, val c: Int, val d: String?)
