import UIKit

/// 놀이터 — 미니게임 고르기
final class PlaygroundActivity: AppCompatActivity {

    private var b: ActivityPlaygroundBinding!
    private var subject = Subject.MATH
    private var level = 2

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        b = ActivityPlaygroundBinding.inflate(layoutInflater)
        setContentView(b.root)
        subject = Subject.of(intent.getStringExtra("subject") ?? "math")
        level = Db.get(self).metaInt("game_level", 2).coerceIn(1, 3)

        b.btnBack.setOnClickListener { [weak self] _ in self?.finish() }
        b.txtTitle.text = "🎮 " + getString(subject.titleRes) + " · " + getString(R.string.st_play)
        b.btnLv1.setOnClickListener { [weak self] _ in self?.setLevel(1) }
        b.btnLv2.setOnClickListener { [weak self] _ in self?.setLevel(2) }
        b.btnLv3.setOnClickListener { [weak self] _ in self?.setLevel(3) }
    }

    override func onResume() {
        super.onResume()
        let db = Db.get(self)
        let theme = Color.parseColor(db.themeColor())
        b.root.setBackgroundColor(theme)
        window.statusBarColor = theme
        setLevel(level)
    }

    private func setLevel(_ v: Int) {
        level = v
        Db.get(self).setMeta("game_level", v.toString())
        let on = Color.parseColor("#FFD54F")
        let off = Color.parseColor("#FFF0CC")
        b.btnLv1.backgroundTintList = ColorStateList.valueOf(v == 1 ? on : off)
        b.btnLv2.backgroundTintList = ColorStateList.valueOf(v == 2 ? on : off)
        b.btnLv3.backgroundTintList = ColorStateList.valueOf(v == 3 ? on : off)
        build()
    }

    private func build() {
        let db = Db.get(self)
        let paidLeft = (GameReward.DAILY_PAID_ROUNDS - db.bonusCountToday("game")).coerceAtLeast(0)

        b.gamesBox.removeAllViews()
        let left = TextView(self)
        left.text = getString(R.string.play_paid_left, paidLeft)
        left.textSize = 12
        left.setTextColor(Color.parseColor("#8D6E63"))
        left.setPadding(dp(6), 0, 0, dp(8))
        b.gamesBox.addView(left)

        for g in MiniGames.forSubject(subject) {
            let card = LinearLayout(self)
            card.orientation = LinearLayout.HORIZONTAL
            card.gravity = Gravity.CENTER_VERTICAL
            card.setPadding(dp(18), dp(20), dp(18), dp(20))
            let bg = GradientDrawable()
            bg.cornerRadius = Float(dp(22))
            bg.setColor(Color.parseColor(g.color))
            card.background = bg
            let lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
            lp.topMargin = dp(10)
            card.layoutParams = lp
            let gameId = g.id
            card.setOnClickListener { [weak self] _ in
                guard let self else { return }
                self.startActivity(
                    Intent(self, GameActivity.self)
                        .putExtra("game", gameId)
                        .putExtra("subject", self.subject.id)
                        .putExtra("level", self.level)
                )
            }
            // 게임에 어울리는 일러스트 (없으면 이모지)
            let gArt = gameArt(g.id)
            if gArt != 0 {
                let img = ImageView(self)
                img.setImageResource(gArt)
                img.layoutParams = LinearLayout.LayoutParams(dp(56), dp(56))
                card.addView(img)
            } else {
                let t = TextView(self)
                t.text = g.emoji; t.textSize = 40
                card.addView(t)
            }
            let col = LinearLayout(self)
            col.orientation = LinearLayout.VERTICAL
            col.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1)
            col.setPadding(dp(14), 0, 0, 0)
            let name = TextView(self)
            name.text = getString(g.titleRes)
            name.textSize = 20
            name.setTypeface(name.typeface, Typeface.BOLD)
            name.setTextColor(Color.parseColor("#3E2723"))
            col.addView(name)
            let desc = TextView(self)
            desc.text = getString(g.descRes)
            desc.textSize = 13
            desc.setTextColor(Color.parseColor("#5D4037"))
            col.addView(desc)
            card.addView(col)
            let arrow = TextView(self)
            arrow.text = "▶"
            arrow.textSize = 20
            arrow.setTextColor(Color.parseColor("#3E2723"))
            card.addView(arrow)
            b.gamesBox.addView(card)
        }
    }

    /// 게임 카드 일러스트: 풍선=풍선, 담기=상자, 잇기=게임기
    private func gameArt(_ id: String) -> Int {
        let name: String
        if id.startsWith(MiniGames.BALLOON) { name = "word_balloon" }
        else if id.startsWith(MiniGames.BASKET) { name = "word_box" }
        else if id.startsWith(MiniGames.LINE) { name = "word_game" }
        else { return 0 }
        return resources.getIdentifier(name, "drawable", packageName)
    }

    private func dp(_ v: Int) -> Int { Int(Float(v) * resources.displayMetrics.density) }
}
