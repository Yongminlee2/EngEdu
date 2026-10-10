import UIKit

/// 미니게임 한 판
final class GameActivity: AppCompatActivity {

    static let ROUNDS = 10
    static let LIVES = 3
    static let TIME_MS = 90_000

    private var b: ActivityGameBinding!
    private var db: Db!
    private var sfx: Sfx!
    private var tts: Tts!

    private var gameId = MiniGames.BALLOON
    private var subject = Subject.MATH
    private var level = 2

    private var score = 0
    private var lives = GameActivity.LIVES
    private var roundsDone = 0
    private var timer: CountDownTimer?
    private var finished = false

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        b = ActivityGameBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(self)
        sfx = Sfx(self)
        tts = Tts(self)
        tts.rate = db.meta("tts_rate", "1.0").toFloatOrNull() ?? 1.0

        gameId = intent.getStringExtra("game") ?? MiniGames.BALLOON
        subject = Subject.of(intent.getStringExtra("subject") ?? "math")
        level = intent.getIntExtra("level", 2).coerceIn(1, 5)

        b.btnClose.setOnClickListener { [weak self] _ in self?.finish() }
        b.btnQuit.setOnClickListener { [weak self] _ in self?.finish() }
        b.btnAgain.setOnClickListener { [weak self] _ in self?.restart() }

