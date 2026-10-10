import UIKit

/// 단계(연령) 선택 후 들어오는 화면 — 그 단계의 코스들만 조용히 보여준다.
/// 기초 코스(10레벨)는 레벨이 곧 학년이라 학년 카드가 레벨 필터로 연결된다
/// (초1~2 = Lv.1 … 고급 = Lv.10 — Placement.LEVEL_NAMES 와 같은 매핑).
final class StageActivity: AppCompatActivity {

    /// 카드 한 장: 이모지, 제목, 부제, 눌렀을 때 (트랙 id, 레벨범위) 또는 특수 화면
    private struct Entry {
        var emoji: String
        var title: Int
        var sub: Int
        var color: String
        var track: String?
        var lvMin: Int
        var lvMax: Int
        var special: String?   // "alphabet" | "playground"
        /// 일러스트 이름 — 비어 있으면 이모지로 그린다
        var art: String

        init(_ emoji: String, _ title: Int, _ sub: Int, _ color: String,
             track: String? = nil, lvMin: Int = 0, lvMax: Int = 99,
             special: String? = nil, art: String = "") {
            self.emoji = emoji; self.title = title; self.sub = sub; self.color = color
            self.track = track; self.lvMin = lvMin; self.lvMax = lvMax
            self.special = special; self.art = art
        }
    }

    /// 둥실둥실 떠 있는 일러스트 (화면을 닫으면 멈춘다)
    private var heroAnim: ObjectAnimator?

    private func entriesFor(_ stage: String) -> (first: String, second: [Entry]) {
        switch stage {
        case "kinder":
            return (first: "🐣 " + getString(R.string.stage_kinder), second: [
                Entry("✏️", R.string.st_alpha, R.string.st_alpha_sub, "#FFF3D6", special: "alphabet", art: "ck_write"),
                Entry("🐣", R.string.st_first, R.string.st_first_sub, "#E8F6EA", track: "elem", art: "stage_kinder"),
                Entry("🎠", R.string.st_play, R.string.st_play_sub, "#E3F4FD", special: "playground", art: "scene_park"),
            ])
        case "elementary":
            return (first: "📗 " + getString(R.string.stage_elem), second: [
                Entry("🐣", R.string.st_elem_course, R.string.st_elem_course_sub, "#E8F6EA", track: "elem", art: "stage_elementary"),
                Entry("1️⃣", R.string.st_g12, R.string.st_g12_sub, "#FFF3D6", track: "basic", lvMin: 1, lvMax: 1, art: "scene_greeting"),
                Entry("3️⃣", R.string.st_g34, R.string.st_g34_sub, "#FFE9CF", track: "basic", lvMin: 2, lvMax: 2, art: "scene_home"),
                Entry("5️⃣", R.string.st_g56, R.string.st_g56_sub, "#FDE2E2", track: "basic", lvMin: 3, lvMax: 3, art: "word_pencil"),
            ])
        case "middle":
            return (first: "📘 " + getString(R.string.stage_middle), second: [
                Entry("🌱", R.string.st_m1, 0, "#E8F6EA", track: "basic", lvMin: 4, lvMax: 4, art: "scene_school"),
                Entry("🌿", R.string.st_m2, 0, "#DFF2E5", track: "basic", lvMin: 5, lvMax: 5, art: "word_book"),
                Entry("🍀", R.string.st_m3, 0, "#D5EEDC", track: "basic", lvMin: 6, lvMax: 6, art: "ck_think"),
                Entry("🌳", R.string.st_h1, 0, "#E3F4FD", track: "basic", lvMin: 7, lvMax: 7, art: "word_test"),
                Entry("🌲", R.string.st_h23, 0, "#DBEEFB", track: "basic", lvMin: 8, lvMax: 8, art: "word_graduate"),
                Entry("📖", R.string.st_grammar, R.string.st_grammar_sub, "#F3EDFB", track: "grammar", art: "ck_book"),
                Entry("📚", R.string.st_reading, R.string.st_reading_sub, "#EFE6FA", track: "reading", art: "scene_library"),
            ])
        case "adult":
            return (first: "✈️ " + getString(R.string.stage_adult), second: [
                Entry("💼", R.string.st_adult_mid, 0, "#FFF3D6", track: "basic", lvMin: 9, lvMax: 9, art: "scene_office"),
                Entry("🎓", R.string.st_adult_adv, 0, "#FFE9CF", track: "basic", lvMin: 10, lvMax: 10, art: "word_graduate"),
                Entry("✈️", R.string.st_travel, R.string.st_travel_sub, "#E3F4FD", track: "daily", art: "scene_travel"),
                Entry("📊", R.string.st_toeic, R.string.st_toeic_sub, "#E8F6EA", track: "toeic", art: "word_test"),
                Entry("🏛", R.string.st_toefl, R.string.st_toefl_sub, "#F3EDFB", track: "toefl", art: "scene_school"),
            ])
        default:
            return (first: "🎯 " + getString(R.string.stage_skills), second: [
                Entry("🎧", R.string.sk_listen, R.string.st_listen_sub, "#E3F4FD", track: "listening", art: "ck_listen"),
                Entry("🎤", R.string.sk_speak, R.string.st_speak_sub, "#FDE2E2", track: "speaking", art: "ck_speak"),
                Entry("✍️", R.string.sk_write, R.string.st_write_sub, "#E8F6EA", track: "writing", art: "ck_write"),
                Entry("📖", R.string.sk_grammar, R.string.st_gram_sub, "#F3EDFB", track: "grammar", art: "ck_book"),
                Entry("📚", R.string.sk_read, R.string.st_read_sub, "#FFF3D6", track: "reading", art: "scene_library"),
            ])
        }
    }

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        let stage = intent.getStringExtra("stage") ?? "skills"
        let (title, entries) = unpair(entriesFor(stage))

