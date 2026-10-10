import UIKit

// 문제 풀이 화면 (LessonActivity.kt 를 옮김).
// Question 은 클래스 상속(Question.Mcq …)이라 `is X` 는 `as? X` 로 옮겼다.
// 화면에 걸어 두는 클로저는 [weak self] — 아이폰은 화면·클로저가 서로 붙잡으면 풀리지 않는다.

final class LessonActivity: AppCompatActivity {

    private var b: ActivityLessonBinding!
    private var db: Db!
    private var tts: Tts!
    private var stt: Stt!
    private var sfx: Sfx!

    private var session: LessonSession? = nil
    private var reviewMode = false
    private var trackId = ""

    // ---- 연출 상태 ----
    /** 연속 정답 수 (오답이면 조용히 리셋) */
    private var combo = 0

    /** 그림을 한 줄에 모아 담는 컨테이너를 찾기 위한 표식 */
    private let ART_ROW_TAG = "artRow"

    /** "3 / 12" — 문제 뷰가 만들어질 때 종류 라벨 옆에 채운다 */
    private var questionNo = ""

    /** 첫 문제는 전환 애니메이션 없이 바로 */
    private var firstQuestion = true

    /** 15초 동안 손을 안 대면 병아리가 응원한다 */
    private lazy var encourageRun = Runnable { [weak self] in
        guard let self else { return }
        if self.b.chickView.visibility == View.VISIBLE { self.b.chickView.encourage() }
    }

    /** 45초까지 조용하면 병아리가 잠든다 — 톡 치면 삐약! 하고 일어난다 */
    private lazy var sleepRun = Runnable { [weak self] in
        guard let self else { return }
        if self.b.chickView.visibility == View.VISIBLE { self.b.chickView.sleep() }
    }
    private var lessonId = ""
    private var lessonTitle = ""

    // 현재 문제의 답 상태
    private var checkAction: (() -> Void)? = nil
    private var speakFails = 0

    /** 실력 집계는 문제당 첫 시도만 반영 */
    private var skillRecorded = Set<String>()

    /** 힌트권(오답 2개 지우기)을 쓸 수 있는 현재 문제의 선택지 */
    private var choiceButtons: [Button] = []
    private var choiceAnswer = -1
    private var hintUsedHere = false

    /** 레슨 시작 시점의 영역별 레벨·칭호 (결과 화면에서 상승분을 보여주려고 기억) */
    private var startSkillLevels: [String: Int] = [:]
    private var startRank: Rank? = nil

    private func recordSkill(_ q: Question, _ correct: Bool) {
        if skillRecorded.insert(q.id).inserted { db.recordSkill(q.skill, correct) }
    }

    // 처음 쓸 때 리소스에서 읽는다
    private lazy var okLines: [String] = [
        getString(R.string.praise_correct), getString(R.string.praise_perfect),
        getString(R.string.praise_genius), getString(R.string.praise_nice), getString(R.string.praise_great),
    ]
    private lazy var noLines: [String] = [
        getString(R.string.cheer_close), getString(R.string.cheer_again),
        getString(R.string.cheer_next), getString(R.string.cheer_more),
    ]

    /** 정답 공개 후 피드백 패널에 보여줄 낱말 그림 — 문제에서 미리 보여주면 답이 새는 유형용 */
    private var feedbackArtRes = 0

    override func onCreate(_ savedInstanceState: SavedState?) {
        super.onCreate(savedInstanceState)
        b = ActivityLessonBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(self)
        sfx = Sfx(self)
        tts = Tts(self)
        tts.rate = db.meta("tts_rate", "1.0").toFloatOrNull() ?? 1.0
        stt = Stt(self)
        // 문제 화면 위 상주 병아리는 뺐다 — 리액션은 정답 패널의 병아리·색종이가 대신한다
        b.chickView.visibility = View.GONE

        reviewMode = intent.getStringExtra("mode") == "review"
        let questions: [Question]
        if reviewMode {
            let wrongs = db.wrongList(12)
            questions = wrongs.compactMap { w in
                let (qid, lid, tid) = w
                return ContentRepo.findQuestion(self, tid, lid, qid)
            }
            lessonTitle = getString(R.string.review_mode)
            if questions.isEmpty {
                Toast.makeText(self, getString(R.string.lesson_no_review), Toast.LENGTH_SHORT).show()
                finish(); return
            }
        } else {
            trackId = intent.getStringExtra("track") ?? ""
            lessonId = intent.getStringExtra("lesson") ?? ""
            let t = ContentRepo.track(self, trackId)
            guard let pair = t?.findLesson(lessonId) else { finish(); return }
            lessonTitle = pair.second.title
            questions = pair.second.questions
            if db.heartsEnabled() && db.hearts() <= 0 {
                AlertDialog.Builder(self)
                    .setTitle(getString(R.string.heart_empty_title))
                    .setMessage(getString(R.string.heart_empty_msg))
                    .setPositiveButton(getString(R.string.confirm)) { [weak self] _, _ in self?.finish() }
                    .setCancelable(false).show()
                return
            }
        }

        session = LessonSession(
            questions,
            hearts: (reviewMode || !db.heartsEnabled()) ? 99 : db.hearts(),
            useHearts: !reviewMode && db.heartsEnabled()
        )

        do {
            let states = db.skillStates()
            var levels: [String: Int] = [:]
            for st in states { levels[st.def.id] = st.level }
            startSkillLevels = levels
            startRank = Ranks.of(Skills.overallLevel(states))
        }

        b.btnClose.setOnClickListener { [weak self] _ in self?.confirmQuit() }
        b.btnHint.setOnClickListener { [weak self] _ in self?.useHint() }
        b.btnContinue.setOnClickListener { [weak self] _ in self?.hideFeedback(); self?.showQuestion() }
        b.btnCheck.setOnClickListener { [weak self] _ in self?.checkAction?() }
        bouncy(b.btnCheck)
        bouncy(b.btnContinue)
        b.btnDone.setOnClickListener { [weak self] _ in self?.finish() }

        // 병아리는 전 트랙 상주 — 토익·토플도 귀엽게

        registerBackHandler()
        showQuestion()
    }

    override func onDestroy() {
        super.onDestroy()
        tts.shutdown(); stt.stop(); sfx.release()
        b.root.removeCallbacks(encourageRun)
        b.root.removeCallbacks(sleepRun)
    }

    /** 뒤로가기 — 콜백을 등록하는 방식 */
    private func registerBackHandler() {
        onBackPressedDispatcher.addCallback(self, OnBackPressedCallback(true) { [weak self] _ in
            self?.confirmQuit()
        })
    }

    private func confirmQuit() {
        AlertDialog.Builder(self)
            .setView(cuteDialogView(getString(R.string.quit_ask)))
            .setPositiveButton(getString(R.string.quit_yes)) { [weak self] _, _ in self?.finish() }
            .setNegativeButton(getString(R.string.quit_no), nil).show()
    }

