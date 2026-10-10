import UIKit

/// A~Z 카드 목록. 대문자/소문자를 골라 연습한다.
final class AlphabetActivity: AppCompatActivity {

    private var b: ActivityAlphabetBinding!
    private var uppercase = true

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        b = ActivityAlphabetBinding.inflate(layoutInflater)
        setContentView(b.root)
        b.btnBack.setOnClickListener { [weak self] _ in self?.finish() }
        b.btnUpper.setOnClickListener { [weak self] _ in self?.uppercase = true; self?.build() }
        b.btnLower.setOnClickListener { [weak self] _ in self?.uppercase = false; self?.build() }
    }

    override func onResume() {
        super.onResume()
        build()
    }

    private func build() {
        let db = Db.get(self)
        b.btnUpper.backgroundTintList = ColorStateList.valueOf(
            Color.parseColor(uppercase ? "#FFD54F" : "#FFF0CC")
        )
        b.btnLower.backgroundTintList = ColorStateList.valueOf(
            Color.parseColor(uppercase ? "#FFF0CC" : "#FFD54F")
        )

        var doneCount = 0
        for d in Letters.ALL {
            if db.letterStars(Letters.key(d, true)) > 0 { doneCount += 1 }
            if db.letterStars(Letters.key(d, false)) > 0 { doneCount += 1 }
        }
        b.txtDone.text = "\(doneCount)/\(Letters.ALL.count * 2)"

        b.lettersGrid.removeAllViews()
        for (i, d) in Letters.ALL.enumerated() {
            let done = db.letterStars(Letters.key(d, uppercase)) > 0
            let card = LinearLayout(self)
            card.orientation = LinearLayout.VERTICAL
            card.gravity = Gravity.CENTER
            card.setPadding(0, dp(12), 0, dp(12))
            let bg = GradientDrawable()
            bg.cornerRadius = Float(dp(18))
            bg.setColor(Color.parseColor(done ? "#FFE7A8" : "#FFFFFF"))
            bg.setStroke(dp(2), Color.parseColor(done ? "#FFB300" : "#FFE082"))
            card.background = bg
            let lp = GridLayout.LayoutParams()
            lp.width = 0
            lp.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, Float(1))
            lp.setMargins(dp(5), dp(5), dp(5), dp(5))
            card.layoutParams = lp
            let upper = uppercase
            card.setOnClickListener { [weak self] _ in
                guard let self else { return }
                self.startActivity(
                    Intent(self, TraceActivity.self)
                        .putExtra("index", i)
                        .putExtra("upper", upper)
                )
            }
            let cardArt = resources.getIdentifier(
                "word_" + d.word.lowercase(), "drawable", packageName
            )
            if cardArt != 0 {
                let img = ImageView(self)
                img.setImageResource(cardArt)
                img.layoutParams = LinearLayout.LayoutParams(dp(38), dp(38))
                card.addView(img)
            } else {
                let t = TextView(self)
                t.text = d.emoji
                t.textSize = 26
                t.gravity = Gravity.CENTER
                card.addView(t)
            }
            let glyph = TextView(self)
            glyph.text = "\(d.glyph(uppercase))"
            glyph.textSize = 30
            glyph.gravity = Gravity.CENTER
            glyph.setTypeface(glyph.typeface, Typeface.BOLD)
            glyph.setTextColor(Color.parseColor("#4E342E"))
            card.addView(glyph)
            let writes = db.letterWrites(Letters.key(d, uppercase))
            let sub = TextView(self)
            sub.text = done
                ? getString(R.string.tr_times, "⭐".repeat_(db.letterStars(Letters.key(d, uppercase))), writes)
                : d.word
            sub.textSize = 11
            sub.gravity = Gravity.CENTER
            sub.setTextColor(Color.parseColor("#8D6E63"))
            card.addView(sub)
            b.lettersGrid.addView(card)
        }
    }

    private func dp(_ v: Int) -> Int { Int(Float(v) * resources.displayMetrics.density) }
}
