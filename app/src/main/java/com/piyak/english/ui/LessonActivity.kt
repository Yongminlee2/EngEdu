package com.piyak.english.ui

import android.Manifest
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.graphics.Color
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import com.piyak.english.R
import com.piyak.english.audio.Sfx
import com.piyak.english.audio.Stt
import com.piyak.english.audio.Tts
import com.piyak.english.databinding.ActivityLessonBinding
import com.piyak.english.db.Db
import com.piyak.english.engine.Badges
import com.piyak.english.engine.Economy
import com.piyak.english.engine.Grader
import com.piyak.english.engine.LessonSession
import com.piyak.english.engine.StatsSnapshot
import com.piyak.english.engine.Wallet
import com.piyak.english.model.ContentRepo
import com.piyak.english.model.Question

class LessonActivity : AppCompatActivity() {

    private lateinit var b: ActivityLessonBinding
    private lateinit var db: Db
    private lateinit var tts: Tts
    private lateinit var stt: Stt
    private lateinit var sfx: Sfx

    private var session: LessonSession? = null
    private var reviewMode = false
    private var trackId = ""

    // ---- 연출 상태 ----
    /** 연속 정답 수 (오답이면 조용히 리셋) */
    private var combo = 0

    /** 그림을 한 줄에 모아 담는 컨테이너를 찾기 위한 표식 */
    private val ART_ROW_TAG = "artRow"

    /** "3 / 12" — 문제 뷰가 만들어질 때 종류 라벨 옆에 채운다 */
    private var questionNo = ""

    /** 첫 문제는 전환 애니메이션 없이 바로 */
    private var firstQuestion = true

    /** 15초 동안 손을 안 대면 병아리가 응원한다 */
    private val encourageRun = Runnable {
        if (b.chickView.visibility == View.VISIBLE) b.chickView.encourage()
    }

    /** 45초까지 조용하면 병아리가 잠든다 — 톡 치면 삐약! 하고 일어난다 */
    private val sleepRun = Runnable {
        if (b.chickView.visibility == View.VISIBLE) b.chickView.sleep()
    }
    private var lessonId = ""
    private var lessonTitle = ""

    // 현재 문제의 답 상태
    private var checkAction: (() -> Unit)? = null
    private var speakFails = 0

    /** 실력 집계는 문제당 첫 시도만 반영 */
    private val skillRecorded = HashSet<String>()

    /** 힌트권(오답 2개 지우기)을 쓸 수 있는 현재 문제의 선택지 */
    private var choiceButtons: List<Button> = emptyList()
    private var choiceAnswer = -1
    private var hintUsedHere = false

    /** 저학년 수학은 문제를 자동으로 읽어 준다 */
    /**
     * 수학 문제를 열자마자 읽어 주지 않는다.
     * 읽어 주는 소리가 갑자기 나오면 방해가 되므로 🔊 버튼을 누를 때만 재생한다.
     */

    /** 레슨 시작 시점의 영역별 레벨·칭호 (결과 화면에서 상승분을 보여주려고 기억) */
    private var startSkillLevels: Map<String, Int> = emptyMap()
    private var startRank: com.piyak.english.engine.Rank? = null

    private fun recordSkill(q: Question, correct: Boolean) {
        if (skillRecorded.add(q.id)) db.recordSkill(q.skill, correct)
    }

    // 필드 초기화 시점에는 Context 가 아직 없다 — 처음 쓸 때 리소스에서 읽는다
    private val okLines by lazy {
        listOf(getString(R.string.praise_correct), getString(R.string.praise_perfect),
            getString(R.string.praise_genius), getString(R.string.praise_nice), getString(R.string.praise_great))
    }
    private val noLines by lazy {
        listOf(getString(R.string.cheer_close), getString(R.string.cheer_again),
            getString(R.string.cheer_next), getString(R.string.cheer_more))
    }

    /** 정답 공개 후 피드백 패널에 보여줄 낱말 그림 — 문제에서 미리 보여주면 답이 새는 유형용 */
    private var feedbackArtRes = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityLessonBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(this)
        sfx = Sfx(this)
        tts = Tts(this)
        tts.rate = db.meta("tts_rate", "1.0").toFloatOrNull() ?: 1.0f
        stt = Stt(this)
        // 문제 화면 위 상주 병아리는 뺐다 — 무슨 역할인지 알기 어렵고 그림과 겹친다.
        // 리액션은 정답 패널의 병아리·색종이가 대신한다 (사용자 결정 2026-08-03)
        b.chickView.visibility = View.GONE

        reviewMode = intent.getStringExtra("mode") == "review"
        val questions: List<Question>
        if (reviewMode) {
            val wrongs = db.wrongList(12)
            questions = wrongs.mapNotNull { (qid, lid, tid) -> ContentRepo.findQuestion(this, tid, lid, qid) }
            lessonTitle = getString(R.string.review_mode)
            if (questions.isEmpty()) {
                Toast.makeText(this, getString(R.string.lesson_no_review), Toast.LENGTH_SHORT).show()
                finish(); return
            }
        } else {
            trackId = intent.getStringExtra("track") ?: ""
            lessonId = intent.getStringExtra("lesson") ?: ""
            val t = ContentRepo.track(this, trackId)
            val pair = t?.findLesson(lessonId)
            if (pair == null) { finish(); return }
            lessonTitle = pair.second.title
            questions = pair.second.questions
            if (db.heartsEnabled() && db.hearts() <= 0) {
                AlertDialog.Builder(this)
                    .setTitle(getString(R.string.heart_empty_title))
                    .setMessage(getString(R.string.heart_empty_msg))
                    .setPositiveButton(getString(R.string.confirm)) { _, _ -> finish() }
                    .setCancelable(false).show()
                return
            }
        }

        session = LessonSession(
            questions,
            hearts = if (reviewMode || !db.heartsEnabled()) 99 else db.hearts(),
            useHearts = !reviewMode && db.heartsEnabled(),
        )

        db.skillStates().let { states ->
            startSkillLevels = states.associate { it.def.id to it.level }
            startRank = com.piyak.english.engine.Ranks.of(com.piyak.english.engine.Skills.overallLevel(states))
        }

        b.btnClose.setOnClickListener { confirmQuit() }
        b.btnHint.setOnClickListener { useHint() }
        b.btnContinue.setOnClickListener { hideFeedback(); showQuestion() }
        b.btnCheck.setOnClickListener { checkAction?.invoke() }
        bouncy(b.btnCheck)
        bouncy(b.btnContinue)
        b.btnDone.setOnClickListener { finish() }

        // 병아리는 전 트랙 상주 — 토익·토플도 귀엽게 (사용자 결정: 전부 귀염뽀짝)