    /** 응원 병아리가 있는 확인 대화상자 내용 (이모지 대신 진짜 일러스트) */
    private func cuteDialogView(_ msg: String) -> View {
        let box = LinearLayout(self)
        box.orientation = LinearLayout.VERTICAL
        box.gravity = Gravity.CENTER_HORIZONTAL
        box.setPadding(dp(20), dp(20), dp(20), dp(4))

        let img = ImageView(self)
        img.setImageResource(R.drawable.ck_cheerup)
        img.layoutParams = LinearLayout.LayoutParams(dp(96), dp(96))
        box.addView(img)

        let tv = TextView(self)
        tv.text = msg
        tv.textSize = 15
        tv.gravity = Gravity.CENTER
        tv.setTextColor(Color.parseColor("#4E342E"))
        tv.setPadding(0, dp(10), 0, 0)
        box.addView(tv)
        return box
    }


    // ---------------- 문제 표시 ----------------

    private func showQuestion() {
        guard let s = session else { return }
        if s.isFinished { showResult(); return }
        guard let q = s.current() else { showResult(); return }

        if firstQuestion {
            firstQuestion = false
            renderQuestion(q)
        } else {
            // 이전 문제가 왼쪽으로 미끄러져 나가고 새 문제가 오른쪽에서 들어온다
            let slide = Float(b.questionBox.width) * 0.22
            b.questionBox.animate().translationX(-slide).alpha(0).setDuration(90)
                .withEndAction { [weak self] in
                    guard let self else { return }
                    self.renderQuestion(q)
                    self.b.questionBox.translationX = slide
                    self.b.questionBox.animate().translationX(0).alpha(1).setDuration(110).start()
                }.start()
        }
    }

    private func renderQuestion(_ q: Question) {
        #if DEBUG
        defer { debugShotHook(q) }
        #endif
        guard let s = session else { return }
        // 응원 타이머 재시작
        b.root.removeCallbacks(encourageRun)
        b.root.removeCallbacks(sleepRun)
        b.root.postDelayed(encourageRun, 15_000)
        b.root.postDelayed(sleepRun, 45_000)

        b.progressBar.progress = (s.progress * 100).toInt()
        questionNo = "\((s.solvedCount + 1).coerceAtMost(s.totalCount)) / \(s.totalCount)"
        showHearts(reviewMode ? nil : (db.heartsEnabled() ? s.hearts : -1))
        b.questionBox.removeAllViews()
        b.btnCheck.isEnabled = false
        b.btnCheck.text = getString(R.string.lesson_check)
        b.btnCheck.visibility = View.VISIBLE
        checkAction = nil
        speakFails = 0
        choiceButtons = []
        choiceAnswer = -1
        hintUsedHere = false
        feedbackArtRes = 0
        tts.stop()

        if let m = q as? Question.Mcq { showMcq(m) }
        else if let m = q as? Question.ListenMcq { showListenMcq(m) }
        else if let m = q as? Question.ListenDialog { showListenDialog(m) }
        else if let m = q as? Question.Dictation { showDictation(m) }
        else if let m = q as? Question.TypeTranslate { showTypeTranslate(m) }
        else if let m = q as? Question.Order { showOrder(m) }
        else if let m = q as? Question.Match { showMatch(m) }
        else if let m = q as? Question.Speak { showSpeak(m) }
        // Question.Math: 영어 전용 앱 — 수학 팩이 없어 도달하지 않는다

        // 선택지가 만들어진 뒤에 힌트 버튼 상태를 갱신한다
        refreshHintButton()
    }

    // ---------------- 힌트권 ----------------

    private func refreshHintButton() {
        let n = db.itemCount("hint")
        b.btnHint.text = "\(n)"
        b.btnHint.isEnabled = true
        b.btnHint.alpha = (n > 0 && choiceButtons.count >= 4 && !hintUsedHere) ? 1 : 0.5
    }

    /** 오답 2개를 지워 준다 (4지선다에서만) */
    private func useHint() {
        // 아무 반응 없이 무시하면 왜 안 되는지 알 수 없다 — 이유를 알려 준다
        if hintUsedHere {
            Toast.makeText(self, getString(R.string.hint_already), Toast.LENGTH_SHORT).show()
            return
        }
        if choiceButtons.count < 4 || choiceAnswer < 0 {
            Toast.makeText(self, getString(R.string.hint_choice_only), Toast.LENGTH_SHORT).show()
            return
        }
        if db.itemCount("hint") <= 0 {
            Toast.makeText(self, getString(R.string.hint_none), Toast.LENGTH_SHORT).show()
            return
        }
        if !db.useItem("hint") { return }
        hintUsedHere = true
        let wrongIdx = Array(choiceButtons.indices).filter { $0 != choiceAnswer }
            .shuffled(random: KRandom.default).take(2)
        for i in wrongIdx {
            let btn = choiceButtons[i]
            btn.isEnabled = false
            btn.alpha = 0.3
            btn.paintFlags = btn.paintFlags | Paint.STRIKE_THRU_TEXT_FLAG
        }
        sfx.piyak()
        refreshHintButton()
    }

    private func artRes(_ name: String?) -> Int {
        guard let name else { return 0 }
        return resources.getIdentifier(name, "drawable", packageName)
    }

    /** 문장·낱말에서 그림 사전에 있는 첫 단어의 일러스트 (없으면 0) */
    private func sentenceArt(_ en: String?, _ ko: String? = nil) -> Int {
        if let en {
            for w in lessonSplitNonAlpha(en.lowercase()) {
                if let it = WordArt.EN[w] { return artRes(it) }
            }
        }
        if let ko {
            // 코틀린 mapOf 는 넣은 순서(가나다순)로 돈다 — 같은 순서로
            for (kw, res) in LessonActivity.koArtOrdered {
                if ko.contains(kw) { return artRes(res) }
            }
        }
        return 0
    }

    /** WordArt.KO 를 코틀린과 같은 순서(UTF-16 정렬)로 */
    private static let koArtOrdered: [(key: String, value: String)] =
        WordArt.KO.sorted { $0.key.utf16.lexicographicallyPrecedes($1.key.utf16) }


    /**
     * 문장·지문의 낱말로 상황 장면 그림을 고른다.
     * 낱말 그림이 없는 문법·회화·대화 문제에 "그 상황의 그림"을 붙이는 용도.
     */
    private func sceneArt(_ texts: String?...) -> Int {
        let t = texts.compactMap { $0 }.joined(separator: " ").lowercase()
        if t.isBlank() { return 0 }
        let table: [(String, [String])] = [
            ("greeting", ["hello", "hi ", "nice to meet", "good morning", "인사", "안녕"]),
            ("restaurant", ["restaurant", "menu", "order", "waiter", "식당", "주문", "메뉴"]),
            ("airport", ["airport", "flight", "passport", "boarding", "공항", "비행"]),
            ("travel", ["travel", "trip", "tour", "hotel", "여행", "호텔"]),
            ("shopping", ["shop", "buy", "price", "store", "쇼핑", "가격", "사다"]),
            ("school", ["school", "class", "teacher", "student", "homework", "학교", "수업", "선생님"]),
            ("hospital", ["hospital", "doctor", "sick", "medicine", "병원", "의사", "아프"]),
            ("phone", ["phone", "call", "message", "전화", "통화"]),
            ("weather", ["weather", "rain", "sunny", "snow", "cloud", "날씨", "비가", "눈이"]),
            ("family", ["family", "mother", "father", "sister", "brother", "가족", "엄마", "아빠"]),
            ("home", ["home", "house", "room", "kitchen", "집에", "방에"]),
            ("office", ["office", "work", "meeting", "boss", "회사", "회의", "직장"]),
            ("market", ["market", "fruit", "vegetable", "시장", "과일"]),
            ("sports", ["sport", "soccer", "baseball", "play ball", "운동", "축구", "야구"]),
            ("birthday", ["birthday", "cake", "party", "present", "생일", "파티", "선물"]),
            ("camping", ["camp", "tent", "campfire", "캠핑", "텐트"]),
            ("library", ["library", "book", "read", "도서관", "책을"]),
            ("bus", ["bus", "subway", "train", "station", "버스", "지하철", "기차"]),
            ("park", ["park", "walk", "bench", "공원", "산책"]),
            ("beach", ["beach", "sea", "swim", "바다", "해변", "수영"]),
        ]
        for (name, keys) in table {
            if keys.contains(where: { t.contains($0) }) {
                let id = artRes("scene_\(name)")
                if id != 0 { return id }
            }
        }
        return 0
    }

