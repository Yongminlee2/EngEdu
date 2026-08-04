package com.piyak.english.ui

import com.piyak.english.R
import android.os.Bundle
import android.os.CountDownTimer
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.audio.Sfx
import com.piyak.english.audio.Tts
import com.piyak.english.databinding.ActivityGameBinding
import com.piyak.english.db.Db
import com.piyak.english.engine.GameReward
import com.piyak.english.engine.MiniGames
import com.piyak.english.engine.Wallet
import com.piyak.english.model.Subject
import com.piyak.english.ui.game.BalloonGameView
import com.piyak.english.ui.game.BasketGameView
import com.piyak.english.ui.game.LineMatchView

/** 미니게임 한 판 */
class GameActivity : AppCompatActivity() {

    companion object {
        const val ROUNDS = 10
        const val LIVES = 3
        const val TIME_MS = 90_000L
    }

    private lateinit var b: ActivityGameBinding
    private lateinit var db: Db
    private lateinit var sfx: Sfx
    private lateinit var tts: Tts

    private var gameId = MiniGames.BALLOON
    private var subject = Subject.MATH
    private var level = 2

    private var score = 0
    private var lives = LIVES
    private var roundsDone = 0
    private var timer: CountDownTimer? = null
    private var finished = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityGameBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(this)
        sfx = Sfx(this)
        tts = Tts(this)
        tts.rate = db.meta("tts_rate", "1.0").toFloatOrNull() ?: 1.0f

        gameId = intent.getStringExtra("game") ?: MiniGames.BALLOON
        subject = Subject.of(intent.getStringExtra("subject") ?: "math")
        level = intent.getIntExtra("level", 2).coerceIn(1, 5)

        b.btnClose.setOnClickListener { finish() }
        b.btnQuit.setOnClickListener { finish() }
        b.btnAgain.setOnClickListener { restart() }

