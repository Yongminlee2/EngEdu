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

        // 획마다 소리를 내면 한 글자 쓰는 동안 대여섯 번 울려 시끄럽다.
        // 소리는 글자를 다 썼을 때 한 번만 (onLetterComplete 의 sfx.done()).
        b.traceView.onStrokeDone = { updateStrokeInfo() }
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
        b.txtWordKo.text = d.ko
        b.donePanel.visibility = View.GONE
        b.btnAgain.text = "↻ 지우기"
        val writes = db.letterWrites(Letters.key(d, upper))
        b.txtHint.text = if (writes > 0)
            "지금까지 ${writes}번 썼어요. 또 써 볼까요? ✏️"
        else "초록 ① 부터 길을 따라 그려 보세요!"
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
        val W = com.piyak.english.engine.Wallet
        val key = Letters.key(def(), uppercase)
        val writes = db.addLetterWrite(key)   // 별은 쓴 횟수에 따라 1→2→3개로 늘어난다
        val first = writes == 1
        db.recordSkill("writing", true)
        db.markToday()

        var coins = 0
        if (first) {
            db.addXp(Letters.XP_PER_LETTER)
            coins = db.earnCoins(W.PER_LETTER, "LETTER", "${def().glyph(uppercase)} 처음 쓰기")
        } else if (writes <= W.LETTER_REPEAT_LIMIT) {
            db.addXp(2)
            coins = db.earnCoins(W.PER_LETTER_REPEAT, "LETTER", "${def().glyph(uppercase)} ${writes}번째 쓰기")
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
        b.txtDoneMsg.text = "${praises.random()}\n${"⭐".repeat(stars)}  ${writes}번 썼어요!"
        b.donePanel.visibility = View.VISIBLE
        b.donePanel.alpha = 0f
        b.donePanel.scaleX = 0.5f; b.donePanel.scaleY = 0.5f
        b.donePanel.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(420).start()

        b.txtHint.text = when {
            coins > 0 -> "완성! 용돈 +${W.format(this@TraceActivity, coins)} 🎁  · '한 번 더 쓰기'로 연습해요!"
            writes < 5 -> "완성! 한 번 더 써 볼까요? ✏️"
            else -> "이 글자는 ${writes}번이나 썼어요! 정말 잘하네요 🌟"
        }
        b.txtStrokeInfo.text = "${b.traceView.totalStrokes} / ${b.traceView.totalStrokes} 획 ✅"
        // 반복 연습이 쉽도록 버튼을 '한 번 더 쓰기'로 바꾼다
        b.btnAgain.text = "✏️ 한 번 더 쓰기"
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