        registerBackHandler()
        showQuestion()
    }

    override fun onDestroy() {
        super.onDestroy()
        tts.shutdown(); stt.stop(); sfx.release()
        b.root.removeCallbacks(encourageRun)
        b.root.removeCallbacks(sleepRun)
    }

    /**
     * 뒤로가기 — 예전 방식(onBackPressed 재정의)은 안드로이드 13+ 의 예측형 뒤로가기와
     * 어긋나고 린트 오류도 난다. 콜백을 등록하는 방식으로 바꿨다.
     */
    private fun registerBackHandler() {
        onBackPressedDispatcher.addCallback(this,
            object : androidx.activity.OnBackPressedCallback(true) {
                override fun handleOnBackPressed() = confirmQuit()
            })
    }

    private fun confirmQuit() {
        AlertDialog.Builder(this)
            .setView(cuteDialogView(getString(R.string.quit_ask)))
            .setPositiveButton(getString(R.string.quit_yes)) { _, _ -> finish() }
            .setNegativeButton(getString(R.string.quit_no), null).show()
    }

    /** 응원 병아리가 있는 확인 대화상자 내용 (이모지 대신 진짜 일러스트) */
    private fun cuteDialogView(msg: String): View {
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = android.view.Gravity.CENTER_HORIZONTAL
            setPadding(dp(20), dp(20), dp(20), dp(4))
        }
        box.addView(android.widget.ImageView(this).apply {
            setImageResource(R.drawable.ck_cheerup)
            layoutParams = LinearLayout.LayoutParams(dp(96), dp(96))
        })
        box.addView(TextView(this).apply {
            text = msg
            textSize = 15f
            gravity = android.view.Gravity.CENTER
            setTextColor(Color.parseColor("#4E342E"))
            setPadding(0, dp(10), 0, 0)
        })
        return box
    }


    // ---------------- 문제 표시 ----------------

    private fun showQuestion() {
        val s = session ?: return
        if (s.isFinished) { showResult(); return }
        val q = s.current() ?: run { showResult(); return }

        if (firstQuestion) {
            firstQuestion = false
            renderQuestion(q)
        } else {
            // 이전 문제가 왼쪽으로 미끄러져 나가고 새 문제가 오른쪽에서 들어온다
            val slide = b.questionBox.width * 0.22f
            b.questionBox.animate().translationX(-slide).alpha(0f).setDuration(90L)
                .withEndAction {
                    renderQuestion(q)
                    b.questionBox.translationX = slide
                    b.questionBox.animate().translationX(0f).alpha(1f).setDuration(110L).start()
                }.start()
        }
    }

    private fun renderQuestion(q: Question) {
        val s = session ?: return
        // 응원 타이머 재시작
        b.root.removeCallbacks(encourageRun)
        b.root.removeCallbacks(sleepRun)
        b.root.postDelayed(encourageRun, 15_000L)
        b.root.postDelayed(sleepRun, 45_000L)

        b.progressBar.progress = (s.progress * 100).toInt()
        questionNo = "${(s.solvedCount + 1).coerceAtMost(s.totalCount)} / ${s.totalCount}"
        showHearts(if (reviewMode) null else if (db.heartsEnabled()) s.hearts else -1)
        b.questionBox.removeAllViews()
        b.btnCheck.isEnabled = false
        b.btnCheck.text = getString(R.string.lesson_check)
        b.btnCheck.visibility = View.VISIBLE
        checkAction = null
        speakFails = 0
        choiceButtons = emptyList()
        choiceAnswer = -1
        hintUsedHere = false
        feedbackArtRes = 0
        tts.stop()

        when (q) {
            is Question.Mcq -> showMcq(q)
            is Question.ListenMcq -> showListenMcq(q)
            is Question.ListenDialog -> showListenDialog(q)
            is Question.Dictation -> showDictation(q)
            is Question.TypeTranslate -> showTypeTranslate(q)
            is Question.Order -> showOrder(q)
            is Question.Match -> showMatch(q)
            is Question.Speak -> showSpeak(q)
            is Question.Math -> Unit   // 영어 전용 앱 — 수학 팩이 없어 도달하지 않는다
        }
        // 선택지가 만들어진 뒤에 힌트 버튼 상태를 갱신한다
        refreshHintButton()
    }

    // ---------------- 힌트권 ----------------

    private fun refreshHintButton() {
        val n = db.itemCount("hint")
        b.btnHint.text = "$n"
        b.btnHint.isEnabled = n > 0 && choiceButtons.size >= 4 && !hintUsedHere
        b.btnHint.alpha = if (b.btnHint.isEnabled) 1f else 0.45f
    }

    /** 오답 2개를 지워 준다 (4지선다에서만) */
    private fun useHint() {
        if (hintUsedHere || choiceButtons.size < 4 || choiceAnswer < 0) return
        if (db.itemCount("hint") <= 0) {
            Toast.makeText(this, getString(R.string.hint_none), Toast.LENGTH_SHORT).show()
            return
        }
        if (!db.useItem("hint")) return
        hintUsedHere = true
        val wrongIdx = choiceButtons.indices.filter { it != choiceAnswer }.shuffled().take(2)
        for (i in wrongIdx) {
            choiceButtons[i].apply {
                isEnabled = false
                alpha = 0.3f
                paintFlags = paintFlags or android.graphics.Paint.STRIKE_THRU_TEXT_FLAG
            }
        }
        sfx.piyak()
        refreshHintButton()
    }

    private fun artRes(name: String?): Int =
        name?.let { resources.getIdentifier(it, "drawable", packageName) } ?: 0

    /** 문장·낱말에서 그림 사전(199장)에 있는 첫 단어의 일러스트 (없으면 0) */
    private fun sentenceArt(en: String?, ko: String? = null): Int {
        en?.lowercase()?.split(Regex("[^a-z]+"))?.forEach { w ->
            com.piyak.english.engine.WordArt.EN[w]?.let { return artRes(it) }
        }
        if (ko != null) {
            for ((kw, res) in com.piyak.english.engine.WordArt.KO) {
                if (ko.contains(kw)) return artRes(res)
            }
        }
        return 0
    }


    /**
     * 문장·지문의 낱말로 상황 장면 그림을 고른다 (발주서 #05, 20장).
     * 낱말 그림이 없는 문법·회화·대화 문제에 "그 상황의 그림"을 붙이는 용도라
     * 정답을 집어 주지는 않되 분위기는 잡아 준다.
     */
    private fun sceneArt(vararg texts: String?): Int {
        val t = texts.filterNotNull().joinToString(" ").lowercase()
        if (t.isBlank()) return 0
        val table = listOf(
            "greeting" to listOf("hello", "hi ", "nice to meet", "good morning", "인사", "안녕"),
            "restaurant" to listOf("restaurant", "menu", "order", "waiter", "식당", "주문", "메뉴"),
            "airport" to listOf("airport", "flight", "passport", "boarding", "공항", "비행"),
            "travel" to listOf("travel", "trip", "tour", "hotel", "여행", "호텔"),
            "shopping" to listOf("shop", "buy", "price", "store", "쇼핑", "가격", "사다"),
            "school" to listOf("school", "class", "teacher", "student", "homework", "학교", "수업", "선생님"),
            "hospital" to listOf("hospital", "doctor", "sick", "medicine", "병원", "의사", "아프"),
            "phone" to listOf("phone", "call", "message", "전화", "통화"),
            "weather" to listOf("weather", "rain", "sunny", "snow", "cloud", "날씨", "비가", "눈이"),
            "family" to listOf("family", "mother", "father", "sister", "brother", "가족", "엄마", "아빠"),
            "home" to listOf("home", "house", "room", "kitchen", "집에", "방에"),
            "office" to listOf("office", "work", "meeting", "boss", "회사", "회의", "직장"),
            "market" to listOf("market", "fruit", "vegetable", "시장", "과일"),
            "sports" to listOf("sport", "soccer", "baseball", "play ball", "운동", "축구", "야구"),
            "birthday" to listOf("birthday", "cake", "party", "present", "생일", "파티", "선물"),
            "camping" to listOf("camp", "tent", "campfire", "캠핑", "텐트"),
            "library" to listOf("library", "book", "read", "도서관", "책을"),
            "bus" to listOf("bus", "subway", "train", "station", "버스", "지하철", "기차"),
            "park" to listOf("park", "walk", "bench", "공원", "산책"),
            "beach" to listOf("beach", "sea", "swim", "바다", "해변", "수영"),
        )
        for ((name, keys) in table) {
            if (keys.any { t.contains(it) }) {
                val id = artRes("scene_$name")
                if (id != 0) return id
            }
        }
        return 0
    }

    /**
     * 문제 위쪽에 일러스트를 끼워 넣는다 — 글만 덜렁 있는 화면을 없애는 핵심.
     *
     * 한 문제에 그림이 두 장 이상 붙을 때(예: 독해 = 낱말 그림 + 책 병아리)
     * 위아래로 쌓으면 화면을 다 잡아먹어서, 한 줄에 나란히 놓고 폭에 맞춰 같이 줄인다.
     */
    private fun addArt(v: View, resId: Int, sizeDp: Int = 165) {
        if (resId == 0) return
        val root = v as? LinearLayout ?: return
        val row = root.findViewWithTag<LinearLayout>(ART_ROW_TAG) ?: LinearLayout(this).apply {
            tag = ART_ROW_TAG
            orientation = LinearLayout.HORIZONTAL
            gravity = android.view.Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(6); bottomMargin = dp(4) }
            root.addView(this, minOf(1, root.childCount))
        }
        val img = android.widget.ImageView(this).apply {
            tag = sizeDp                     // 원래 요청 크기 — 다시 계산할 때 쓴다
            layoutParams = LinearLayout.LayoutParams(dp(sizeDp), dp(sizeDp))
        }
        // 두 번째 프레임이 있는 포즈는 저절로 움직인다 (듣기 병아리 고개 까딱 등)
        PoseAnim.applyTo(img, resId)
        row.addView(img)
        fitArtRow(row)
        // 뿅 하고 등장
        img.scaleX = 0.7f; img.scaleY = 0.7f; img.alpha = 0f
        img.animate().scaleX(1f).scaleY(1f).alpha(1f)
            .setDuration(260L).setInterpolator(android.view.animation.OvershootInterpolator(1.6f)).start()
    }

    /** 그림 줄이 화면 밖으로 나가지 않게 비율을 지키며 같이 줄인다 */
    private fun fitArtRow(row: LinearLayout) {
        val n = row.childCount
        if (n == 0) return
        val gap = dp(10)
        val avail = resources.displayMetrics.widthPixels - dp(32) - gap * (n - 1)
        var want = 0
        for (i in 0 until n) want += dp(row.getChildAt(i).tag as? Int ?: 150)
        val scale = if (want > avail) avail.toFloat() / want else 1f
        for (i in 0 until n) {
            val child = row.getChildAt(i)
            val size = (dp(child.tag as? Int ?: 150) * scale).toInt()
            child.layoutParams = LinearLayout.LayoutParams(size, size).apply {
                if (i > 0) marginStart = gap
            }
        }
    }

    private fun inflate(layout: Int): View {
        val v = LayoutInflater.from(this).inflate(layout, b.questionBox, false)
        // 내용이 화면보다 짧을 때 위로 쏠리지 않도록 세로 중앙에 놓는다
        // (fillViewport 라 questionBox 가 화면을 채우고, 길면 그대로 스크롤된다)
        // 위쪽에 붙이되, 내용이 짧으면 조금만 내려 준다 —
        // 그냥 가운데 정렬하면 진행바와 문제 사이가 손가락 두 마디만큼 벌어진다
        (v.layoutParams as? android.widget.FrameLayout.LayoutParams)?.gravity =
            android.view.Gravity.TOP
        v.findViewById<TextView>(R.id.txtCountInline)?.text = questionNo
        // 입력칸(받아쓰기·영작)이 포커스를 채가면 스크롤이 아래로 끌려가 문제 위쪽이 잘린다
        v.isFocusableInTouchMode = true
        b.questionBox.addView(v)
        v.requestFocus()
        b.questionScroll.post { b.questionScroll.scrollTo(0, 0) }
        v.addOnLayoutChangeListener(object : View.OnLayoutChangeListener {
            override fun onLayoutChange(
                view: View, l: Int, t: Int, r: Int, bo: Int,
                ol: Int, ot: Int, or_: Int, ob: Int,
            ) {
                val free = b.questionBox.height - view.height
                view.translationY = (free / 2f).coerceIn(0f, dp(10).toFloat())
            }
        })
        return v
    }

    /** 보기마다 다른 파스텔 — 아이 눈에 "글 목록"이 아니라 "알록달록 카드"로 보이게 */
    private val choiceTints = listOf("#FFF3D6", "#E3F4FD", "#E8F6EA", "#F3EDFB")

    /** 누르는 맛 — 눌리면 살짝 줄었다가 튕겨 돌아온다 */
    private fun bouncy(v: View) {
        v.setOnTouchListener { view, e ->
            when (e.actionMasked) {
                android.view.MotionEvent.ACTION_DOWN ->
                    view.animate().scaleX(0.95f).scaleY(0.95f).setDuration(60).start()
                android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL ->
                    view.animate().scaleX(1f).scaleY(1f).setDuration(140)
                        .setInterpolator(android.view.animation.OvershootInterpolator(2f)).start()
            }
            false
        }
    }

    /**
     * 문제·보기에 등장하는 낱말을 놀이터 낱말사전에서 찾아 삽화 이모지로.
     * 정답 힌트가 되지 않도록 **문제 지문에 있는 낱말만** 본다 (보기는 안 본다 —
     * 보기 중 하나의 그림을 띄우면 그게 답이라고 알려주는 셈이 된다).
     */
    private fun findWordArt(prompt: String, choices: List<String>): String? {
        val p = prompt.lowercase()
        for ((emoji, en, ko) in com.piyak.english.engine.MiniGames.WORDS) {
            if (Regex("\b${Regex.escape(en)}\b").containsMatchIn(p) || prompt.contains(ko)) return emoji
        }
        return null
    }

    private fun choiceButton(text: String, index: Int = 0): Button = Button(this).apply {
        this.text = text
        textSize = 17f
        isAllCaps = false
        setTextColor(Color.parseColor("#4E342E"))
        val base = Color.parseColor(choiceTints[index % choiceTints.size])
        tag = base
        backgroundTintList = ColorStateList.valueOf(base)
        bouncy(this)
        layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(8) }
    }

    /** 공용 4지선다 렌더링 */
    private fun renderChoices(
        box: LinearLayout, choices: List<String>, answer: Int,
        explain: String?, answerText: String,
    ) {
        // 보기가 짧으면 둥둥 떠다니는 버블로 (만지는 재미), 길면 읽기 편한 버튼 목록으로
        if (com.piyak.english.ui.game.BubbleChoiceView.fits(choices)) {
            renderBubbleChoices(box, choices, answer, explain, answerText)
            return
        }
        var selected = -1
        val buttons = ArrayList<Button>()
        choices.forEachIndexed { i, c ->
            val btn = choiceButton(c, i)
            btn.setOnClickListener {
                selected = i
                buttons.forEach {
                    if (it.isEnabled) it.backgroundTintList =
                        ColorStateList.valueOf(it.tag as? Int ?: Color.WHITE)
                }
                btn.backgroundTintList = ColorStateList.valueOf(Color.parseColor("#FFD54F"))
                b.btnCheck.isEnabled = true
            }
            buttons.add(btn)
            box.addView(btn)
        }
        choiceButtons = buttons
        choiceAnswer = answer
        checkAction = {
            val ok = selected == answer
            submitAnswer(ok, if (ok) null else getString(R.string.fb_answer, answerText), explain)
        }
    }

    /**
     * 보기를 **그림 2×2** 로 보여준다.
     *
     * 뜻을 한국어 낱말로 물으면 그 문제는 한국어 화자 전용이 된다.
     * 그림으로 물으면 어느 나라 아이도 그대로 풀 수 있고, 저학년에게는
     * 글자를 읽는 것보다 그림을 고르는 편이 애초에 더 맞는 방식이다.
     *
     * 채점은 그대로 answer(인덱스)로 한다 — 보기 글자가 무엇이든 상관없다.
     */
    private fun renderArtChoices(
        box: LinearLayout, choices: List<String>, choiceArt: List<String>,
        answer: Int, explain: String?, answerText: String,
    ) {
        val grid = android.widget.GridLayout(this).apply {
            columnCount = 2
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
        var selected = -1
        val cards = ArrayList<View>()
        choices.indices.forEach { i ->
            val card = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = android.view.Gravity.CENTER
                setPadding(dp(6), dp(8), dp(6), dp(8))
                background = getDrawable(R.drawable.bg_tile)
                layoutParams = android.widget.GridLayout.LayoutParams().apply {
                    width = 0
                    height = dp(132)
                    columnSpec = android.widget.GridLayout.spec(
                        android.widget.GridLayout.UNDEFINED, 1f
                    )
                    setMargins(dp(5), dp(5), dp(5), dp(5))
                }
            }
            val res = artRes(choiceArt.getOrNull(i))
            if (res != 0) {
                card.addView(android.widget.ImageView(this).apply {
                    setImageResource(res)
                    layoutParams = LinearLayout.LayoutParams(dp(96), dp(96))
                })
            } else {
                // 그림이 없으면 글자로라도 보여 준다 (빈 칸은 절대 만들지 않는다)
                card.addView(TextView(this).apply {
                    text = choices[i]
                    textSize = 17f
                    gravity = android.view.Gravity.CENTER
                    setTextColor(Color.parseColor("#4E342E"))
                })
            }
            card.setOnClickListener {
                selected = i
                sfx.piyak()
                cards.forEachIndexed { j, c ->
                    val on = j == i
                    c.alpha = if (on) 1f else 0.4f
                    c.scaleX = if (on) 1.04f else 1f
                    c.scaleY = if (on) 1.04f else 1f
                }
                b.btnCheck.isEnabled = true
            }
            cards.add(card)
            grid.addView(card)
        }
        box.addView(grid)
        checkAction = {
            val ok = selected == answer
            submitAnswer(ok, if (ok) null else getString(R.string.fb_answer, answerText), explain)
        }
    }

    /** 짧은 보기: 버블로 띄운다. 시간 압박은 없고 움직임과 터치감만 더한다. */
    private fun renderBubbleChoices(
        box: LinearLayout, choices: List<String>, answer: Int,
        explain: String?, answerText: String,
    ) {
        val view = com.piyak.english.ui.game.BubbleChoiceView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(230)
            )
        }
        var selected = -1
        view.onPick = {
            selected = it
            sfx.piyak()
            b.btnCheck.isEnabled = true
        }
        view.setChoices(choices)
        box.addView(view)
        checkAction = {
            val ok = selected == answer
            view.reveal(answer)
            view.lock()
            submitAnswer(ok, if (ok) null else getString(R.string.fb_answer, answerText), explain)
        }
    }

    private fun showMcq(q: Question.Mcq) {
        val v = inflate(R.layout.view_q_mcq)
        v.findViewById<TextView>(R.id.txtKind).text = when {
            q.passage != null -> getString(R.string.kind_reading)
            q.bigEmoji != null -> getString(R.string.kind_pic)
            else -> getString(R.string.kind_choose)
        }
        // 그림 우선 원칙 (사용자 결정 2026-08-02): 그림이 답을 알려줘도 좋다.
        // 그림-소리-뜻이 같이 붙는 것이 곧 학습이고, 화면도 훨씬 즐겁다.
        val koWord = Regex("\"([가-힣]+)").find(q.prompt)?.groupValues?.get(1)
        val koArt = koWord?.let { k -> com.piyak.english.engine.WordArt.KO[k]?.let { artRes(it) } } ?: 0
        val enWord = Regex("\"([A-Za-z]+)").find(q.prompt)?.groupValues?.get(1)?.lowercase()
        val enArt = enWord?.let {
            resources.getIdentifier("word_$it", "drawable", packageName)
        } ?: 0
        val quotedArt = if (koArt != 0) koArt else enArt
        when {
            // 독해는 지문·보기가 길다. 그림은 책 병아리 하나만 작게 (아래에서 붙인다)
            q.passage != null -> Unit
            // 한국어를 못 읽는 폰에서는 문제가 지정한 그림이 곧 문제문이 된다
            q.bigArt != null && !com.piyak.english.i18n.Tpl.isKorean &&
                artRes(q.bigArt) != 0 -> addArt(v, artRes(q.bigArt), 175)
            quotedArt != 0 -> addArt(v, quotedArt, 175)
            // 초등영어처럼 이모지가 붙어 온 문제도 낱말 그림이 있으면 그걸 먼저 쓴다
            q.bigEmoji != null -> {
                val emojiArt = sentenceArt(q.prompt)
                if (emojiArt != 0) addArt(v, emojiArt, 165)
                else v.findViewById<TextView>(R.id.txtBigEmoji).apply {
                    visibility = View.VISIBLE
                    text = q.bigEmoji
                }
            }
            else -> {
                // 낱말 그림 → 상황 장면 그림 → 이모지 순으로 무조건 뭐라도 붙인다
                val hint = sentenceArt(q.prompt)
                val scene = if (hint == 0) sceneArt(q.prompt, q.passage) else 0
                if (hint != 0) addArt(v, hint, 150)
                else if (scene != 0) addArt(v, scene, 150)
                else {
                    val emoji = findWordArt(q.prompt, q.choices)
                    if (emoji != null) v.findViewById<TextView>(R.id.txtBigEmoji).apply {
                        visibility = View.VISIBLE
                        text = emoji
                    } else if (q.passage == null) {
                        // 아무것도 못 찾으면 생각하는 병아리 — 그림 없는 문제 0% 보장
                        // (지문 문제는 아래에서 책 읽는 병아리가 붙으니 겹치지 않게 건너뛴다)
                        addArt(v, artRes("ck_think"), 120)
                    }
                }
            }
        }
        if (q.passage != null) {
            addArt(v, artRes("ck_book"), 84)
            v.findViewById<TextView>(R.id.txtPassage).apply {
                visibility = View.VISIBLE
                text = q.passage
                // 지문이 길면 지문 상자 안에서 굴려 읽는다
                movementMethod = android.text.method.ScrollingMovementMethod()
                setOnTouchListener { view, e ->
                    view.parent.requestDisallowInterceptTouchEvent(true)
                    if (e.actionMasked == android.view.MotionEvent.ACTION_UP) {
                        view.parent.requestDisallowInterceptTouchEvent(false)
                    }
                    false
                }
            }
        }
        // "…를 영어로?" 문제의 인자는 한국어 뜻이라, 번역된 프레임에 넣어도 한국어가 샌다.
        // 그림이 붙은 문제는 한국어를 못 읽는 폰에서 **그림 자체를 문제**로 쓴다.
        v.findViewById<TextView>(R.id.txtPrompt).text =
            if (q.bigArt != null && !com.piyak.english.i18n.Tpl.isKorean && artRes(q.bigArt) != 0)
                getString(R.string.ask_pic_en)
            else q.prompt
        // 한국 폰은 예전 그대로 한국어 글자 보기로 푼다.
        // 한국어를 못 읽는 폰에서만 같은 문제를 그림 보기로 바꿔 준다 (정답 자리는 같다).
        if (q.choiceArt.isNotEmpty() && !com.piyak.english.i18n.Tpl.isKorean) {
            renderArtChoices(
                v.findViewById(R.id.choicesBox), q.choices, q.choiceArt,
                q.answer, q.explain, q.choices[q.answer]
            )
        } else {
            renderChoices(v.findViewById(R.id.choicesBox), q.choices, q.answer, q.explain, q.choices[q.answer])
        }
    }

    private fun showListenMcq(q: Question.ListenMcq) {
        val v = inflate(R.layout.view_q_mcq)
        // 그림 우선: 들려준 낱말의 그림을 바로 보여준다 (그림-소리 연결도 학습)
        val heardArt = sentenceArt(q.tts).takeIf { it != 0 }
            ?: sceneArt(q.tts, q.prompt).takeIf { it != 0 }
            ?: artRes("ck_listen")
        addArt(v, heardArt, 160)
        v.findViewById<TextView>(R.id.txtKind).text = getString(R.string.kind_listen)
        v.findViewById<TextView>(R.id.txtPrompt).text = q.prompt
        val play = v.findViewById<Button>(R.id.btnPlay)
        val slow = v.findViewById<Button>(R.id.btnPlaySlow)
        play.visibility = View.VISIBLE; slow.visibility = View.VISIBLE
        play.setOnClickListener { tts.speak(q.tts) }
        slow.setOnClickListener { tts.speak(q.tts, slow = true) }
        renderChoices(v.findViewById(R.id.choicesBox), q.choices, q.answer, q.explain,
            getString(R.string.heard_was, q.choices[q.answer], q.tts))
        addSkip(v)
        b.root.postDelayed({ tts.speak(q.tts) }, 350)
    }

    private fun showListenDialog(q: Question.ListenDialog) {
        val v = inflate(R.layout.view_q_mcq)
        val spoken = q.lines.joinToString(" ") { (_, t) -> t }
        val dlgArt = q.lines.asSequence().map { (_, t) -> sentenceArt(t) }.firstOrNull { it != 0 }
            ?: sceneArt(spoken, q.prompt).takeIf { it != 0 }
            ?: artRes("ck_listen")
        addArt(v, dlgArt, 150)
        v.findViewById<TextView>(R.id.txtKind).text = getString(R.string.kind_dialog)
        v.findViewById<TextView>(R.id.txtPrompt).text = q.prompt
        val play = v.findViewById<Button>(R.id.btnPlay)
        play.visibility = View.VISIBLE
        val lines = q.lines.map { (spk, text) -> (if (spk == "A") 0.9f else 1.2f) to text }
        play.setOnClickListener { tts.speakLines(lines) }
        val script = q.lines.joinToString("\n") { (s, t) -> "$s: $t" }
        renderChoices(v.findViewById(R.id.choicesBox), q.choices, q.answer, q.explain,
            getString(R.string.dialog_script, q.choices[q.answer], script))
        addSkip(v)
        b.root.postDelayed({ tts.speakLines(lines) }, 350)
    }

    private fun showDictation(q: Question.Dictation) {
        val v = inflate(R.layout.view_q_type)
        val dictArt = sentenceArt(q.answer).takeIf { it != 0 }
            ?: sceneArt(q.answer, q.hintKo).takeIf { it != 0 }
            ?: artRes("ck_write")
        addArt(v, dictArt)
        v.findViewById<TextView>(R.id.txtKind).text = getString(R.string.kind_dictation)
        v.findViewById<TextView>(R.id.txtPrompt).text = getString(R.string.dictation_prompt)
        // 한국어 힌트는 한국 폰에서만 — 다른 언어 폰에서는 위의 그림이 힌트를 대신한다
        if (q.hintKo != null && com.piyak.english.i18n.Tpl.isKorean) {
            v.findViewById<TextView>(R.id.txtHint).apply { visibility = View.VISIBLE; text = getString(R.string.hint_prefix, q.hintKo) }
        }
        val play = v.findViewById<Button>(R.id.btnPlay)
        val slow = v.findViewById<Button>(R.id.btnPlaySlow)
        play.visibility = View.VISIBLE; slow.visibility = View.VISIBLE
        play.setOnClickListener { tts.speak(q.tts) }
        slow.setOnClickListener { tts.speak(q.tts, slow = true) }
        val edit = v.findViewById<EditText>(R.id.editAnswer)
        edit.addTextChangedListener(SimpleWatcher { b.btnCheck.isEnabled = it.isNotBlank() })
        checkAction = {
            val r = Grader.grade(edit.text.toString(), q.answer, q.alts)
            val extra = if (r.typo) getString(R.string.typo_ok, q.answer) else null
            submitAnswer(r.correct, if (r.correct) extra else getString(R.string.fb_answer, q.answer), q.explain)
        }
        addSkip(v)
        b.root.postDelayed({ tts.speak(q.tts) }, 350)
    }

    private fun showTypeTranslate(q: Question.TypeTranslate) {
        val v = inflate(R.layout.view_q_type)
        val typeArt = sentenceArt(q.answer, q.ko).takeIf { it != 0 }
            ?: sceneArt(q.answer, q.ko).takeIf { it != 0 }
            ?: artRes("ck_write")
        addArt(v, typeArt)
        v.findViewById<TextView>(R.id.txtKind).text = getString(R.string.kind_compose)
        // 한국어를 못 읽는 폰에서는 "한국어 → 영작"이 성립하지 않는다.
        // 대신 영어 문장을 **들려 주고 받아 적게** 한다 — 번역 없이 같은 문장을 익힌다.
        if (com.piyak.english.i18n.Tpl.isKorean) {
            v.findViewById<TextView>(R.id.txtPrompt).text = q.ko
        } else {
            v.findViewById<TextView>(R.id.txtPrompt).text = getString(R.string.listen_type)
            val play = v.findViewById<Button>(R.id.btnPlay)
            play.visibility = View.VISIBLE
            play.text = getString(R.string.play_again)
            play.setOnClickListener { tts.speak(q.answer) }
            b.root.postDelayed({ tts.speak(q.answer) }, 350)
        }
        val edit = v.findViewById<EditText>(R.id.editAnswer)
        edit.addTextChangedListener(SimpleWatcher { b.btnCheck.isEnabled = it.isNotBlank() })
        checkAction = {
            val r = Grader.grade(edit.text.toString(), q.answer, q.alts)
            val extra = if (r.typo) getString(R.string.typo_ok, q.answer) else null
            submitAnswer(r.correct, if (r.correct) extra else getString(R.string.fb_answer, q.answer), q.explain)
        }
    }

    private fun showOrder(q: Question.Order) {
        val v = inflate(R.layout.view_q_order)
        val orderArt = sentenceArt(q.en, q.ko).takeIf { it != 0 }
            ?: sceneArt(q.en, q.ko).takeIf { it != 0 }
            ?: artRes("ck_book")
        addArt(v, orderArt, 150)
        // 한국어를 못 읽는 폰에서는 뜻 대신 **영어 문장을 들려 주고** 순서를 맞추게 한다.
        // 듣기+어순 연습이 되므로 번역 없이도 문제가 성립한다. 문구를 누르면 다시 들려 준다.
        val orderPrompt = v.findViewById<TextView>(R.id.txtPrompt)
        if (com.piyak.english.i18n.Tpl.isKorean) {
            orderPrompt.text = q.ko
        } else {
            orderPrompt.text = getString(R.string.listen_arrange)
            orderPrompt.setOnClickListener { tts.speak(q.en) }
            b.root.postDelayed({ tts.speak(q.en) }, 350)
        }
        val answerFlow = v.findViewById<FlowLayout>(R.id.answerFlow)
        val bankFlow = v.findViewById<FlowLayout>(R.id.bankFlow)

        val selected = ArrayList<String>()
        val tiles = (q.tokens + q.extras).shuffled()

        fun tileButton(word: String): Button = Button(this).apply {
            text = word; textSize = 18f; isAllCaps = false
            setTextColor(Color.parseColor("#4E342E"))
            background = getDrawable(R.drawable.bg_tile)
            backgroundTintList = null
            minWidth = 0; minimumWidth = 0
            setPadding(dp(18), dp(13), dp(18), dp(13))
        }

        fun refreshCheck() { b.btnCheck.isEnabled = selected.isNotEmpty() }

        for (word in tiles) {
            val tile = tileButton(word)
            tile.setOnClickListener {
                if (tile.parent == bankFlow) {
                    bankFlow.removeView(tile); answerFlow.addView(tile)
                    selected.add(word)
                } else {
                    answerFlow.removeView(tile); bankFlow.addView(tile)
                    selected.remove(word)
                }
                refreshCheck()
            }
            bankFlow.addView(tile)
        }
        checkAction = {
            val ok = Grader.gradeOrder(selected.toList(), q.tokens)
            submitAnswer(ok, if (ok) null else getString(R.string.fb_answer, q.en), q.explain)
        }
    }

    /**
     * 짝 맞추기 — 탭-탭 대신 **손가락으로 선을 그어** 잇는다.
     * 놀이터의 선 잇기와 같은 조작이라 아이가 한 번 익히면 어디서든 통한다.
     */
    private fun showMatch(q: Question.Match) {
        b.btnCheck.visibility = View.INVISIBLE

        val hint = TextView(this).apply {
            text = getString(R.string.match_hint)
            textSize = 15f
            setTextColor(Color.parseColor("#8D6E63"))
            setPadding(dp(4), 0, 0, dp(6))
        }
        val view = com.piyak.english.ui.game.LineMatchView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(400)
            )
        }
        val wrap = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(hint)
            addView(view)
        }
        b.questionBox.addView(wrap)

        var mistakes = 0
        view.onHit = { sfx.piyak() }
        view.onMiss = { mistakes++; sfx.wrong() }
        view.onFinish = {
            val ok = mistakes == 0
            recordSkill(q, ok)
            session?.submitNoPenalty(ok)
            showFeedback(
                ok,
                if (ok) null else getString(R.string.match_mistakes, mistakes),
                q.explain, penalty = false
            )
        }
        view.setPairs(q.pairs)
        view.startLoop()
    }

    private fun showSpeak(q: Question.Speak) {
        val v = inflate(R.layout.view_q_speak)
        val speakArt = sentenceArt(q.en, q.ko).takeIf { it != 0 }
            ?: sceneArt(q.en, q.ko).takeIf { it != 0 }
            ?: artRes("ck_speak")
        addArt(v, speakArt, 150)
        v.findViewById<TextView>(R.id.txtEn).text = q.en
        // 한국어 해석은 한국 폰에서만 — 읽을 문장(영어)은 어차피 위에 있다
        v.findViewById<TextView>(R.id.txtKo).text =
            if (com.piyak.english.i18n.Tpl.isKorean) q.ko ?: "" else ""
        val txtHeard = v.findViewById<TextView>(R.id.txtHeard)
        val btnMic = v.findViewById<Button>(R.id.btnMic)
        val btnSkip = v.findViewById<Button>(R.id.btnCantSpeak)
        b.btnCheck.visibility = View.GONE

        v.findViewById<Button>(R.id.btnListen).setOnClickListener { tts.speak(q.en) }

        btnMic.setOnClickListener {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 77)
                return@setOnClickListener
            }
            tts.stop()
            txtHeard.text = getString(R.string.speak_listening)
            btnMic.isEnabled = false
            stt.start(
                onResult = { heard ->
                    runOnUiThread {
                        btnMic.isEnabled = true
                        val score = Grader.speakScore(heard, q.en)
                        txtHeard.text = getString(R.string.speak_heard, heard, score)
                        if (Grader.gradeSpeak(heard, q.en)) {
                            submitAnswer(true, getString(R.string.speak_success, score), q.explain)
                        } else {
                            speakFails++
                            sfx.wrong()
                            // 건너뛰기는 처음부터 보인다 (못 할 수도 있으니까)
                            Toast.makeText(this, getString(R.string.speak_retry), Toast.LENGTH_SHORT).show()
                        }
                    }
                },
                onError = { code ->
                    runOnUiThread {
                        btnMic.isEnabled = true
                        speakFails++
                        if (speakFails >= 2) btnSkip.visibility = View.VISIBLE
                        txtHeard.text = when (code) {
                            android.speech.SpeechRecognizer.ERROR_NO_MATCH,
                            android.speech.SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
                                getString(R.string.speak_not_heard)
                            -1 -> getString(R.string.speak_unavailable)
                            else -> getString(R.string.speak_error, code)
                        }
                    }
                }
            )
        }
        btnSkip.setOnClickListener {
            recordSkill(q, false)
            session?.submitNoPenalty(false)
            showFeedback(false, getString(R.string.speak_giveup, q.en), q.explain, penalty = false)
        }
    }


    /**
     * 못 풀 수도 있는 문제(듣기·받아쓰기)에 붙이는 건너뛰기.
     * 하트를 깎지 않고 정답을 알려 준 뒤 다음 문제로 넘어간다.
     */
    private fun addSkip(v: View) {
        val root = v as? LinearLayout ?: return
        root.addView(Button(this).apply {
            text = getString(R.string.skip_btn)
            isAllCaps = false
            textSize = 14f
            setTextColor(Color.parseColor("#8D6E63"))
            background = null
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(4) }
            setOnClickListener {
                val q = session?.current() ?: return@setOnClickListener
                val note = when (q) {
                    is Question.ListenMcq ->
                        getString(R.string.heard_was, q.choices[q.answer], q.tts)
                    is Question.ListenDialog -> getString(R.string.fb_answer, q.choices[q.answer])
                    is Question.Dictation -> getString(R.string.fb_answer, q.answer)
                    else -> null
                }
                recordSkill(q, false)
                session?.submitNoPenalty(false)
                showFeedback(false, note, q.explain, penalty = false)
            }
        })
    }

    // ---------------- 채점·피드백 ----------------

    /** 일반 제출 (하트·재출제 규칙 적용) */
    private fun submitAnswer(correct: Boolean, note: String?, explain: String?) {
        val s = session ?: return
        val q = s.current() ?: return
        recordSkill(q, correct)
        if (reviewMode) {
            val cleared = db.reviewOutcome(q.id, correct)
            s.submit(correct)
            val msg = when {
                correct && cleared -> getString(R.string.review_cleared)
                correct -> getString(R.string.review_one_more)
                else -> note
            }
            showFeedback(correct, msg, explain, penalty = false)
        } else {
            if (!correct && q !is Question.Match) db.recordWrong(q, lessonId, trackId)
            s.submit(correct)
            showFeedback(correct, note, explain, penalty = true)
        }
    }

    private fun showFeedback(correct: Boolean, note: String?, explain: String?, penalty: Boolean) {
        if (correct) sfx.correct() else if (penalty) sfx.wrong()
        // 병아리 리액션 + 콤보 (답을 냈으니 응원 타이머는 멈춘다)
        b.root.removeCallbacks(encourageRun)
        if (correct) {
            combo++
            b.celebrate.correct(combo)
            if (b.chickView.visibility == View.VISIBLE) b.chickView.cheer()
        } else {
            combo = 0
            if (penalty && b.chickView.visibility == View.VISIBLE) b.chickView.oops()
        }
        // GONE 으로 없애면 그만큼 자리가 남아 문제가 아래로 밀린다 — 자리는 남겨 둔다
        b.btnCheck.visibility = View.INVISIBLE
        b.feedbackPanel.visibility = View.VISIBLE
        b.feedbackPanel.background = getDrawable(
            if (correct) R.drawable.bg_feedback_ok else R.drawable.bg_feedback_no
        )
        // 정답 공개 후에는 낱말 그림으로 한 번 더 각인 (없으면 병아리)
        val fbArt = feedbackArtRes
        PoseAnim.applyTo(
            b.imgFeedback,
            when {
                fbArt != 0 -> fbArt
                correct -> R.drawable.ck_cheer   // 날갯짓하며 축하
                else -> R.drawable.ck_sad
            }
        )
        val fbSize = dp(if (fbArt != 0) 84 else 56)
        b.imgFeedback.layoutParams = b.imgFeedback.layoutParams.apply { width = fbSize; height = fbSize }
        b.txtFeedback.text = if (correct) okLines.random() else noLines.random()
        // 패널이 아래에서 통통 올라오고, 그림이 뿅 하고 커진다
        b.feedbackPanel.translationY = dp(48).toFloat()
        b.feedbackPanel.alpha = 0f
        b.feedbackPanel.animate().translationY(0f).alpha(1f)
            .setDuration(240L).setInterpolator(android.view.animation.OvershootInterpolator(1.1f)).start()
        b.imgFeedback.scaleX = 0.4f; b.imgFeedback.scaleY = 0.4f
        b.imgFeedback.animate().scaleX(1f).scaleY(1f)
            .setDuration(340L).setInterpolator(android.view.animation.OvershootInterpolator(2.2f)).start()
        val detail = listOfNotNull(note, explain).joinToString("\n\n")
        if (detail.isNotEmpty()) {
            b.txtExplain.visibility = View.VISIBLE
            b.txtExplain.text = detail
            // 긴 해설은 패널 안에서 스크롤
            b.txtExplain.movementMethod = android.text.method.ScrollingMovementMethod()
            b.txtExplain.scrollTo(0, 0)
        } else b.txtExplain.visibility = View.GONE
        b.btnContinue.backgroundTintList = ColorStateList.valueOf(
            Color.parseColor(if (correct) "#66BB6A" else "#FF5252")
        )
        showHearts(if (reviewMode) null else if (db.heartsEnabled()) (session?.hearts ?: 0) else -1)
    }


    /**
     * 상단 하트 표시. [n] 이 null 이면 복습 모드, -1 이면 하트 기능 끔.
     * 아이콘을 레이아웃에 박아 두면 글자만 지워도 하트가 남으므로 코드에서 같이 끈다.
     */
    private fun showHearts(n: Int?) {
        val icon = if (n != null && n >= 0) R.drawable.ic_heart else 0
        b.txtHearts.setCompoundDrawablesRelativeWithIntrinsicBounds(icon, 0, 0, 0)
        b.txtHearts.text = when {
            n == null -> getString(R.string.lesson_review_mode)
            n < 0 -> ""
            else -> "$n"
        }
    }

    private fun hideFeedback() {
        b.feedbackPanel.visibility = View.GONE
        b.btnCheck.visibility = View.VISIBLE
    }

    // ---------------- 결과 ----------------

    private fun showResult() {
        val s = session ?: return
        tts.stop()
        b.resultPanel.visibility = View.VISIBLE

        if (s.failed) {
            b.imgResult.setImageResource(R.drawable.ck_cheerup)
            b.txtResultTitle.text = getString(R.string.result_no_heart_title)
            b.txtResultStats.text = getString(R.string.result_no_heart_msg)
            db.setHearts(0)
            return
        }

        sfx.done()
        PoseAnim.applyTo(b.imgResult, if (s.isPerfect) R.drawable.ck_cheer else R.drawable.ck_clap)
        b.celebrate.finale()
        val xp = s.xpEarned()
        var coins = 0
        if (reviewMode) {
            val h = (db.hearts() + 1).coerceAtMost(db.maxHearts())
            db.setHearts(h)
            db.addXp(xp)
            db.markToday()
            // 복습 보너스는 하루 한도까지만 (파밍 방지)
            if (db.bonusCountToday("review") < Wallet.REVIEW_DAILY_LIMIT) {
                coins = db.earnCoins(Wallet.REVIEW_BONUS, "REVIEW", getString(R.string.review_done))
                db.addBonusCountToday("review")
            }
            b.txtResultTitle.text = getString(R.string.result_review_title)
            b.txtResultStats.text = getString(R.string.result_review_stats, (s.accuracy * 100).toInt(), xp, h)
        } else {
            if (db.heartsEnabled()) db.setHearts(s.hearts)
            db.addXp(xp)
            // 코인은 이 레슨을 "처음" 깰 때만 — 다시 풀어도 0원이라 반복 파밍이 안 된다
            val firstClear = db.lessonStars(lessonId) == 0
            db.completeLesson(lessonId, trackId, s.stars(), s.accuracy)
            if (s.isPerfect) db.setMeta("perfect_count", (db.metaInt("perfect_count") + 1).toString())
            if (firstClear) {
                coins = db.earnCoins(
                    Wallet.lessonReward(s.firstTryCorrect, s.isPerfect), "LESSON",
                    getString(R.string.result_lesson_sub, lessonTitle, s.firstTryCorrect)
                )
            }
            b.txtResultTitle.text = if (s.isPerfect) getString(R.string.result_perfect_title) else getString(R.string.result_lesson_title)
            b.txtResultStats.text =
                "$lessonTitle\n${"⭐".repeat(s.stars())}\n" +
                    getString(R.string.result_stats, (s.accuracy * 100).toInt(), xp) +
                    if (s.isPerfect) getString(R.string.result_perfect_bonus) else ""
        }
        if (coins > 0) {
            b.txtResultStats.append("\n\n" + getString(R.string.result_coins, Wallet.format(this, coins), Wallet.format(this, db.coins())))
        } else if (!reviewMode) {
            b.txtResultStats.append("\n\n" + getString(R.string.result_no_coins))
        }
        b.txtResultStats.append(growthReport())
        checkBadges()
    }

    /** 결과 화면 하단: 영역 레벨업·칭호 승급·오늘의 목표 달성 알림 */
    private fun growthReport(): String {
        val states = db.skillStates()
        val sb = StringBuilder()

        for (st in states) {
            val before = startSkillLevels[st.def.id] ?: 0
            if (st.level > before) {
                sb.append("\n\n" + getString(R.string.result_skill_up, st.def.emoji, getString(st.def.titleRes), st.level))
            }
        }
        val overall = com.piyak.english.engine.Skills.overallLevel(states)
        val rank = com.piyak.english.engine.Ranks.of(overall)
        if (startRank != null && rank.titleRes != startRank!!.titleRes) {
            sb.append("\n\n" + getString(R.string.result_rank_up, rank.emoji, getString(rank.titleRes)))
        }
        val goal = db.dailyGoal()
        val todayXp = db.xpToday()
        sb.append("\n\n" + getString(R.string.result_goal, todayXp, goal))
        if (com.piyak.english.engine.DailyGoal.isDone(todayXp, goal)) {
            sb.append(getString(R.string.result_goal_done))
            // 목표 달성은 하루 한 번만 집계 + 용돈 보너스
            if (db.metaLong("goal_met_day", -1) != Db.today()) {
                db.setMeta("goal_met_day", Db.today().toString())
                db.setMeta("goals_met", (db.metaInt("goals_met") + 1).toString())
                val bonus = db.earnCoins(Wallet.DAILY_GOAL_BONUS, "GOAL", getString(R.string.goal_reached))
                if (bonus > 0) sb.append("\n" + getString(R.string.result_goal_bonus, Wallet.format(this, bonus)))
            }
        }
        return sb.toString()
    }

    private fun checkBadges() {
        val days = db.studyDays()
        val (_, best) = Economy.streak(days, Db.today())
        val unitMap = HashMap<String, Int>()
        if (trackId.isNotEmpty()) {
            ContentRepo.track(this, trackId)?.let { t ->
                val done = db.completedLessonIds()
                unitMap[trackId] = t.units.count { u -> u.lessons.isNotEmpty() && u.lessons.all { it.id in done } }
            }
        }
        val snap = StatsSnapshot(
            lessonsDone = db.lessonsDoneCount(),
            perfectCount = db.metaInt("perfect_count"),
            xp = db.xp(),
            streakBest = best,
            placementDone = db.meta("placement_done") == "1",
            reviewCleared = db.metaInt("review_cleared"),
            unitsCompleted = unitMap,
            // 배지 판정에는 두 과목의 영역을 모두 넘긴다
            skillLevels = db.skillStates(
                com.piyak.english.engine.Skills.ALL + com.piyak.english.engine.Skills.MATH
            ).associate { it.def.id to it.level },
            goalsMet = db.metaInt("goals_met"),
        )
        val newly = Badges.check(snap, db.earnedBadges())
        for (bd in newly) {
            db.earnBadge(bd.id)
            Toast.makeText(this, getString(R.string.badge_earned, bd.emoji, getString(bd.titleRes)), Toast.LENGTH_LONG).show()
        }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}

/** EditText 간단 워처 */
private class SimpleWatcher(val onChange: (String) -> Unit) : android.text.TextWatcher {
    override fun beforeTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
    override fun onTextChanged(s: CharSequence?, a: Int, b: Int, c: Int) {}
    override fun afterTextChanged(s: android.text.Editable?) { onChange(s?.toString() ?: "") }
}
