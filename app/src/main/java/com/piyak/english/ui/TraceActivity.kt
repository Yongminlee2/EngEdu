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

    private val praises = listOf("잘했어요! 🎉", "완벽해요! 🌟", "삐약! 최고예요!", "멋져요! 👏", "우와, 예쁘게 썼네요!")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityTraceBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(this)
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

        b.traceView.onStrokeDone = { sfx.piyak(); updateStrokeInfo() }
        b.traceView.onStrokeFail = {
            b.txtHint.text = "앗, 길을 벗어났어요. 다시 천천히! 🐥"
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
        b.txtTitle.text = "${d.glyph(true)} ${d.glyph(false)}   (${if (upper) "대문자" else "소문자"})"
        b.txtEmoji.text = d.emoji
        b.txtWord.text = d.word
        b.txtWordKo.text = d.ko
        b.donePanel.visibility = View.GONE
        b.txtHint.text = "초록 ① 부터 길을 따라 그려 보세요!"
        b.traceView.setLetter(d.strokes(upper), d.glyph(upper).toString())
        updateStrokeInfo()
        // 처음 여는 글자는 병아리가 먼저 시범을 보여준다
        b.traceView.postDelayed({ b.traceView.playDemo() }, 600)
        sayLetter()
    }

    private fun updateStrokeInfo() {
        val total = b.traceView.totalStrokes
        val done = b.traceView.doneStrokes
        b.txtStrokeInfo.text = "${minOf(done + 1, total)} / $total 획"
        if (done in 1 until total) b.txtHint.text = "좋아요! 다음은 ${done + 1}번 획이에요 ✏️"
    }

    private fun onLetterComplete() {
        sfx.done()
        val key = Letters.key(def(), uppercase)
        val first = db.letterStars(key) == 0
        db.setLetterStars(key, 3)
        var coins = 0
        if (first) {
            db.addXp(Letters.XP_PER_LETTER)
            db.recordSkill("writing", true)
            db.markToday()
            coins = db.earnCoins(
                com.piyak.english.engine.Wallet.PER_LETTER, "LETTER",
                "알파벳 ${def().glyph(uppercase)} 쓰기 완성"
            )
        }
        b.txtDoneBig.text = def().emoji
        b.txtDoneMsg.text = praises.random()
        b.donePanel.visibility = View.VISIBLE
        b.donePanel.alpha = 0f
        b.donePanel.scaleX = 0.5f; b.donePanel.scaleY = 0.5f
        b.donePanel.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(420).start()
        b.txtHint.text = if (first)
            "완성! +${Letters.XP_PER_LETTER} XP · 용돈 +${com.piyak.english.engine.Wallet.format(coins)} 🎁"
        else "완성! 다시 써도 좋아요 😊"
        b.txtStrokeInfo.text = "${b.traceView.totalStrokes} / ${b.traceView.totalStrokes} 획 ✅"
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
