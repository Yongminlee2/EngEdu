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
            // 수학 배치고사는 선다형과 숫자 답 문제가 섞여 있다 — 숫자 답은 보기로 바꿔 낸다
            is Question.Math -> when {
                q.input == "choice" && q.choices.size == 4 ->
                    Quad(q.prompt, q.choices, q.answerIndex, null)
                else -> {
                    val opts = numericOptions(q.answer)
                    if (opts == null) { showNext(); return }
                    Quad(q.prompt, opts.first, opts.second, null)
                }
            }
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

    /**
     * 숫자로 답하는 수학 문제를 배치고사용 4지선다로 바꾼다.
     * 배치고사는 빠르게 넘겨야 해서 키패드 대신 보기를 준다.
     */
    private fun numericOptions(answer: String): Pair<List<String>, Int>? {
        val v = com.piyak.english.engine.MathGrader.parse(answer) ?: return null
        if (v != Math.floor(v) || Math.abs(v) > 100000) return null
        val n = v.toInt()
        val wrong = LinkedHashSet<Int>()
        var d = 1
        while (wrong.size < 3 && d < 40) {
            for (w in listOf(n + d, n - d)) {
                if (w != n && w >= 0 && wrong.size < 3) wrong.add(w)
            }
            d++
        }
        if (wrong.size < 3) return null
        val opts = (listOf(n) + wrong).map { it.toString() }.shuffled()
        return opts to opts.indexOf(n.toString())
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
                "${subject.title} 레벨테스트 완료"
            )
            coinLine = "\n💰 용돈 +${com.piyak.english.engine.Wallet.format(c)}"
        }
        b.resultPanel.visibility = View.VISIBLE
        val name = Placement.levelName(subject, placed)
        if (subject == com.piyak.english.model.Subject.MATH) {
            b.txtResultTitle.text = name
            b.txtResultDesc.text =
                "$name 수준이에요!\n${name}까지 모든 단원을 열어 드렸어요.\n+30 XP 🎁$coinLine"
        } else {
            b.txtResultTitle.text = "레벨 $placed"
            b.txtResultDesc.text =
                "$name 수준이에요!\n기초 트랙 레벨 ${placed}까지 열어 드렸어요.\n+30 XP 🎁$coinLine"
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}

private data class Quad(val a: String, val b: List<String>, val c: Int, val d: String?)
