import UIKit

final class TrackActivity: AppCompatActivity {

    private var b: ActivityTrackBinding!
    private var trackId = "basic"

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        b = ActivityTrackBinding.inflate(layoutInflater)
        setContentView(b.root)
        trackId = intent.getStringExtra("track") ?? "basic"
        b.btnBack.setOnClickListener { [weak self] _ in self?.finish() }
    }

    override func onResume() {
        super.onResume()
        guard let t = ContentRepo.track(self, trackId) else { finish(); return }
        let stageTitle = intent.getStringExtra("stageTitle")
        b.txtTitle.text = stageTitle != nil ? "\(t.emoji) \(stageTitle!)" : "\(t.emoji) \(t.title)"
        build(t)
    }

    private func build(_ t: TrackData) {
        let db = Db.get(self)
        let done = db.completedLessonIds()
        let freeMode = db.meta("free_mode") == "1"
        let placed = db.metaInt("placement_level", 0)

        b.unitsBox.removeAllViews()
        var doneCount = 0
        var prevAllDone = true // 트랙 내 순차 해금 포인터

        // 학년별 진입이면 그 레벨의 유닛만 보여준다 (기초 코스 레벨 = 학년)
        let lvMin = intent.getIntExtra("lvMin", 0)
        let lvMax = intent.getIntExtra("lvMax", 99)
        for u in t.units {
            if u.level < lvMin || u.level > lvMax { continue }
            let header = TextView(self)
            header.text = "\(u.emoji)  \(u.title)"
            header.textSize = 17
            header.setTypeface(header.typeface, Typeface.BOLD)
            header.setPadding(dp(6), dp(18), 0, dp(6))
            b.unitsBox.addView(header)

            // 원의 그림자가 부모 경계에서 잘리지 않게 잘라내기를 끈다
            let flow = FlowLayout(self)
            flow.setPadding(dp(4), dp(2), dp(4), dp(10))
            flow.clipChildren = false
            flow.clipToPadding = false
            // 배치고사 결과 이하는 전체 해금 — 영어는 기초 트랙의 레벨, 수학은 학년 단위
            let mathLevel: Int? = MathGrades.of(trackId) != nil ? MathGrades.levelOf(trackId) : nil
            let unitUnlockedByPlacement: Bool
            if let mathLevel {
                unitUnlockedByPlacement = mathLevel <= db.metaInt("math_placement_level", 0)
            } else if trackId == "basic" {
                unitUnlockedByPlacement = u.level <= placed
            } else {
                unitUnlockedByPlacement = false
            }

            for l in u.lessons {
                let isDone = done.contains(l.id)
                if isDone { doneCount += 1 }
                let unlocked = freeMode || unitUnlockedByPlacement || isDone || prevAllDone
                if !isDone { prevAllDone = false }

                let node = Button(self)
                node.layoutParams = LinearLayout.LayoutParams(dp(72), dp(72))
                // 기본 최소 폭이 크면 원이 타원으로 늘어난다
                node.minWidth = 0; node.minimumWidth = 0
                node.minHeight = 0; node.minimumHeight = 0
                node.setPadding(0, 0, 0, 0)
                node.background = getDrawable(R.drawable.bg_node)
                let stars = db.lessonStars(l.id)
                if isDone {
                    node.text = String(repeating: "⭐", count: stars.coerceIn(1, 3))
                } else if unlocked {
                    node.text = ""      // 아래 foreground 의 병아리가 선다
                } else {
                    node.text = "🥚"
                }
                if !isDone && unlocked {
                    // 다음에 풀 레슨 위에 병아리가 서 있다.
                    // 위를 줄이고 아래를 늘려 살짝 띄운다 — 좌우 합과 상하 합이 같아야 안 찌그러진다.
                    node.foreground = InsetDrawable(
                        getDrawable(R.drawable.ck_idle), dp(11), dp(7), dp(11), dp(15)
                    )
                }
                node.textSize = isDone ? 11 : 22
                node.gravity = Gravity.CENTER
                let tint: Int
                if isDone { tint = Color.parseColor("#FFD54F") }
                else if unlocked { tint = Color.parseColor("#FFFFFF") }
                else { tint = Color.parseColor("#EDE7E0") }
                node.backgroundTintList = ColorStateList.valueOf(tint)
                node.alpha = unlocked ? 1 : 0.55
                let lessonId = l.id
                node.setOnClickListener { [weak self] _ in
                    guard let self else { return }
                    if !unlocked {
                        Toast.makeText(
                            self, self.getString(R.string.locked_lesson), Toast.LENGTH_SHORT
                        ).show()
                    } else {
                        self.startActivity(
                            Intent(self, LessonActivity.self)
                                .putExtra("track", self.trackId).putExtra("lesson", lessonId)
                        )
                    }
                }
                flow.addView(node)
            }
            b.unitsBox.addView(flow)
        }
        b.txtTrackProgress.text = "\(doneCount)/\(t.lessonCount)"
    }

    private func dp(_ v: Int) -> Int { Int(Float(v) * resources.displayMetrics.density) }
}
