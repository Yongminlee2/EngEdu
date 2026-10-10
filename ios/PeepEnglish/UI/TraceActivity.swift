import UIKit

/// 글자 하나를 손가락·펜으로 따라 쓰는 화면
final class TraceActivity: AppCompatActivity {

    private var b: ActivityTraceBinding!
    private var db: Db!
    private var tts: Tts!
    private var sfx: Sfx!

    private var index = 0
    private var uppercase = true

    // 처음 쓸 때 리소스에서 읽는다
    private lazy var praises: [String] = [
        getString(R.string.tr_praise_1), getString(R.string.tr_praise_2),
        getString(R.string.tr_praise_3), getString(R.string.tr_praise_4),
        getString(R.string.tr_praise_5),
    ]

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        b = ActivityTraceBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(self)
        Tpl.initialize(self)   // 낱말 뜻 번역에 필요
        sfx = Sfx(self)
        tts = Tts(self) { [weak self] ready in
            if ready { self?.b.root.postDelayed({ [weak self] in self?.sayLetter() }, 400) }
        }
        tts.rate = db.meta("tts_rate", "1.0").toFloatOrNull() ?? 1.0

        index = intent.getIntExtra("index", 0)
        uppercase = intent.getBooleanExtra("upper", true)

        b.btnClose.setOnClickListener { [weak self] _ in self?.finish() }
        b.btnSay.setOnClickListener { [weak self] _ in self?.sayLetter() }
        b.btnDemo.setOnClickListener { [weak self] _ in self?.b.traceView.playDemo() }
        b.btnAgain.setOnClickListener { [weak self] _ in
            guard let self else { return }
            self.loadLetter(self.index, self.uppercase)
        }
        b.btnNext.setOnClickListener { [weak self] _ in
            guard let self else { return }
            if self.index < Letters.ALL.count - 1 { self.loadLetter(self.index + 1, self.uppercase) }
            else { self.finish() }
        }

        // 획마다 소리를 내면 시끄럽다 — 소리는 글자를 다 썼을 때 한 번만 (onLetterComplete 의 sfx.done())
        b.traceView.onStrokeDone = { [weak self] _ in self?.updateStrokeInfo() }
        b.traceView.onStrokeFail = { [weak self] in
            guard let self else { return }
            self.b.txtHint.text = self.getString(R.string.tr_off_path)
            self.b.traceView.startAnimation(AnimationUtils.loadAnimation(self, R.anim.shake))
        }
        b.traceView.onAllDone = { [weak self] in self?.onLetterComplete() }

        loadLetter(index, uppercase)
    }

    override func onDestroy() {
        super.onDestroy()
        tts.shutdown(); sfx.release()
    }

    private func def() -> LetterDef { Letters.byIndex(index) }

    private func loadLetter(_ i: Int, _ upper: Bool) {
        index = i
        uppercase = upper
        let d = def()
        b.txtTitle.text = "\(d.glyph(true)) \(d.glyph(false))   (" +
            getString(upper ? R.string.tr_case_upper : R.string.tr_case_lower) + ")"
        // 낱말 그림이 있으면 이모지 대신
        let art = resources.getIdentifier("word_" + d.word.lowercase(), "drawable", packageName)
        if art != 0 {
            b.imgWordArt.visibility = View.VISIBLE
            b.imgWordArt.setImageResource(art)
            b.txtEmoji.visibility = View.GONE
        } else {
            b.imgWordArt.visibility = View.GONE
            b.txtEmoji.visibility = View.VISIBLE
            b.txtEmoji.text = d.emoji
        }
        b.txtWord.text = d.word
        b.txtWordKo.text = Tpl.word(d.ko)   // 뜻은 폰 언어로
        b.donePanel.visibility = View.GONE
        b.btnAgain.text = getString(R.string.ly_clear2)
        let writes = db.letterWrites(Letters.key(d, upper))
        b.txtHint.text = writes > 0
            ? getString(R.string.tr_written_n, writes)
            : getString(R.string.ly_trace_hint)
        b.traceView.setLetter(d.strokes(upper), "\(d.glyph(upper))")
        updateStrokeInfo()
        // 처음 여는 글자는 병아리가 먼저 시범을 보여준다
        b.traceView.postDelayed({ [weak self] in self?.b.traceView.playDemo() }, 600)
        sayLetter()
    }

    private func updateStrokeInfo() {
        let total = b.traceView.totalStrokes
        let done = b.traceView.doneStrokes
        b.txtStrokeInfo.text = getString(R.string.tr_stroke_of, min(done + 1, total), total)
        if done >= 1 && done < total { b.txtHint.text = getString(R.string.tr_next_stroke, done + 1) }
    }

    private func onLetterComplete() {
        sfx.done()
        let key = Letters.key(def(), uppercase)
        let writes = db.addLetterWrite(key)   // 별은 쓴 횟수에 따라 1→2→3개로 늘어난다
        let first = writes == 1
        db.recordSkill("writing", true)
        db.markToday()

        var coins = 0
        if first {
            db.addXp(Letters.XP_PER_LETTER)
            coins = db.earnCoins(Wallet.PER_LETTER, "LETTER", getString(R.string.tr_first_write, "\(def().glyph(uppercase))"))
        } else if writes <= Wallet.LETTER_REPEAT_LIMIT {
            db.addXp(2)
            coins = db.earnCoins(Wallet.PER_LETTER_REPEAT, "LETTER", getString(R.string.tr_nth_write, "\(def().glyph(uppercase))", writes))
        }

        let stars = writes >= 5 ? 3 : (writes >= 3 ? 2 : 1)
        let doneArt = resources.getIdentifier(
            "word_" + def().word.lowercase(), "drawable", packageName
        )
        if doneArt != 0 {
            b.imgDoneBig.visibility = View.VISIBLE
            b.imgDoneBig.setImageResource(doneArt)
            b.txtDoneBig.visibility = View.GONE
        } else {
            b.imgDoneBig.visibility = View.GONE
            b.txtDoneBig.visibility = View.VISIBLE
            b.txtDoneBig.text = def().emoji
        }
        b.txtDoneMsg.text = getString(R.string.tr_done_msg, praises.random(), "⭐".repeat_(stars), writes)
        b.donePanel.visibility = View.VISIBLE
        b.donePanel.alpha = 0
        b.donePanel.scaleX = 0.5; b.donePanel.scaleY = 0.5
        b.donePanel.animate().alpha(1).scaleX(1).scaleY(1).setDuration(420).start()

        if coins > 0 {
            b.txtHint.text = getString(R.string.tr_done_coins, Wallet.format(self, coins))
        } else if writes < 5 {
            b.txtHint.text = getString(R.string.tr_done_more)
        } else {
            b.txtHint.text = getString(R.string.tr_done_many, writes)
        }
        b.txtStrokeInfo.text = getString(R.string.tr_stroke_done, b.traceView.totalStrokes)
        // 반복 연습이 쉽도록 버튼을 '한 번 더 쓰기'로 바꾼다
        b.btnAgain.text = getString(R.string.tr_write_again)
        sayLetter()
    }

    private func sayLetter() {
        let d = def()
        tts.speakLines(
            [
                (first: Float(1.05), second: "\(d.glyph(uppercase))"),
                (first: Float(1.0), second: d.word),
            ]
        )
    }
}