        start()
    }

    override fun onDestroy() {
        super.onDestroy()
        timer?.cancel()
        sfx.release()
        tts.shutdown()
    }

    // ---------------- 진행 ----------------

    private fun restart() {
        b.resultPanel.visibility = View.GONE
        start()
    }

    private fun start() {
        score = 0
        lives = LIVES
        roundsDone = 0
        finished = false
        updateHud()
        buildBoard()
        startTimer()
    }

    private fun startTimer() {
        timer?.cancel()
        timer = object : CountDownTimer(TIME_MS, 200) {
            override fun onTick(left: Long) {
                b.timeBar.progress = (left * 100 / TIME_MS).toInt()
            }
            override fun onFinish() = end(getString(R.string.game_time_up))
        }.start()
    }

    private fun updateHud() {
        b.txtScore.text = "⭐ $score"
        b.txtLives.text = "❤️".repeat(lives.coerceAtLeast(0))
    }

    private fun hit() {
        score += GameReward.SCORE_PER_HIT
        sfx.correct()
        updateHud()
        recordSkill(true)
    }

    private fun miss() {
        lives--
        sfx.wrong()
        updateHud()
        recordSkill(false)
        if (lives <= 0) end(getString(R.string.game_lost))
    }

    /** 게임도 진짜 연습이므로 실력에 반영한다 */
    private fun recordSkill(correct: Boolean) {
        val skill = if (subject == Subject.MATH) "m_calc" else "vocab"
        db.recordSkill(skill, correct)
    }

    // ---------------- 게임판 ----------------

    private var balloon: BalloonGameView? = null
    private var basket: BasketGameView? = null
    private var lineView: LineMatchView? = null

    /** 게임 속 이모지 → 낱말 일러스트 (그림 사전 1,181장 활용) */
    private val gameArtCache = HashMap<String, android.graphics.drawable.Drawable?>()
    private fun wordArtFor(s: String): android.graphics.drawable.Drawable? =
        gameArtCache.getOrPut(s) {
            val en = MiniGames.WORDS.firstOrNull { it.first == s }?.second ?: return@getOrPut null
            val name = com.piyak.english.engine.WordArt.EN[en.lowercase()] ?: return@getOrPut null
            val id = resources.getIdentifier(name, "drawable", packageName)
            if (id == 0) null else getDrawable(id)
        }

    private fun buildBoard() {
        b.gameBox.removeAllViews()
        b.btnAction.visibility = View.GONE
        balloon = null; basket = null; lineView = null

        when {
            gameId.startsWith(MiniGames.BALLOON) -> {
                val v = BalloonGameView(this)
                v.artResolver = { s -> wordArtFor(s) }
                v.riseSpeed = 0.85f + level * 0.12f
                v.onHit = { hit() }
                v.onMiss = { miss() }
                v.onSpeak = { s -> tts.speak(s) }
                v.onNextRound = { nextBalloonRound() }
                balloon = v
                b.gameBox.addView(v)
                v.startLoop()
                nextBalloonRound(first = true)
            }
            gameId.startsWith(MiniGames.BASKET) -> {
                val v = BasketGameView(this)
                v.onHit = { hit(); nextBasketRound() }
                v.onMiss = { miss() }
                v.onSpeak = { s -> tts.speakKo(s) }
                basket = v
                b.gameBox.addView(v)
                v.startLoop()
                b.btnAction.visibility = View.VISIBLE
                b.btnAction.text = getString(R.string.game_basket_done)
                b.btnAction.setOnClickListener { basket?.check() }
                nextBasketRound(first = true)
            }
            else -> {
                val v = LineMatchView(this)
                v.artResolver = { s -> wordArtFor(s) }
                v.onHit = { hit() }
                v.onMiss = { miss() }
                v.onFinish = { nextLineRound() }
                lineView = v
                b.gameBox.addView(v)
                v.startLoop()
                nextLineRound(first = true)
            }
        }
    }

    private fun countRound(): Boolean {
        roundsDone++
        if (roundsDone >= ROUNDS) { end(getString(R.string.game_all_done)); return false }
        return true
    }

    private fun nextBalloonRound(first: Boolean = false) {
        if (finished) return
        if (!first && !countRound()) return
        val r = if (subject == Subject.MATH) MiniGames.balloonMath(level)
        else MiniGames.balloonEnglish()
        b.txtQuestion.text = r.question
        balloon?.setRound(r)
    }

    private fun nextBasketRound(first: Boolean = false) {
        if (finished) return
        if (!first && !countRound()) return
        val r = MiniGames.basketRound(level)
        b.txtQuestion.text = r.question
        basket?.setRound(r)
    }

    private fun nextLineRound(first: Boolean = false) {
        if (finished) return
        // 선 잇기는 한 판에 4쌍이라 라운드를 4문제로 친다
        if (!first) { roundsDone += 3; if (!countRound()) return }
        val pairs = if (subject == Subject.MATH) MiniGames.lineMath(level)
        else MiniGames.lineEnglish()
        b.txtQuestion.text = if (subject == Subject.MATH) getString(R.string.game_match_math)
        else getString(R.string.game_match_en)
        lineView?.setPairs(pairs)
    }

    // ---------------- 끝 ----------------

    private fun end(title: String) {
        if (finished) return
        finished = true
        timer?.cancel()
        balloon?.stopLoop(); basket?.stopLoop(); lineView?.stopLoop()
        sfx.done()

        val maxScore = ROUNDS * GameReward.SCORE_PER_HIT
        val stars = GameReward.stars(score, maxScore)
        val xp = GameReward.xpFor(score)
        db.addXp(xp)
        db.markToday()

        // 용돈은 하루 몇 판까지만 (게임으로 무한히 벌 수 없게)
        var coins = 0
        val paidToday = db.bonusCountToday("game")
        if (paidToday < GameReward.DAILY_PAID_ROUNDS) {
            coins = db.earnCoins(
                GameReward.coinsFor(score, maxScore), "GAME",
                (MiniGames.byId(gameId)?.titleRes?.let { getString(it) } ?: getString(R.string.game_minigame)) + " ($score)"
            )
            if (coins > 0) db.addBonusCountToday("game")
        }

        b.txtResultTitle.text = "$title ${"⭐".repeat(stars)}"
        b.txtResultBody.text = buildString {
            append(getString(R.string.game_score, score, xp))
            if (coins > 0) append("\n" + getString(R.string.placement_coins, Wallet.format(this@GameActivity, coins)))
            else append("\n" + getString(R.string.game_no_more_coins))
        }
        b.resultPanel.visibility = View.VISIBLE
    }
}