    /**
     * 문제 위쪽에 일러스트를 끼워 넣는다 — 글만 덜렁 있는 화면을 없애는 핵심.
     * 그림이 두 장 이상이면 한 줄에 나란히 놓고 폭에 맞춰 같이 줄인다.
     */
    private func addArt(_ v: View, _ resId: Int, _ sizeDp: Int = 165) {
        if resId == 0 { return }
        guard let root = v as? LinearLayout else { return }
        let row: LinearLayout
        if let found = root.findViewWithTag(ART_ROW_TAG) as? LinearLayout {
            row = found
        } else {
            row = LinearLayout(self)
            row.tagAny = ART_ROW_TAG
            row.orientation = LinearLayout.HORIZONTAL
            row.gravity = Gravity.CENTER
            let lp = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
            lp.topMargin = dp(6); lp.bottomMargin = dp(4)
            row.layoutParams = lp
            root.addView(row, min(1, root.childCount))
        }
        let img = ImageView(self)
        img.tagAny = sizeDp                     // 원래 요청 크기 — 다시 계산할 때 쓴다
        img.layoutParams = LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp))
        // 두 번째 프레임이 있는 포즈는 저절로 움직인다 (듣기 병아리 고개 까딱 등)
        PoseAnim.applyTo(img, resId)
        row.addView(img)
        fitArtRow(row)
        // 뿅 하고 등장
        img.scaleX = 0.7; img.scaleY = 0.7; img.alpha = 0
        img.animate().scaleX(1).scaleY(1).alpha(1)
            .setDuration(260).setInterpolator(OvershootInterpolator(1.6)).start()
    }

    /** 그림 줄이 화면 밖으로 나가지 않게 비율을 지키며 같이 줄인다 */
    private func fitArtRow(_ row: LinearLayout) {
        let n = row.childCount
        if n == 0 { return }
        let gap = dp(10)
        let avail = resources.displayMetrics.widthPixels - dp(32) - gap * (n - 1)
        var want = 0
        for i in 0..<n { want += dp((row.getChildAt(i)?.tagAny as? Int) ?? 150) }
        let scale: Float = want > avail ? Float(avail) / Float(want) : 1
        for i in 0..<n {
            guard let child = row.getChildAt(i) else { continue }
            let size = (Float(dp((child.tagAny as? Int) ?? 150)) * scale).toInt()
            let lp = LinearLayout.LayoutParams(size, size)
            if i > 0 { lp.marginStart = gap }
            child.layoutParams = lp
        }
    }

    private func inflate(_ layout: Int) -> View {
        let v = LayoutInflater.from(self).inflate(layout, b.questionBox, false)
        // 위쪽에 붙이되, 내용이 짧으면 조금만 내려 준다
        (v.layoutParams as? FrameLayout.LayoutParams)?.gravity = Gravity.TOP
        (v.findViewById(R.id.txtCountInline) as TextView?)?.text = questionNo
        // 안드로이드는 입력칸이 포커스를 채가지 않게 문제 뷰가 포커스를 가져갔다 —
        // 아이폰 입력칸은 스스로 포커스를 잡지 않아 할 일이 없다
        v.isFocusableInTouchMode = true
        b.questionBox.addView(v)
        b.questionScroll.post { [weak self] in self?.b.questionScroll.scrollTo(0, 0) }
        v.addOnLayoutChangeListener { [weak self] view, _, _, _, _, _, _, _, _ in
            guard let self else { return }
            let free = self.b.questionBox.height - view.height
            view.translationY = (Float(free) / 2).coerceIn(0, Float(self.dp(10)))
        }
        return v
    }

    /** 보기마다 다른 파스텔 — 아이 눈에 "글 목록"이 아니라 "알록달록 카드"로 보이게 */
    private let choiceTints = ["#FFF3D6", "#E3F4FD", "#E8F6EA", "#F3EDFB"]

    /** 누르는 맛 — 눌리면 살짝 줄었다가 튕겨 돌아온다 */
    private func bouncy(_ v: View) {
        v.setOnTouchListener { view, e in
            switch e.actionMasked {
            case MotionEvent.ACTION_DOWN:
                view.animate().scaleX(0.95).scaleY(0.95).setDuration(60).start()
            case MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL:
                view.animate().scaleX(1).scaleY(1).setDuration(140)
                    .setInterpolator(OvershootInterpolator(2)).start()
            default: break
            }
            return false
        }
    }

    /**
     * 문제 지문에 나오는 낱말을 놀이터 낱말사전에서 찾아 삽화 이모지로.
     * 정답 힌트가 되지 않도록 보기는 보지 않는다.
     */
    private func findWordArt(_ prompt: String, _ choices: [String]) -> String? {
        let p = prompt.lowercase()
        for w in MiniGames.WORDS {
            let (emoji, en, ko) = (w.first, w.second, w.third)
            // 코틀린 원본의 "\b" 는 문자열 안이라 백스페이스 글자다(단어 경계가 아님) — 같은 동작으로 둔다
            if p.contains("\u{8}\(en)\u{8}") || prompt.contains(ko) { return emoji }
        }
        return nil
    }

    private func choiceButton(_ text: String, _ index: Int = 0) -> Button {
        let btn = Button(self)
        btn.text = text
        btn.textSize = 17
        btn.isAllCaps = false
        btn.setTextColor(Color.parseColor("#4E342E"))
        let base = Color.parseColor(choiceTints[index % choiceTints.count])
        btn.tagAny = base
        btn.backgroundTintList = ColorStateList.valueOf(base)
        bouncy(btn)
        let lp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        )
        lp.topMargin = dp(8)
        btn.layoutParams = lp
        return btn
    }

    /** 공용 4지선다 렌더링 */
    private func renderChoices(
        _ box: LinearLayout, _ choices: [String], _ answer: Int,
        _ explain: String?, _ answerText: String
    ) {
        // 보기가 짧으면 둥둥 떠다니는 버블로 (만지는 재미), 길면 읽기 편한 버튼 목록으로
        if BubbleChoiceView.fits(choices) {
            renderBubbleChoices(box, choices, answer, explain, answerText)
            return
        }
        var selected = -1
        var buttons: [Button] = []
        for (i, c) in choices.enumerated() {
            let btn = choiceButton(c, i)
            btn.setOnClickListener { [weak self] btn in
                guard let self else { return }
                selected = i
                // 다 만든 뒤의 목록을 본다 (코틀린 ArrayList 와 같게)
                for it in buttons {
                    if it.isEnabled {
                        it.backgroundTintList = ColorStateList.valueOf((it.tagAny as? Int) ?? Color.WHITE)
                    }
                }
                btn.backgroundTintList = ColorStateList.valueOf(Color.parseColor("#FFD54F"))
                self.b.btnCheck.isEnabled = true
            }
            buttons.append(btn)
            box.addView(btn)
        }
        choiceButtons = buttons
        choiceAnswer = answer
        checkAction = { [weak self] in
            guard let self else { return }
            let ok = selected == answer
            self.submitAnswer(ok, ok ? nil : self.getString(R.string.fb_answer, answerText), explain)
        }
    }

    /**
     * 보기를 그림 2×2 로 보여준다.
     * 그림으로 물으면 어느 나라 아이도 그대로 풀 수 있다. 채점은 그대로 answer(인덱스)로 한다.
     */
    private func renderArtChoices(
        _ box: LinearLayout, _ choices: [String], _ choiceArt: [String],
        _ answer: Int, _ explain: String?, _ answerText: String
    ) {
        let grid = GridLayout(self)
        grid.columnCount = 2
        grid.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        )
        var selected = -1
        var cards: [View] = []
        for i in choices.indices {
            let card = LinearLayout(self)
            card.orientation = LinearLayout.VERTICAL
            card.gravity = Gravity.CENTER
            card.setPadding(dp(6), dp(8), dp(6), dp(8))
            card.background = getDrawable(R.drawable.bg_tile)
            let lp = GridLayout.LayoutParams()
            lp.width = 0
            lp.height = dp(132)
            lp.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, Float(1))
            lp.setMargins(dp(5), dp(5), dp(5), dp(5))
            card.layoutParams = lp

            let res = artRes(choiceArt.getOrNull(i))
            if res != 0 {
                let img = ImageView(self)
                img.setImageResource(res)
                img.layoutParams = LinearLayout.LayoutParams(dp(96), dp(96))
                card.addView(img)
            } else {
                // 그림이 없으면 글자로라도 보여 준다 (빈 칸은 절대 만들지 않는다)
                let tv = TextView(self)
                tv.text = choices[i]
                tv.textSize = 17
                tv.gravity = Gravity.CENTER
                tv.setTextColor(Color.parseColor("#4E342E"))
                card.addView(tv)
            }
            card.setOnClickListener { [weak self] _ in
                guard let self else { return }
                selected = i
                self.sfx.piyak()
                for (j, c) in cards.enumerated() {
                    let on = j == i
                    c.alpha = on ? 1 : 0.4
                    c.scaleX = on ? 1.04 : 1
                    c.scaleY = on ? 1.04 : 1
                }
                self.b.btnCheck.isEnabled = true
            }
            cards.append(card)
            grid.addView(card)
        }
        box.addView(grid)
        checkAction = { [weak self] in
            guard let self else { return }
            let ok = selected == answer
            self.submitAnswer(ok, ok ? nil : self.getString(R.string.fb_answer, answerText), explain)
        }
    }

    /** 짧은 보기: 버블로 띄운다. 시간 압박은 없고 움직임과 터치감만 더한다. */
    private func renderBubbleChoices(
        _ box: LinearLayout, _ choices: [String], _ answer: Int,
        _ explain: String?, _ answerText: String
    ) {
        let view = BubbleChoiceView(self)
        view.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(230)
        )
        var selected = -1
        view.onPick = { [weak self] it in
            selected = it
            self?.sfx.piyak()
            self?.b.btnCheck.isEnabled = true
        }
        view.setChoices(choices)
        box.addView(view)
        checkAction = { [weak self, weak view] in
            guard let self, let view else { return }
            let ok = selected == answer
            view.reveal(answer)
            view.lock()
            self.submitAnswer(ok, ok ? nil : self.getString(R.string.fb_answer, answerText), explain)
        }
    }

    private func showMcq(_ q: Question.Mcq) {
        let v = inflate(R.layout.view_q_mcq)
        let txtKind: TextView = v.findViewById(R.id.txtKind)!
        if q.passage != nil { txtKind.text = getString(R.string.kind_reading) }
        else if q.bigEmoji != nil { txtKind.text = getString(R.string.kind_pic) }
        else { txtKind.text = getString(R.string.kind_choose) }
        // 그림 우선 원칙: 그림이 답을 알려줘도 좋다 (그림-소리-뜻이 같이 붙는 것이 곧 학습)
        let koWord = lessonFirstGroup("\"([가-힣]+)", q.prompt)
        let koArt = koWord.flatMap { k in WordArt.KO[k].map { artRes($0) } } ?? 0
        let enWord = lessonFirstGroup("\"([A-Za-z]+)", q.prompt)?.lowercase()
        let enArt = enWord.map { resources.getIdentifier("word_\($0)", "drawable", packageName) } ?? 0
        let quotedArt = koArt != 0 ? koArt : enArt
        if q.passage != nil {
            // 독해는 지문·보기가 길다. 그림은 책 병아리 하나만 작게 (아래에서 붙인다)
        } else if q.bigArt != nil && !Tpl.isKorean && artRes(q.bigArt) != 0 {
            // 한국어를 못 읽는 폰에서는 문제가 지정한 그림이 곧 문제문이 된다
            addArt(v, artRes(q.bigArt), 175)
        } else if quotedArt != 0 {
            addArt(v, quotedArt, 175)
        } else if let bigEmoji = q.bigEmoji {
            // 이모지가 붙어 온 문제도 낱말 그림이 있으면 그걸 먼저 쓴다
            let emojiArt = sentenceArt(q.prompt)
            if emojiArt != 0 { addArt(v, emojiArt, 165) }
            else {
                let tv: TextView = v.findViewById(R.id.txtBigEmoji)!
                tv.visibility = View.VISIBLE
                tv.text = bigEmoji
            }
        } else {
            // 낱말 그림 → 상황 장면 그림 → 이모지 순으로 무조건 뭐라도 붙인다
            let hint = sentenceArt(q.prompt)
            let scene = hint == 0 ? sceneArt(q.prompt, q.passage) : 0
            if hint != 0 { addArt(v, hint, 150) }
            else if scene != 0 { addArt(v, scene, 150) }
            else {
                let emoji = findWordArt(q.prompt, q.choices)
                if let emoji {
                    let tv: TextView = v.findViewById(R.id.txtBigEmoji)!
                    tv.visibility = View.VISIBLE
                    tv.text = emoji
                } else if q.passage == nil {
                    // 아무것도 못 찾으면 생각하는 병아리 — 그림 없는 문제 0% 보장
                    addArt(v, artRes("ck_think"), 120)
                }
            }
        }
        if let passage = q.passage {
            addArt(v, artRes("ck_book"), 84)
            let tv: TextView = v.findViewById(R.id.txtPassage)!
            tv.visibility = View.VISIBLE
            tv.text = passage
            // 지문이 길면 지문 상자 안에서 굴려 읽는다
            tv.movementMethod = ScrollingMovementMethod()
            tv.setOnTouchListener { view, e in
                view.parent?.requestDisallowInterceptTouchEvent(true)
                if e.actionMasked == MotionEvent.ACTION_UP {
                    view.parent?.requestDisallowInterceptTouchEvent(false)
                }
                return false
            }
        }
        // 그림이 붙은 문제는 한국어를 못 읽는 폰에서 그림 자체를 문제로 쓴다
        let txtPrompt: TextView = v.findViewById(R.id.txtPrompt)!
        txtPrompt.text = (q.bigArt != nil && !Tpl.isKorean && artRes(q.bigArt) != 0)
            ? getString(R.string.ask_pic_en)
            : q.prompt
        // 한국어를 못 읽는 폰에서만 같은 문제를 그림 보기로 바꿔 준다 (정답 자리는 같다)
        let choicesBox: LinearLayout = v.findViewById(R.id.choicesBox)!
        if !q.choiceArt.isEmpty && !Tpl.isKorean {
            renderArtChoices(choicesBox, q.choices, q.choiceArt, q.answer, q.explain, q.choices[q.answer])
        } else {
            renderChoices(choicesBox, q.choices, q.answer, q.explain, q.choices[q.answer])
        }
    }

    private func showListenMcq(_ q: Question.ListenMcq) {
        let v = inflate(R.layout.view_q_mcq)
        // 그림 우선: 들려준 낱말의 그림을 바로 보여준다 (그림-소리 연결도 학습)
        let heardArt = lessonNonZero(sentenceArt(q.tts))
            ?? lessonNonZero(sceneArt(q.tts, q.prompt))
            ?? artRes("ck_listen")
        addArt(v, heardArt, 160)
        (v.findViewById(R.id.txtKind) as TextView?)?.text = getString(R.string.kind_listen)
        (v.findViewById(R.id.txtPrompt) as TextView?)?.text = q.prompt
        let play: Button = v.findViewById(R.id.btnPlay)!
        let slow: Button = v.findViewById(R.id.btnPlaySlow)!
        play.visibility = View.VISIBLE; slow.visibility = View.VISIBLE
        play.setOnClickListener { [weak self] _ in self?.tts.speak(q.tts) }
        slow.setOnClickListener { [weak self] _ in self?.tts.speak(q.tts, slow: true) }
        renderChoices(v.findViewById(R.id.choicesBox)!, q.choices, q.answer, q.explain,
                      getString(R.string.heard_was, q.choices[q.answer], q.tts))
        addSkip(v)
        b.root.postDelayed({ [weak self] in self?.tts.speak(q.tts) }, 350)
    }

    private func showListenDialog(_ q: Question.ListenDialog) {
        let v = inflate(R.layout.view_q_mcq)
        let spoken = q.lines.map { $0.second }.joined(separator: " ")
        let dlgArt = q.lines.lazy.map { self.sentenceArt($0.second) }.first { $0 != 0 }
            ?? lessonNonZero(sceneArt(spoken, q.prompt))
            ?? artRes("ck_listen")
        addArt(v, dlgArt, 150)
        (v.findViewById(R.id.txtKind) as TextView?)?.text = getString(R.string.kind_dialog)
        (v.findViewById(R.id.txtPrompt) as TextView?)?.text = q.prompt
        let play: Button = v.findViewById(R.id.btnPlay)!
        play.visibility = View.VISIBLE
        let lines: [(first: Float, second: String)] = q.lines.map { l in
            (first: l.first == "A" ? Float(0.9) : Float(1.2), second: l.second)
        }
        play.setOnClickListener { [weak self] _ in self?.tts.speakLines(lines) }
        let script = q.lines.map { "\($0.first): \($0.second)" }.joined(separator: "\n")
        renderChoices(v.findViewById(R.id.choicesBox)!, q.choices, q.answer, q.explain,
                      getString(R.string.dialog_script, q.choices[q.answer], script))
        addSkip(v)
        b.root.postDelayed({ [weak self] in self?.tts.speakLines(lines) }, 350)
    }

    private func showDictation(_ q: Question.Dictation) {
        let v = inflate(R.layout.view_q_type)
        let dictArt = lessonNonZero(sentenceArt(q.answer))
            ?? lessonNonZero(sceneArt(q.answer, q.hintKo))
            ?? artRes("ck_write")
        addArt(v, dictArt)
        (v.findViewById(R.id.txtKind) as TextView?)?.text = getString(R.string.kind_dictation)
        (v.findViewById(R.id.txtPrompt) as TextView?)?.text = getString(R.string.dictation_prompt)
        // 한국어 힌트는 한국 폰에서만 — 다른 언어 폰에서는 위의 그림이 힌트를 대신한다
        if let hintKo = q.hintKo, Tpl.isKorean {
            let tv: TextView = v.findViewById(R.id.txtHint)!
            tv.visibility = View.VISIBLE; tv.text = getString(R.string.hint_prefix, hintKo)
        }
        let play: Button = v.findViewById(R.id.btnPlay)!
        let slow: Button = v.findViewById(R.id.btnPlaySlow)!
        play.visibility = View.VISIBLE; slow.visibility = View.VISIBLE
        play.setOnClickListener { [weak self] _ in self?.tts.speak(q.tts) }
        slow.setOnClickListener { [weak self] _ in self?.tts.speak(q.tts, slow: true) }
        let edit: EditText = v.findViewById(R.id.editAnswer)!
        edit.addTextChangedListener(SimpleWatcher { [weak self] s in self?.b.btnCheck.isEnabled = s.isNotBlank() })
        checkAction = { [weak self, weak edit] in
            guard let self, let edit else { return }
            let r = Grader.grade(edit.text, q.answer, q.alts)
            let extra = r.typo ? self.getString(R.string.typo_ok, q.answer) : nil
            self.submitAnswer(r.correct, r.correct ? extra : self.getString(R.string.fb_answer, q.answer), q.explain)
        }
        addSkip(v)
        b.root.postDelayed({ [weak self] in self?.tts.speak(q.tts) }, 350)
    }

    private func showTypeTranslate(_ q: Question.TypeTranslate) {
        let v = inflate(R.layout.view_q_type)
        let typeArt = lessonNonZero(sentenceArt(q.answer, q.ko))
            ?? lessonNonZero(sceneArt(q.answer, q.ko))
            ?? artRes("ck_write")
        addArt(v, typeArt)
        (v.findViewById(R.id.txtKind) as TextView?)?.text = getString(R.string.kind_compose)
        // 한국어를 못 읽는 폰에서는 영어 문장을 들려 주고 받아 적게 한다
        let txtPrompt: TextView = v.findViewById(R.id.txtPrompt)!
        if Tpl.isKorean {
            txtPrompt.text = q.ko
        } else {
            txtPrompt.text = getString(R.string.listen_type)
            let play: Button = v.findViewById(R.id.btnPlay)!
            play.visibility = View.VISIBLE
            play.text = getString(R.string.play_again)
            play.setOnClickListener { [weak self] _ in self?.tts.speak(q.answer) }
            b.root.postDelayed({ [weak self] in self?.tts.speak(q.answer) }, 350)
        }
        let edit: EditText = v.findViewById(R.id.editAnswer)!
        edit.addTextChangedListener(SimpleWatcher { [weak self] s in self?.b.btnCheck.isEnabled = s.isNotBlank() })
        checkAction = { [weak self, weak edit] in
            guard let self, let edit else { return }
            let r = Grader.grade(edit.text, q.answer, q.alts)
            let extra = r.typo ? self.getString(R.string.typo_ok, q.answer) : nil
            self.submitAnswer(r.correct, r.correct ? extra : self.getString(R.string.fb_answer, q.answer), q.explain)
        }
    }

    private func showOrder(_ q: Question.Order) {
        let v = inflate(R.layout.view_q_order)
        let orderArt = lessonNonZero(sentenceArt(q.en, q.ko))
            ?? lessonNonZero(sceneArt(q.en, q.ko))
            ?? artRes("ck_book")
        addArt(v, orderArt, 150)
        // 한국어를 못 읽는 폰에서는 영어 문장을 들려 주고 순서를 맞추게 한다. 문구를 누르면 다시 들려 준다.
        let orderPrompt: TextView = v.findViewById(R.id.txtPrompt)!
        if Tpl.isKorean {
            orderPrompt.text = q.ko
        } else {
            orderPrompt.text = getString(R.string.listen_arrange)
            orderPrompt.setOnClickListener { [weak self] _ in self?.tts.speak(q.en) }
            b.root.postDelayed({ [weak self] in self?.tts.speak(q.en) }, 350)
        }
        let answerFlow: FlowLayout = v.findViewById(R.id.answerFlow)!
        let bankFlow: FlowLayout = v.findViewById(R.id.bankFlow)!

        var selected: [String] = []
        let tiles = (q.tokens + q.extras).shuffled(random: KRandom.default)

        func tileButton(_ word: String) -> Button {
            let t = Button(self)
            t.text = word; t.textSize = 18; t.isAllCaps = false
            t.setTextColor(Color.parseColor("#4E342E"))
            t.background = getDrawable(R.drawable.bg_tile)
            t.backgroundTintList = nil
            t.minWidth = 0; t.minimumWidth = 0
            t.setPadding(dp(18), dp(13), dp(18), dp(13))
            return t
        }

        for word in tiles {
            let tile = tileButton(word)
            // 눌린 타일은 인자로 받는다 (타일·줄을 클로저가 붙잡지 않게)
            tile.setOnClickListener { [weak self, weak bankFlow, weak answerFlow] tile in
                guard let self, let bankFlow, let answerFlow else { return }
                if tile.parent === bankFlow {
                    bankFlow.removeView(tile); answerFlow.addView(tile)
                    selected.append(word)
                } else {
                    answerFlow.removeView(tile); bankFlow.addView(tile)
                    _ = selected.remove(word)
                }
                self.b.btnCheck.isEnabled = !selected.isEmpty   // refreshCheck
            }
            bankFlow.addView(tile)
        }
        checkAction = { [weak self] in
            guard let self else { return }
            let ok = Grader.gradeOrder(selected, q.tokens)
            self.submitAnswer(ok, ok ? nil : self.getString(R.string.fb_answer, q.en), q.explain)
        }
    }

    /**
     * 짝 맞추기 — 탭-탭 대신 손가락으로 선을 그어 잇는다.
     * 놀이터의 선 잇기와 같은 조작이다.
     */
    private func showMatch(_ q: Question.Match) {
        b.btnCheck.visibility = View.INVISIBLE

        let hint = TextView(self)
        hint.text = getString(R.string.match_hint)
        hint.textSize = 15
        hint.setTextColor(Color.parseColor("#8D6E63"))
        hint.setPadding(dp(4), 0, 0, dp(6))
        let view = LineMatchView(self)
        view.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(400)
        )
        let wrap = LinearLayout(self)
        wrap.orientation = LinearLayout.VERTICAL
        wrap.addView(hint)
        wrap.addView(view)
        b.questionBox.addView(wrap)

        var mistakes = 0
        view.onHit = { [weak self] in self?.sfx.piyak() }
        view.onMiss = { [weak self] in mistakes += 1; self?.sfx.wrong() }
        view.onFinish = { [weak self] in
            guard let self else { return }
            let ok = mistakes == 0
            self.recordSkill(q, ok)
            self.session?.submitNoPenalty(ok)
            self.showFeedback(
                ok,
                ok ? nil : self.getString(R.string.match_mistakes, mistakes),
                q.explain, penalty: false
            )
        }
        view.setPairs(q.pairs.map { Pair($0.first, $0.second) })
        view.startLoop()
    }

    private func showSpeak(_ q: Question.Speak) {
        let v = inflate(R.layout.view_q_speak)
        let speakArt = lessonNonZero(sentenceArt(q.en, q.ko))
            ?? lessonNonZero(sceneArt(q.en, q.ko))
            ?? artRes("ck_speak")
        addArt(v, speakArt, 150)
        (v.findViewById(R.id.txtEn) as TextView?)?.text = q.en
        // 한국어 해석은 한국 폰에서만 — 읽을 문장(영어)은 어차피 위에 있다
        (v.findViewById(R.id.txtKo) as TextView?)?.text = Tpl.isKorean ? (q.ko ?? "") : ""
        let txtHeard: TextView = v.findViewById(R.id.txtHeard)!
        let btnMic: Button = v.findViewById(R.id.btnMic)!
        let btnSkip: Button = v.findViewById(R.id.btnCantSpeak)!
        b.btnCheck.visibility = View.GONE

        (v.findViewById(R.id.btnListen) as Button?)?.setOnClickListener { [weak self] _ in self?.tts.speak(q.en) }

        btnMic.setOnClickListener { [weak self, weak txtHeard, weak btnMic, weak btnSkip] _ in
            guard let self, let txtHeard, let btnMic, let btnSkip else { return }
            if ActivityCompat.checkSelfPermission(self, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED {
                ActivityCompat.requestPermissions(self, [Manifest.permission.RECORD_AUDIO], 77)
                return
            }
            self.tts.stop()
            txtHeard.text = self.getString(R.string.speak_listening)
            btnMic.isEnabled = false
            self.stt.start(
                onResult: { [weak self] heard in
                    self?.runOnUiThread {
                        guard let self else { return }
                        btnMic.isEnabled = true
                        let score = Grader.speakScore(heard, q.en)
                        txtHeard.text = self.getString(R.string.speak_heard, heard, score)
                        if Grader.gradeSpeak(heard, q.en) {
                            self.submitAnswer(true, self.getString(R.string.speak_success, score), q.explain)
                        } else {
                            self.speakFails += 1
                            self.sfx.wrong()
                            // 건너뛰기는 처음부터 보인다 (못 할 수도 있으니까)
                            Toast.makeText(self, self.getString(R.string.speak_retry), Toast.LENGTH_SHORT).show()
                        }
                    }
                },
                onError: { [weak self] code in
                    self?.runOnUiThread {
                        guard let self else { return }
                        btnMic.isEnabled = true
                        self.speakFails += 1
                        if self.speakFails >= 2 { btnSkip.visibility = View.VISIBLE }
                        switch code {
                        case SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT:
                            txtHeard.text = self.getString(R.string.speak_not_heard)
                        case -1:
                            txtHeard.text = self.getString(R.string.speak_unavailable)
                        default:
                            txtHeard.text = self.getString(R.string.speak_error, code)
                        }
                    }
                }
            )
        }
        btnSkip.setOnClickListener { [weak self] _ in
            guard let self else { return }
            self.recordSkill(q, false)
            self.session?.submitNoPenalty(false)
            self.showFeedback(false, self.getString(R.string.speak_giveup, q.en), q.explain, penalty: false)
        }
    }


    /**
     * 못 풀 수도 있는 문제(듣기·받아쓰기)에 붙이는 건너뛰기.
     * 하트를 깎지 않고 정답을 알려 준 뒤 다음 문제로 넘어간다.
     */
    private func addSkip(_ v: View) {
        guard let root = v as? LinearLayout else { return }
        let btn = Button(self)
        btn.text = getString(R.string.skip_btn)
        btn.isAllCaps = false
        btn.textSize = 14
        btn.setTextColor(Color.parseColor("#8D6E63"))
        btn.background = nil
        let lp = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        )
        lp.topMargin = dp(4)
        btn.layoutParams = lp
        btn.setOnClickListener { [weak self] _ in
            guard let self else { return }
            guard let q = self.session?.current() else { return }
            let note: String?
            if let m = q as? Question.ListenMcq {
                note = self.getString(R.string.heard_was, m.choices[m.answer], m.tts)
            } else if let m = q as? Question.ListenDialog {
                note = self.getString(R.string.fb_answer, m.choices[m.answer])
            } else if let m = q as? Question.Dictation {
                note = self.getString(R.string.fb_answer, m.answer)
            } else {
                note = nil
            }
            self.recordSkill(q, false)
            self.session?.submitNoPenalty(false)
            self.showFeedback(false, note, q.explain, penalty: false)
        }
        root.addView(btn)
    }

    // ---------------- 채점·피드백 ----------------

    /** 일반 제출 (하트·재출제 규칙 적용) */
    private func submitAnswer(_ correct: Bool, _ note: String?, _ explain: String?) {
        guard let s = session else { return }
        guard let q = s.current() else { return }
        recordSkill(q, correct)
        if reviewMode {
            let cleared = db.reviewOutcome(q.id, correct)
            _ = s.submit(correct)
            let msg: String?
            if correct && cleared { msg = getString(R.string.review_cleared) }
            else if correct { msg = getString(R.string.review_one_more) }
            else { msg = note }
            showFeedback(correct, msg, explain, penalty: false)
        } else {
            if !correct && !(q is Question.Match) { db.recordWrong(q, lessonId, trackId) }
            _ = s.submit(correct)
            showFeedback(correct, note, explain, penalty: true)
        }
    }

    private func showFeedback(_ correct: Bool, _ note: String?, _ explain: String?, penalty: Bool) {
        if correct { sfx.correct() } else if penalty { sfx.wrong() }
        // 병아리 리액션 + 콤보 (답을 냈으니 응원 타이머는 멈춘다)
        b.root.removeCallbacks(encourageRun)
        if correct {
            combo += 1
            b.celebrate.correct(combo)
            if b.chickView.visibility == View.VISIBLE { b.chickView.cheer() }
        } else {
            combo = 0
            if penalty && b.chickView.visibility == View.VISIBLE { b.chickView.oops() }
        }
        // GONE 으로 없애면 그만큼 자리가 남아 문제가 아래로 밀린다 — 자리는 남겨 둔다
        b.btnCheck.visibility = View.INVISIBLE
        b.feedbackPanel.visibility = View.VISIBLE
        b.feedbackPanel.background = getDrawable(
            correct ? R.drawable.bg_feedback_ok : R.drawable.bg_feedback_no
        )
        // 정답 공개 후에는 낱말 그림으로 한 번 더 각인 (없으면 병아리)
        let fbArt = feedbackArtRes
        PoseAnim.applyTo(
            b.imgFeedback,
            fbArt != 0 ? fbArt : (correct ? R.drawable.ck_cheer : R.drawable.ck_sad)   // 날갯짓하며 축하
        )
        let fbSize = dp(fbArt != 0 ? 84 : 56)
        if let lp = b.imgFeedback.layoutParams {
            lp.width = fbSize; lp.height = fbSize
            b.imgFeedback.layoutParams = lp
        }
        b.txtFeedback.text = correct ? okLines.random() : noLines.random()
        // 패널이 아래에서 통통 올라오고, 그림이 뿅 하고 커진다
        b.feedbackPanel.translationY = Float(dp(48))
        b.feedbackPanel.alpha = 0
        b.feedbackPanel.animate().translationY(0).alpha(1)
            .setDuration(240).setInterpolator(OvershootInterpolator(1.1)).start()
        b.imgFeedback.scaleX = 0.4; b.imgFeedback.scaleY = 0.4
        b.imgFeedback.animate().scaleX(1).scaleY(1)
            .setDuration(340).setInterpolator(OvershootInterpolator(2.2)).start()
        let detail = [note, explain].compactMap { $0 }.joined(separator: "\n\n")
        if !detail.isEmpty {
            b.txtExplain.visibility = View.VISIBLE
            b.txtExplain.text = detail
            // 긴 해설은 패널 안에서 스크롤
            b.txtExplain.movementMethod = ScrollingMovementMethod()
            b.txtExplain.scrollTo(0, 0)
        } else { b.txtExplain.visibility = View.GONE }
        b.btnContinue.backgroundTintList = ColorStateList.valueOf(
            Color.parseColor(correct ? "#66BB6A" : "#FF5252")
        )
        showHearts(reviewMode ? nil : (db.heartsEnabled() ? (session?.hearts ?? 0) : -1))
    }


    /**
     * 상단 하트 표시. n 이 nil 이면 복습 모드, -1 이면 하트 기능 끔.
     * 아이콘도 코드에서 같이 끈다.
     */
    private func showHearts(_ n: Int?) {
        let icon = (n != nil && n! >= 0) ? R.drawable.ic_heart : 0
        b.txtHearts.setCompoundDrawablesRelativeWithIntrinsicBounds(icon, 0, 0, 0)
        if let n {
            b.txtHearts.text = n < 0 ? "" : "\(n)"
        } else {
            b.txtHearts.text = getString(R.string.lesson_review_mode)
        }
    }

    private func hideFeedback() {
        b.feedbackPanel.visibility = View.GONE
        b.btnCheck.visibility = View.VISIBLE
    }

    // ---------------- 결과 ----------------

    private func showResult() {
        guard let s = session else { return }
        tts.stop()
        b.resultPanel.visibility = View.VISIBLE

        if s.failed {
            b.imgResult.setImageResource(R.drawable.ck_cheerup)
            b.txtResultTitle.text = getString(R.string.result_no_heart_title)
            b.txtResultStats.text = getString(R.string.result_no_heart_msg)
            db.setHearts(0)
            return
        }

        sfx.done()
        PoseAnim.applyTo(b.imgResult, s.isPerfect ? R.drawable.ck_cheer : R.drawable.ck_clap)
        b.celebrate.finale()
        let xp = s.xpEarned()
        var coins = 0
        if reviewMode {
            let h = (db.hearts() + 1).coerceAtMost(db.maxHearts())
            db.setHearts(h)
            db.addXp(xp)
            db.markToday()
            // 복습 보너스는 하루 한도까지만 (파밍 방지)
            if db.bonusCountToday("review") < Wallet.REVIEW_DAILY_LIMIT {
                coins = db.earnCoins(Wallet.REVIEW_BONUS, "REVIEW", getString(R.string.review_done))
                db.addBonusCountToday("review")
            }
            b.txtResultTitle.text = getString(R.string.result_review_title)
            b.txtResultStats.text = getString(R.string.result_review_stats, (s.accuracy * 100).toInt(), xp, h)
        } else {
            if db.heartsEnabled() { db.setHearts(s.hearts) }
            db.addXp(xp)
            // 코인은 이 레슨을 "처음" 깰 때만 — 다시 풀어도 0원이라 반복 파밍이 안 된다
            let firstClear = db.lessonStars(lessonId) == 0
            db.completeLesson(lessonId, trackId, s.stars(), s.accuracy)
            if s.isPerfect { db.setMeta("perfect_count", String(db.metaInt("perfect_count") + 1)) }
            if firstClear {
                coins = db.earnCoins(
                    Wallet.lessonReward(s.firstTryCorrect, s.isPerfect), "LESSON",
                    getString(R.string.result_lesson_sub, lessonTitle, s.firstTryCorrect)
                )
            }
            b.txtResultTitle.text = s.isPerfect ? getString(R.string.result_perfect_title) : getString(R.string.result_lesson_title)
            b.txtResultStats.text =
                "\(lessonTitle)\n\("⭐".repeat_(s.stars()))\n" +
                getString(R.string.result_stats, (s.accuracy * 100).toInt(), xp) +
                (s.isPerfect ? getString(R.string.result_perfect_bonus) : "")
        }
        // TextView.append → text 에 이어 붙이기
        if coins > 0 {
            b.txtResultStats.text += "\n\n" + getString(R.string.result_coins, Wallet.format(self, coins), Wallet.format(self, db.coins()))
        } else if !reviewMode {
            b.txtResultStats.text += "\n\n" + getString(R.string.result_no_coins)
        }
        b.txtResultStats.text += growthReport()
        checkBadges()
    }

    /** 결과 화면 하단: 영역 레벨업·칭호 승급·오늘의 목표 달성 알림 */
    private func growthReport() -> String {
        let states = db.skillStates()
        var sb = ""

        for st in states {
            let before = startSkillLevels[st.def.id] ?? 0
            if st.level > before {
                sb += "\n\n" + getString(R.string.result_skill_up, st.def.emoji, getString(st.def.titleRes), st.level)
            }
        }
        let overall = Skills.overallLevel(states)
        let rank = Ranks.of(overall)
        if let start = startRank, rank.titleRes != start.titleRes {
            sb += "\n\n" + getString(R.string.result_rank_up, rank.emoji, getString(rank.titleRes))
        }
        let goal = db.dailyGoal()
        let todayXp = db.xpToday()
        sb += "\n\n" + getString(R.string.result_goal, todayXp, goal)
        if DailyGoal.isDone(todayXp, goal) {
            sb += getString(R.string.result_goal_done)
            // 목표 달성은 하루 한 번만 집계 + 용돈 보너스
            if db.metaLong("goal_met_day", -1) != Db.today() {
                db.setMeta("goal_met_day", String(Db.today()))
                db.setMeta("goals_met", String(db.metaInt("goals_met") + 1))
                let bonus = db.earnCoins(Wallet.DAILY_GOAL_BONUS, "GOAL", getString(R.string.goal_reached))
                if bonus > 0 { sb += "\n" + getString(R.string.result_goal_bonus, Wallet.format(self, bonus)) }
            }
        }
        return sb
    }

    private func checkBadges() {
        let days = db.studyDays()
        let best = Economy.streak(days, Db.today()).second
        var unitMap: [String: Int] = [:]
        if !trackId.isEmpty {
            if let t = ContentRepo.track(self, trackId) {
                let done = db.completedLessonIds()
                unitMap[trackId] = t.units.filter { u in
                    !u.lessons.isEmpty && u.lessons.allSatisfy { done.contains($0.id) }
                }.count
            }
        }
        // 배지 판정에는 두 과목의 영역을 모두 넘긴다
        var skillLevels: [String: Int] = [:]
        for st in db.skillStates(Skills.ALL + Skills.MATH) { skillLevels[st.def.id] = st.level }
        let snap = StatsSnapshot(
            lessonsDone: db.lessonsDoneCount(),
            perfectCount: db.metaInt("perfect_count"),
            xp: db.xp(),
            streakBest: best,
            placementDone: db.meta("placement_done") == "1",
            reviewCleared: db.metaInt("review_cleared"),
            unitsCompleted: unitMap,
            skillLevels: skillLevels,
            goalsMet: db.metaInt("goals_met")
        )
        let newly = Badges.check(snap, db.earnedBadges())
        for bd in newly {
            db.earnBadge(bd.id)
            Toast.makeText(self, getString(R.string.badge_earned, bd.emoji, getString(bd.titleRes)), Toast.LENGTH_LONG).show()
        }
    }

    private func dp(_ v: Int) -> Int { Int(Float(v) * resources.displayMetrics.density) }
}

