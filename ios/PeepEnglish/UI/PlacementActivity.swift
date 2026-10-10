import UIKit

final class PlacementActivity: AppCompatActivity {

    private var b: ActivityPlacementBinding!
    private var db: Db!
    private var tts: Tts!

    private var pool: [Int: [Question]] = [:]
    private var history: [Pair<Int, Bool>] = []
    private var curLevel = Placement.START_LEVEL
    private var count = 0
    private let TOTAL = Placement.TOTAL
    private var subject: Subject = Subject.ENGLISH
    private var maxLevel = Placement.MAX_LEVEL_ENGLISH

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        b = ActivityPlacementBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(self)
        tts = Tts(self)
        tts.rate = db.meta("tts_rate", "1.0").toFloatOrNull() ?? 1.0

        subject = Subject.of(intent.getStringExtra("subject") ?? "english")
        maxLevel = Placement.maxLevel(subject)

        let all = ContentRepo.placement(self, subject)
        if all.isEmpty { finish(); return }
        for e in all.shuffled(random: KRandom.default) {
            let (lv, q) = unpair(e)
            pool[lv, default: []].append(q)
        }

        b.btnClose.setOnClickListener { [weak self] _ in
            guard let self else { return }
            let den = self.resources.displayMetrics.density
            let box = LinearLayout(self)
            box.orientation = LinearLayout.VERTICAL
            box.gravity = Gravity.CENTER_HORIZONTAL
            box.setPadding(Int(20 * den), Int(20 * den), Int(20 * den), Int(4 * den))
            let img = ImageView(self)
            img.setImageResource(R.drawable.ck_cheerup)
            img.layoutParams = LinearLayout.LayoutParams(Int(96 * den), Int(96 * den))
            box.addView(img)
            let msg = TextView(self)
            msg.text = self.getString(R.string.placement_quit_ask)
            msg.textSize = 15
            msg.gravity = Gravity.CENTER
            msg.setTextColor(Color.parseColor("#4E342E"))
            msg.setPadding(0, Int(10 * den), 0, 0)
            box.addView(msg)
            AlertDialog.Builder(self)
                .setView(box)
                .setPositiveButton(self.getString(R.string.quit_yes)) { _, _ in self.finish() }
                .setNegativeButton(self.getString(R.string.quit_no), nil).show()
        }
        b.btnDone.setOnClickListener { [weak self] _ in self?.finish() }
        showNext()
    }

    override func onDestroy() { super.onDestroy(); tts?.shutdown() }

    private func takeQuestion(_ level: Int) -> (Int, Question)? {
        // 해당 레벨에 문제가 없으면 가까운 레벨에서 가져온다
        for d in 0...maxLevel {
            for lv in [level - d, level + d] {
                if lv >= 1 && lv <= maxLevel {
                    if var list = pool[lv], !list.isEmpty {
                        let q = list.removeLast()
                        pool[lv] = list
                        return (lv, q)
                    }
                }
            }
        }
        return nil
    }

    private func showNext() {
        if count >= TOTAL { showResult(); return }
        guard let taken = takeQuestion(curLevel) else { showResult(); return }
        let (lv, q) = taken
        count += 1
        b.txtCount.text = "\(count) / \(TOTAL)"
        b.progressBar.progress = count * 100 / TOTAL
        b.choicesBox.removeAllViews()
        b.btnPlay.visibility = View.GONE
        tts.stop()

        let quad: Quad
        if let m = q as? Question.Mcq {
            quad = Quad(a: m.prompt, b: m.choices, c: m.answer, d: nil)
        } else if let m = q as? Question.ListenMcq {
            quad = Quad(a: m.prompt, b: m.choices, c: m.answer, d: m.tts)
        } else {
            showNext(); return
        }
        let (prompt, choices, answer, ttsText) = (quad.a, quad.b, quad.c, quad.d)
        b.txtPrompt.text = prompt
        if let ttsText {
            b.btnPlay.visibility = View.VISIBLE
            b.btnPlay.setOnClickListener { [weak self] _ in self?.tts.speak(ttsText) }
            b.root.postDelayed({ [weak self] in self?.tts.speak(ttsText) }, 300)
        }

        for (i, c) in choices.enumerated() {
            let btn = Button(self)
            btn.text = c; btn.textSize = 16; btn.isAllCaps = false
            btn.setTextColor(Color.parseColor("#4E342E"))
            btn.backgroundTintList = ColorStateList.valueOf(Color.WHITE)
            let lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
            lp.topMargin = dp(8)
            btn.layoutParams = lp
            btn.setOnClickListener { [weak self, weak btn] _ in
                guard let self, let btn else { return }
                let correct = i == answer
                self.history.append(Pair(lv, correct))
                self.curLevel = Placement.nextLevel(lv, correct, self.maxLevel)
                btn.backgroundTintList = ColorStateList.valueOf(
                    Color.parseColor(correct ? "#C8E6C9" : "#FFCDD2")
                )
                self.b.choicesBox.postDelayed({ [weak self] in self?.showNext() }, 350)
                // 더블탭 방지
                for j in 0..<self.b.choicesBox.childCount { self.b.choicesBox.getChildAt(j)?.isEnabled = false }
            }
            b.choicesBox.addView(btn)
        }
    }

    private func showResult() {
        let placed = Placement.placeLevel(history.map { (first: $0.first, second: $0.second) })
        let doneKey = Placement.doneKey(subject)
        let firstTime = db.meta(doneKey) != "1"
        db.setMeta(Placement.levelKey(subject), String(placed))
        db.setMeta(doneKey, "1")
        db.addXp(30)
        db.markToday()
        var coinLine = ""
        if firstTime {
            let c = db.earnCoins(
                Wallet.PLACEMENT_BONUS, "PLACEMENT",
                getString(R.string.placement_done, getString(subject.titleRes))
            )
            coinLine = "\n" + getString(R.string.placement_coins, Wallet.format(self, c))
        }
        b.resultPanel.visibility = View.VISIBLE
        let name = Placement.levelName(self, subject, placed)
        if subject == Subject.MATH {
            b.txtResultTitle.text = name
            b.txtResultDesc.text =
                getString(R.string.placement_msg_math, name) + coinLine
        } else {
            b.txtResultTitle.text = getString(R.string.placement_level, placed)
            b.txtResultDesc.text =
                getString(R.string.placement_msg_en, name, placed) + coinLine
        }
    }

    private func dp(_ v: Int) -> Int { Int(Float(v) * resources.displayMetrics.density) }
}

private struct Quad {
    let a: String
    let b: [String]
    let c: Int
    let d: String?
}