        start()
    }

    override func onDestroy() {
        super.onDestroy()
        timer?.cancel()
        // 게임판의 프레임 반복도 멈춘다 (아이폰은 화면이 남아 있으면 계속 돈다)
        balloon?.stopLoop(); basket?.stopLoop(); lineView?.stopLoop()
        sfx.release()
        tts.shutdown()
    }

    // ---------------- 진행 ----------------

    private func restart() {
        b.resultPanel.visibility = View.GONE
        start()
    }

    private func start() {
        score = 0
        lives = GameActivity.LIVES
        roundsDone = 0
        finished = false
        updateHud()
        buildBoard()
        startTimer()
    }

    private func startTimer() {
        timer?.cancel()
        timer = CountDownTimer(GameActivity.TIME_MS, 200, onTick: { [weak self] left in
            self?.b.timeBar.progress = left * 100 / GameActivity.TIME_MS
        }, onFinish: { [weak self] in
            guard let self else { return }
            self.end(self.getString(R.string.game_time_up))
        }).start()
    }

    private func updateHud() {
        b.txtScore.text = "⭐ \(score)"
        b.txtLives.text = "❤️".repeat_(lives.coerceAtLeast(0))
    }

    private func hit() {
        score += GameReward.SCORE_PER_HIT
        sfx.correct()
        updateHud()
        recordSkill(true)
    }

    private func miss() {
        lives -= 1
        sfx.wrong()
        updateHud()
        recordSkill(false)
        if lives <= 0 { end(getString(R.string.game_lost)) }
    }

    /// 게임도 진짜 연습이므로 실력에 반영한다
    private func recordSkill(_ correct: Bool) {
        let skill = subject == Subject.MATH ? "m_calc" : "vocab"
        db.recordSkill(skill, correct)
    }

    // ---------------- 게임판 ----------------

    private var balloon: BalloonGameView?
    private var basket: BasketGameView?
    private var lineView: LineMatchView?

    /// 게임 속 이모지 → 낱말 일러스트
    private var gameArtCache: [String: Drawable?] = [:]
    private func wordArtFor(_ s: String) -> Drawable? {
        if let cached = gameArtCache[s] { return cached }
        var d: Drawable? = nil
        if let en = MiniGames.WORDS.firstOrNull({ $0.first == s })?.second,
           let name = WordArt.EN[en.lowercase()] {
            let id = resources.getIdentifier(name, "drawable", packageName)
            d = id == 0 ? nil : getDrawable(id)
        }
        gameArtCache[s] = .some(d)
        return d
    }

    private func buildBoard() {
        b.gameBox.removeAllViews()
        b.btnAction.visibility = View.GONE
        balloon = nil; basket = nil; lineView = nil

        if gameId.startsWith(MiniGames.BALLOON) {
            let v = BalloonGameView(self)
            v.artResolver = { [weak self] s in self?.wordArtFor(s) }
            v.riseSpeed = 0.85 + Float(level) * 0.12
            v.onHit = { [weak self] in self?.hit() }
            v.onMiss = { [weak self] in self?.miss() }
            v.onSpeak = { [weak self] s in self?.tts.speak(s) }
            v.onNextRound = { [weak self] in self?.nextBalloonRound() }
            balloon = v
            b.gameBox.addView(v)
            v.startLoop()
            nextBalloonRound(first: true)
        } else if gameId.startsWith(MiniGames.BASKET) {
            let v = BasketGameView(self)
            v.onHit = { [weak self] in self?.hit(); self?.nextBasketRound() }
            v.onMiss = { [weak self] in self?.miss() }
            v.onSpeak = { [weak self] s in self?.tts.speakKo(s) }
            basket = v
            b.gameBox.addView(v)
            v.startLoop()
            b.btnAction.visibility = View.VISIBLE
            b.btnAction.text = getString(R.string.game_basket_done)
            b.btnAction.setOnClickListener { [weak self] _ in self?.basket?.check() }
            nextBasketRound(first: true)
        } else {
            let v = LineMatchView(self)
            v.artResolver = { [weak self] s in self?.wordArtFor(s) }
            v.onHit = { [weak self] in self?.hit() }
            v.onMiss = { [weak self] in self?.miss() }
            v.onFinish = { [weak self] in self?.nextLineRound() }
            lineView = v
            b.gameBox.addView(v)
            v.startLoop()
            nextLineRound(first: true)
        }
    }

    private func countRound() -> Bool {
        roundsDone += 1
        if roundsDone >= GameActivity.ROUNDS { end(getString(R.string.game_all_done)); return false }
        return true
    }

    private func nextBalloonRound(first: Bool = false) {
        if finished { return }
        if !first && !countRound() { return }
        let r = subject == Subject.MATH ? MiniGames.balloonMath(level) : MiniGames.balloonEnglish()
        b.txtQuestion.text = questionOf(r)
        balloon?.setRound(r)
    }

    private func nextBasketRound(first: Bool = false) {
        if finished { return }
        if !first && !countRound() { return }
        let r = MiniGames.basketRound(level)
        b.txtQuestion.text = questionOf(r)
        basket?.setRound(r)
    }

    private func nextLineRound(first: Bool = false) {
        if finished { return }
        // 선 잇기는 한 판에 4쌍이라 라운드를 4문제로 친다
        if !first { roundsDone += 3; if !countRound() { return } }
        let pairs = subject == Subject.MATH ? MiniGames.lineMath(level) : MiniGames.lineEnglish()
        b.txtQuestion.text = subject == Subject.MATH
            ? getString(R.string.game_match_math)
            : getString(R.string.game_match_en)
        lineView?.setPairs(pairs.map { Pair($0.first, $0.second) })
    }

    // ---------------- 끝 ----------------

    private func end(_ title: String) {
        if finished { return }
        finished = true
        timer?.cancel()
        balloon?.stopLoop(); basket?.stopLoop(); lineView?.stopLoop()
        sfx.done()

        let maxScore = GameActivity.ROUNDS * GameReward.SCORE_PER_HIT
        let stars = GameReward.stars(score, maxScore)
        let xp = GameReward.xpFor(score)
        db.addXp(xp)
        db.markToday()

        // 용돈은 하루 몇 판까지만 (게임으로 무한히 벌 수 없게)
        var coins = 0
        let paidToday = db.bonusCountToday("game")
        if paidToday < GameReward.DAILY_PAID_ROUNDS {
            let gameName = MiniGames.byId(gameId).map { getString($0.titleRes) } ?? getString(R.string.game_minigame)
            coins = db.earnCoins(
                GameReward.coinsFor(score, maxScore), "GAME",
                gameName + " (\(score))"
            )
            if coins > 0 { db.addBonusCountToday("game") }
        }

        b.txtResultTitle.text = "\(title) \("⭐".repeat_(stars))"
        var body = getString(R.string.game_score, score, xp)
        if coins > 0 { body += "\n" + getString(R.string.placement_coins, Wallet.format(self, coins)) }
        else { body += "\n" + getString(R.string.game_no_more_coins) }
        b.txtResultBody.text = body
        b.resultPanel.visibility = View.VISIBLE
    }

    /// 게임 물음을 폰 언어로 — 뼈대가 없으면 원문(한국어)을 그대로
    private func questionOf(_ r: GameRound) -> String {
        if r.questionRes == 0 { return r.question }
        return JavaFormat.format(getString(r.questionRes), r.questionArgs)
    }
}
