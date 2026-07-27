package com.piyak.english.ui

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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityPlacementBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(this)
        tts = Tts(this)
        tts.rate = db.meta("tts_rate", "1.0").toFloatOrNull() ?: 1.0f

        val all = ContentRepo.placement(this)
        if (all.isEmpty()) { finish(); return }
        for ((lv, q) in all.shuffled()) pool.getOrPut(lv) { ArrayList() }.add(q)

        b.btnClose.setOnClickListener {
            AlertDialog.Builder(this)
                .setMessage("레벨테스트를 그만둘까요?")
                .setPositiveButton("그만두기") { _, _ -> finish() }
                .setNegativeButton("계속", null).show()
        }
        b.btnDone.setOnClickListener { finish() }
        showNext()
    }

    override fun onDestroy() { super.onDestroy(); tts.shutdown() }

    private fun takeQuestion(level: Int): Pair<Int, Question>? {
        // 해당 레벨에 문제가 없으면 가까운 레벨에서 가져온다
        for (d in 0..9) {
            for (lv in listOf(level - d, level + d)) {
                if (lv in 1..10) pool[lv]?.let { if (it.isNotEmpty()) return lv to it.removeAt(it.size - 1) }
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
            else -> { showNext(); return } // 배치고사는 선다형만
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
                curLevel = Placement.nextLevel(lv, correct)
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
        val firstTime = db.meta("placement_done") != "1"
        db.setMeta("placement_level", placed.toString())
        db.setMeta("placement_done", "1")
        db.addXp(30)
        db.markToday()
        var coinLine = ""
        if (firstTime) {
            val c = db.earnCoins(
                com.piyak.english.engine.Wallet.PLACEMENT_BONUS, "PLACEMENT", "레벨테스트 완료"
            )
            coinLine = "\n💰 용돈 +${com.piyak.english.engine.Wallet.format(c)}"
        }
        b.resultPanel.visibility = View.VISIBLE
        b.txtResultTitle.text = "레벨 $placed"
        b.txtResultDesc.text =
            "${Placement.LEVEL_NAMES[placed]} 수준이에요!\n기초 트랙 레벨 ${placed}까지 열어 드렸어요.\n+30 XP 🎁$coinLine"
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}

private data class Quad(val a: String, val b: List<String>, val c: Int, val d: String?)