/** EditText 간단 워처 */
private struct SimpleWatcher: TextWatcher {
    let onChange: (String) -> Void
    init(_ onChange: @escaping (String) -> Void) { self.onChange = onChange }
    func afterTextChanged(_ s: String) { onChange(s) }
}

// MARK: - 이 파일 도우미

/// 코틀린 `takeIf { it != 0 }`
private func lessonNonZero(_ v: Int) -> Int? { v != 0 ? v : nil }

/// 코틀린 `split(Regex("[^a-z]+"))` — a~z 가 아닌 글자 덩어리로 자른다 (빈 조각도 남긴다)
private func lessonSplitNonAlpha(_ s: String) -> [String] {
    var out: [String] = []
    var cur = ""
    var inSep = false
    for u in s.unicodeScalars {
        if u.value >= 0x61 && u.value <= 0x7A {
            cur.unicodeScalars.append(u); inSep = false
        } else if !inSep {
            out.append(cur); cur = ""; inSep = true
        }
    }
    out.append(cur)
    return out
}

/// 코틀린 `Regex(p).find(s)?.groupValues?.get(1)`
private func lessonFirstGroup(_ pattern: String, _ s: String) -> String? {
    guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
    let ns = s as NSString
    guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
          m.numberOfRanges > 1 else { return nil }
    let r = m.range(at: 1)
    return r.location == NSNotFound ? nil : ns.substring(with: r)
}

#if DEBUG
extension LessonActivity {
    /// 스토어 스크린샷용 (DEBUG 빌드만): -answer 1 이면 정답 화면을 띄운다
    static var debugShotDone = false
    func debugShotHook(_ q: Question) {
        guard !LessonActivity.debugShotDone else { return }
        LessonActivity.debugShotDone = true
        if DebugLaunch.args["answer"] == "1" {
            b.root.postDelayed({ [weak self] in self?.submitAnswer(true, nil, q.explain) }, 700)
        }
    }
}
#endif