        let root = LinearLayout(self)
        root.orientation = LinearLayout.VERTICAL
        root.setPadding(dp(16), dp(10), dp(16), dp(24))
        root.setBackgroundColor(Color.parseColor(Db.get(self).themeColor()))

        let header = LinearLayout(self)
        header.orientation = LinearLayout.HORIZONTAL
        header.gravity = Gravity.CENTER_VERTICAL
        let back = Button(self)
        back.text = "◀"
        back.minWidth = 0; back.minimumWidth = 0
        back.background = nil
        back.textSize = 20
        back.setOnClickListener { [weak self] _ in self?.finish() }
        header.addView(back)
        let head = TextView(self)
        head.text = title
        head.textSize = 21
        head.setTypeface(head.typeface, Typeface.BOLD)
        head.setTextColor(Color.parseColor("#4E342E"))
        header.addView(head)
        root.addView(header)

        // 단계 대표 일러스트 — 화면의 얼굴
        let hero = resources.getIdentifier("stage_\(stage)", "drawable", packageName)
        if hero != 0 {
            let img = ImageView(self)
            img.setImageResource(hero)
            let lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(132))
            lp.topMargin = dp(2); lp.bottomMargin = dp(4)
            img.layoutParams = lp
            // 둥실둥실 떠 있는 느낌
            let a = ObjectAnimator.ofFloat(img, View.TRANSLATION_Y, 0, Float(dp(7)))
            a.duration = 1700
            a.repeatCount = ValueAnimator.INFINITE
            a.repeatMode = ValueAnimator.REVERSE
            a.interpolator = AccelerateDecelerateInterpolator()
            a.start()
            heroAnim = a
            root.addView(img)
        }

        let db = Db.get(self)
        let done = db.completedLessonIds()

        for e in entries {
            // 진행률: 트랙 전체 또는 학년(레벨) 범위만 센다
            var progress = ""
            var lessonTotal = -1
            if let track = e.track, let t = ContentRepo.track(self, track) {
                let units = t.units.filter { $0.level >= e.lvMin && $0.level <= e.lvMax }
                let total = units.sumOf { $0.lessons.count }
                lessonTotal = total
                let d = units.sumOf { u in u.lessons.filter { done.contains($0.id) }.count }
                if total > 0 { progress = getString(R.string.stage_progress, d, total) }
            }
            // 비한국어 폰: 걸러져서 풀 문제가 하나도 없는 트랙 카드는 숨긴다 (예: 한국어 독해)
            if !Tpl.isKorean && lessonTotal == 0 { continue }

            let card = LinearLayout(self)
            card.orientation = LinearLayout.HORIZONTAL
            card.gravity = Gravity.CENTER_VERTICAL
            card.setPadding(dp(18), dp(16), dp(16), dp(16))
            let cardBg = GradientDrawable()
            cardBg.cornerRadius = Float(dp(24))
            cardBg.setColor(Color.WHITE)
            cardBg.setStroke(dp(3), Color.parseColor(darken(e.color)))
            card.background = cardBg
            let cardLp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
            cardLp.topMargin = dp(12)
            card.layoutParams = cardLp
            card.setOnClickListener { [weak self] _ in
                guard let self else { return }
                switch e.special {
                case "alphabet":
                    self.startActivity(Intent(self, AlphabetActivity.self))
                case "playground":
                    self.startActivity(
                        Intent(self, PlaygroundActivity.self)
                            .putExtra("subject", "english")
                    )
                default:
                    self.startActivity(
                        Intent(self, TrackActivity.self)
                            .putExtra("track", e.track)
                            .putExtra("lvMin", e.lvMin)
                            .putExtra("lvMax", e.lvMax)
                            .putExtra("stageTitle", self.getString(e.title))
                    )
                }
            }
            // 동그라미 안에 일러스트 (없는 것만 이모지)
            let artId = e.art.isEmpty ? 0 : resources.getIdentifier(e.art, "drawable", packageName)
            if artId != 0 {
                let img = ImageView(self)
                img.setImageResource(artId)
                let oval = GradientDrawable()
                oval.shape = GradientDrawable.OVAL
                oval.setColor(Color.parseColor(e.color))
                img.background = oval
                let pad = dp(4)
                img.setPadding(pad, pad, pad, pad)
                img.layoutParams = LinearLayout.LayoutParams(dp(64), dp(64))
                card.addView(img)
            } else {
                let t = TextView(self)
                t.text = e.emoji
                t.textSize = 26
                t.gravity = Gravity.CENTER
                let oval = GradientDrawable()
                oval.shape = GradientDrawable.OVAL
                oval.setColor(Color.parseColor(e.color))
                t.background = oval
                t.layoutParams = LinearLayout.LayoutParams(dp(54), dp(54))
                card.addView(t)
            }
            let col = LinearLayout(self)
            col.orientation = LinearLayout.VERTICAL
            col.layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1)
            col.setPadding(dp(14), 0, 0, 0)
            let name = TextView(self)
            name.text = getString(e.title)
            name.textSize = 17
            name.setTypeface(name.typeface, Typeface.BOLD)
            name.setTextColor(Color.parseColor("#4E342E"))
            col.addView(name)
            let subLine = [e.sub != 0 ? getString(e.sub) : "", progress]
                .filter { $0.isNotEmpty() }.joined(separator: "  ·  ")
            if subLine.isNotEmpty() {
                let sub = TextView(self)
                sub.text = subLine
                sub.textSize = 13
                sub.setTextColor(Color.parseColor("#8D6E63"))
                col.addView(sub)
            }
            card.addView(col)
            let arrow = TextView(self)
            arrow.text = "▶"; arrow.textSize = 16; arrow.setTextColor(Color.parseColor("#C9A25E"))
            arrow.setPadding(dp(8), 0, 0, 0)   // 긴 번역 부제와 맞붙지 않게
            card.addView(arrow)
            root.addView(card)
        }

        let scroll = ScrollView(self)
        scroll.addView(root)
        scroll.isFillViewport = true
        setContentView(scroll)
    }

    override func onDestroy() {
        super.onDestroy()
        heroAnim?.cancel()
    }

    /// 테두리용 — 파스텔을 살짝 진하게
    private func darken(_ hex: String) -> String {
        let c = Color.parseColor(hex)
        func d(_ v: Int) -> Int { (Float(v) * 0.82).toInt().coerceAtLeast(0) }
        return "#%02X%02X%02X".format(d(Color.red(c)), d(Color.green(c)), d(Color.blue(c)))
    }

    private func dp(_ v: Int) -> Int { Int(Float(v) * resources.displayMetrics.density) }
}
