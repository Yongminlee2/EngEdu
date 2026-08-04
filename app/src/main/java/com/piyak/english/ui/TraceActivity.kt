package com.piyak.english.ui

import android.os.Bundle
import android.view.View
import android.view.animation.AnimationUtils
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.R
import com.piyak.english.audio.Sfx
import com.piyak.english.audio.Tts
import com.piyak.english.databinding.ActivityTraceBinding
import com.piyak.english.db.Db
import com.piyak.english.engine.Letters

/** 글자 하나를 손가락·펜으로 따라 쓰는 화면 */
class TraceActivity : AppCompatActivity() {

    private lateinit var b: ActivityTraceBinding
    private lateinit var db: Db
    private lateinit var tts: Tts
    private lateinit var sfx: Sfx

    private var index = 0
    private var uppercase = true

    // 필드 초기화 시점에는 Context 가 없다 — 처음 쓸 때 리소스에서 읽는다
    private val praises by lazy {
        listOf(getString(R.string.tr_praise_1), getString(R.string.tr_praise_2),
            getString(R.string.tr_praise_3), getString(R.string.tr_praise_4),
            getString(R.string.tr_praise_5))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityTraceBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(this)
        com.piyak.english.i18n.Tpl.init(this)   // 낱말 뜻 번역에 필요
        sfx = Sfx(this)
        tts = Tts(this) { ready -> if (ready) b.root.postDelayed({ sayLetter() }, 400) }
        tts.rate = db.meta("tts_rate", "1.0").toFloatOrNull() ?: 1.0f

        index = intent.getIntExtra("index", 0)
        uppercase = intent.getBooleanExtra("upper", true)

        b.btnClose.setOnClickListener { finish() }
        b.btnSay.setOnClickListener { sayLetter() }
        b.btnDemo.setOnClickListener { b.traceView.playDemo() }
        b.btnAgain.setOnClickListener { loadLetter(index, uppercase) }
        b.btnNext.setOnClickListener {
            if (index < Letters.ALL.size - 1) loadLetter(index + 1, uppercase)
            else finish()
        }

        // 획마다 소리를 내면 한 글자 쓰는 동안 대여섯 번 울려 시끄럽다.
        // 소리는 글자를 다 썼을 때 한 번만 (onLetterComplete 의 sfx.done()).
        b.traceView.onStrokeDone = { updateStrokeInfo() }
        b.traceView.onStrokeFail = {
            b.txtHint.text = getString(R.string.tr_off_path)
            b.traceView.startAnimation(AnimationUtils.loadAnimation(this, R.anim.shake))
        }
        b.traceView.onAllDone = { onLetterComplete() }

        loadLetter(index, uppercase)
    }

    override fun onDestroy() {
        super.onDestroy()
        tts.shutdown(); sfx.release()
    }

    private fun def() = Letters.byIndex(index)

    private fun loadLetter(i: Int, upper: Boolean) {
        index = i
        uppercase = upper
        val d = def()
        b.txtTitle.text = "${d.glyph(true)} ${d.glyph(false)}   (" +
            getString(if (upper) R.string.tr_case_upper else R.string.tr_case_lower) + ")"
        // 낱말 그림이 있으면 이모지 대신 (알파벳 23자 전부 있다)
        val art = resources.getIdentifier("word_" + d.word.lowercase(), "drawable", packageName)
        if (art != 0) {
            b.imgWordArt.visibility = View.VISIBLE
            b.imgWordArt.setImageResource(art)
            b.txtEmoji.visibility = View.GONE
        } else {
            b.imgWordArt.visibility = View.GONE
            b.txtEmoji.visibility = View.VISIBLE
            b.txtEmoji.text = d.emoji
        }
        b.txtWord.text = d.word
        b.txtWordKo.text = com.piyak.english.i18n.Tpl.word(d.ko)   // 뜻은 폰 언어로
        b.donePanel.visibility = View.GONE
        b.btnAgain.text = getString(R.string.ly_clear2)
        val writes = db.letterWrites(Letters.key(d, upper))
        b.txtHint.text = if (writes > 0)
            getString(R.string.tr_written_n, writes)
        else getString(R.string.ly_trace_hint)
        b.traceView.setLetter(d.strokes(upper), d.glyph(upper).toString())
        updateStrokeInfo()
        // 처음 여는 글자는 병아리가 먼저 시범을 보여준다
        b.traceView.postDelayed({ b.traceView.playDemo() }, 600)
        sayLetter()
    }

    private fun updateStrokeInfo() {
        val total = b.traceView.totalStrokes
        val done = b.traceView.doneStrokes
        b.txtStrokeInfo.text = getString(R.string.tr_stroke_of, minOf(done + 1, total), total)
        if (done in 1 until total) b.txtHint.text = getString(R.string.tr_next_stroke, done + 1)
    }

    private fun onLetterComplete() {
        sfx.done()
        val W = com.piyak.english.engine.Wallet
        val key = Letters.key(def(), uppercase)
        val writes = db.addLetterWrite(key)   // 별은 쓴 횟수에 따라 1→2→3개로 늘어난다
        val first = writes == 1
        db.recordSkill("writing", true)
        db.markToday()

        var coins = 0
        if (first) {
            db.addXp(Letters.XP_PER_LETTER)
            coins = db.earnCoins(W.PER_LETTER, "LETTER", getString(R.string.tr_first_write, def().glyph(uppercase)))
        } else if (writes <= W.LETTER_REPEAT_LIMIT) {
            db.addXp(2)
            coins = db.earnCoins(W.PER_LETTER_REPEAT, "LETTER", getString(R.string.tr_nth_write, def().glyph(uppercase), writes))
        }

        val stars = if (writes >= 5) 3 else if (writes >= 3) 2 else 1
        val doneArt = resources.getIdentifier(
            "word_" + def().word.lowercase(), "drawable", packageName
        )
        if (doneArt != 0) {
            b.imgDoneBig.visibility = View.VISIBLE
            b.imgDoneBig.setImageResource(doneArt)
            b.txtDoneBig.visibility = View.GONE
        } else {
            b.imgDoneBig.visibility = View.GONE
            b.txtDoneBig.visibility = View.VISIBLE
            b.txtDoneBig.text = def().emoji
        }
        b.txtDoneMsg.text = getString(R.string.tr_done_msg, praises.random(), "⭐".repeat(stars), writes)
        b.donePanel.visibility = View.VISIBLE
        b.donePanel.alpha = 0f
        b.donePanel.scaleX = 0.5f; b.donePanel.scaleY = 0.5f
        b.donePanel.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(420).start()

        b.txtHint.text = when {
            coins > 0 -> getString(R.string.tr_done_coins, W.format(this@TraceActivity, coins))
            writes < 5 -> getString(R.string.tr_done_more)
            else -> getString(R.string.tr_done_many, writes)
        }
        b.txtStrokeInfo.text = getString(R.string.tr_stroke_done, b.traceView.totalStrokes)
        // 반복 연습이 쉽도록 버튼을 '한 번 더 쓰기'로 바꾼다
        b.btnAgain.text = getString(R.string.tr_write_again)
        sayLetter()
    }

    private fun sayLetter() {
        val d = def()
        tts.speakLines(
            listOf(
                1.05f to d.glyph(uppercase).toString(),
                1.0f to d.word,
            )
        )
    }
}
