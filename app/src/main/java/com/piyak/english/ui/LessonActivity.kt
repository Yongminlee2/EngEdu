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
    private val autoReadMath = false

    /** 레슨 시작 시점의 영역별 레벨·칭호 (결과 화면에서 상승분을 보여주려고 기억) */
    private var startSkillLevels: Map<String, Int> = emptyMap()
    private var startRank: com.piyak.english.engine.Rank? = null

    private fun recordSkill(q: Question, correct: Boolean) {
        if (skillRecorded.add(q.id)) db.recordSkill(q.skill, correct)
    }

    private val okLines = listOf("삐약! 정답이에요!", "완벽해요! 🐥", "역시 천재!", "삐약삐약~ 좋아요!", "굿굿! 최고예요!")
    private val noLines = listOf("아쉬워요 😢", "괜찮아요, 다시 나와요!", "삐약… 다음엔 맞혀요!", "조금만 더 힘내요!")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        b = ActivityLessonBinding.inflate(layoutInflater)
        setContentView(b.root)
        db = Db.get(this)
        sfx = Sfx(this)
        tts = Tts(this)
        tts.rate = db.meta("tts_rate", "1.0").toFloatOrNull() ?: 1.0f
        stt = Stt(this)

        reviewMode = intent.getStringExtra("mode") == "review"
        val questions: List<Question>
        if (reviewMode) {
            val wrongs = db.wrongList(12)
            questions = wrongs.mapNotNull { (qid, lid, tid) -> ContentRepo.findQuestion(this, tid, lid, qid) }
            lessonTitle = "오답 복습"
            if (questions.isEmpty()) {
                Toast.makeText(this, "복습할 오답이 없어요!", Toast.LENGTH_SHORT).show()
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
            if (db.hearts() <= 0) {
                AlertDialog.Builder(this)
                    .setTitle("하트가 없어요 💔")
                    .setMessage("30분마다 하트가 1개씩 차요.\n오답 복습을 완료하면 하트 1개를 받을 수 있어요!")
                    .setPositiveButton("확인") { _, _ -> finish() }
                    .setCancelable(false).show()
                return
            }
        }

        session = LessonSession(
            questions,
            hearts = if (reviewMode) 99 else db.hearts(),
            useHearts = !reviewMode,
        )

        db.skillStates().let { states ->
            startSkillLevels = states.associate { it.def.id to it.level }
            startRank = com.piyak.english.engine.Ranks.of(com.piyak.english.engine.Skills.overallLevel(states))
        }

        b.btnClose.setOnClickListener { confirmQuit() }
        b.btnHint.setOnClickListener { useHint() }
        setUpScratchPad()
        b.btnContinue.setOnClickListener { hideFeedback(); showQuestion() }
        b.btnCheck.setOnClickListener { checkAction?.invoke() }
        b.btnDone.setOnClickListener { finish() }

        showQuestion()
    }

    override fun onDestroy() {
        super.onDestroy()
        tts.shutdown(); stt.stop(); sfx.release()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() { confirmQuit() }

    private fun confirmQuit() {
        AlertDialog.Builder(this)
            .setMessage("레슨을 그만둘까요?\n진행 상황은 저장되지 않아요 🐥")
            .setPositiveButton("그만두기") { _, _ -> finish() }
            .setNegativeButton("계속하기", null).show()
    }

    // ---------------- 문제 표시 ----------------

    private fun showQuestion() {
        val s = session ?: return
        if (s.isFinished) { showResult(); return }
        val q = s.current() ?: run { showResult(); return }

        b.progressBar.progress = (s.progress * 100).toInt()
        b.txtHearts.text = if (reviewMode) "💊 복습" else "❤️ ${s.hearts}"
        b.questionBox.removeAllViews()
        b.btnCheck.isEnabled = false
        b.btnCheck.text = "확인"
        b.btnCheck.visibility = View.VISIBLE
        checkAction = null
        speakFails = 0
        choiceButtons = emptyList()
        choiceAnswer = -1
        hintUsedHere = false
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
            is Question.Math -> showMath(q)
        }
        // 선택지가 만들어진 뒤에 힌트 버튼 상태를 갱신한다
        refreshHintButton()
        // 연습장은 수학 문제에서만 쓴다 (문제가 바뀌면 비운다)
        resetScratchPad(q is Question.Math)
    }

    // ---------------- 연습장 ----------------

    /** 문제 위에 겹쳐 식을 쓰거나 그림에 표시할 수 있는 판 */
    private fun setUpScratchPad() {
        b.btnScratch.setOnClickListener { showScratch(true) }
        b.btnClosePad.setOnClickListener { showScratch(false) }
        b.btnUndo.setOnClickListener { b.scratchPad.undo() }
        b.btnClearPad.setOnClickListener { b.scratchPad.clearAll() }

        fun pen(color: String) {
            b.scratchPad.eraserMode = false
            b.scratchPad.penColor = Color.parseColor(color)
            b.btnEraser.alpha = 0.5f
        }
        b.btnPenDark.setOnClickListener { pen("#3E2723") }
        b.btnPenRed.setOnClickListener { pen("#E53935") }
        b.btnPenBlue.setOnClickListener { pen("#1E88E5") }
        b.btnEraser.setOnClickListener {
            b.scratchPad.eraserMode = true
            b.btnEraser.alpha = 1f
        }
    }

    private fun showScratch(on: Boolean) {
        b.scratchPad.visibility = if (on) View.VISIBLE else View.GONE
        b.scratchBar.visibility = if (on) View.VISIBLE else View.GONE
        // 연습장을 켜면 문제 화면의 버튼을 잘못 누르지 않도록 확인 버튼을 감춘다
        b.btnCheck.visibility = if (on) View.GONE else View.VISIBLE
        if (on) {
            b.btnEraser.alpha = 0.5f
            b.scratchPad.eraserMode = false
        }
    }

    /** 다음 문제로 넘어가면 연습장을 비운다 */
    private fun resetScratchPad(show: Boolean) {
        b.scratchPad.clearAll()
        showScratch(false)
        b.btnScratch.visibility = if (show) View.VISIBLE else View.GONE
    }

    // ---------------- 힌트권 ----------------

    private fun refreshHintButton() {
        val n = db.itemCount("hint")
        b.btnHint.text = "💡 $n"
        b.btnHint.isEnabled = n > 0 && choiceButtons.size >= 4 && !hintUsedHere
        b.btnHint.alpha = if (b.btnHint.isEnabled) 1f else 0.45f
    }

    /** 오답 2개를 지워 준다 (4지선다에서만) */
    private fun useHint() {
        if (hintUsedHere || choiceButtons.size < 4 || choiceAnswer < 0) return
        if (db.itemCount("hint") <= 0) {
            Toast.makeText(this, "힌트권이 없어요. 상점에서 살 수 있어요! 💡", Toast.LENGTH_SHORT).show()
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

    private fun inflate(layout: Int): View {
        val v = LayoutInflater.from(this).inflate(layout, b.questionBox, false)
        b.questionBox.addView(v)
        return v
    }

    private fun choiceButton(text: String): Button = Button(this).apply {
        this.text = text
        textSize = 16f
        isAllCaps = false
        setTextColor(Color.parseColor("#4E342E"))
        backgroundTintList = ColorStateList.valueOf(Color.WHITE)
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
            val btn = choiceButton(c)
            btn.setOnClickListener {
                selected = i
                buttons.forEach {
                    if (it.isEnabled) it.backgroundTintList = ColorStateList.valueOf(Color.WHITE)
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
            submitAnswer(ok, if (ok) null else "정답: $answerText", explain)
        }
    }

    /** 짧은 보기: 버블로 띄운다. 시간 압박은 없고 움직임과 터치감만 더한다. */
    private fun renderBubbleChoices(
        box: LinearLayout, choices: List<String>, answer: Int,
        explain: String?, answerText: String,
    ) {
        val view = com.piyak.english.ui.game.BubbleChoiceView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(290)
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
            submitAnswer(ok, if (ok) null else "정답: $answerText", explain)
        }
    }

    private fun showMcq(q: Question.Mcq) {
        val v = inflate(R.layout.view_q_mcq)
        v.findViewById<TextView>(R.id.txtKind).text = when {
            q.passage != null -> "📖 독해"
            q.bigEmoji != null -> "🎨 그림 문제"
            else -> "🔤 고르기"
        }
        if (q.bigEmoji != null) {
            v.findViewById<TextView>(R.id.txtBigEmoji).apply {
                visibility = View.VISIBLE
                text = q.bigEmoji
            }
        }
        if (q.passage != null) {
            v.findViewById<TextView>(R.id.txtPassage).apply { visibility = View.VISIBLE; text = q.passage }
        }
        v.findViewById<TextView>(R.id.txtPrompt).text = q.prompt
        renderChoices(v.findViewById(R.id.choicesBox), q.choices, q.answer, q.explain, q.choices[q.answer])
    }

    private fun showListenMcq(q: Question.ListenMcq) {
        val v = inflate(R.layout.view_q_mcq)
        v.findViewById<TextView>(R.id.txtKind).text = "🎧 듣기"
        v.findViewById<TextView>(R.id.txtPrompt).text = q.prompt
        val play = v.findViewById<Button>(R.id.btnPlay)
        val slow = v.findViewById<Button>(R.id.btnPlaySlow)
        play.visibility = View.VISIBLE; slow.visibility = View.VISIBLE
        play.setOnClickListener { tts.speak(q.tts) }
        slow.setOnClickListener { tts.speak(q.tts, slow = true) }
        renderChoices(v.findViewById(R.id.choicesBox), q.choices, q.answer, q.explain,
            "${q.choices[q.answer]}  (들려준 말: ${q.tts})")
        b.root.postDelayed({ tts.speak(q.tts) }, 350)
    }

    private fun showListenDialog(q: Question.ListenDialog) {
        val v = inflate(R.layout.view_q_mcq)
        v.findViewById<TextView>(R.id.txtKind).text = "🎧 대화 듣기"
        v.findViewById<TextView>(R.id.txtPrompt).text = q.prompt
        val play = v.findViewById<Button>(R.id.btnPlay)
        play.visibility = View.VISIBLE
        val lines = q.lines.map { (spk, text) -> (if (spk == "A") 0.9f else 1.2f) to text }
        play.setOnClickListener { tts.speakLines(lines) }
        val script = q.lines.joinToString("\n") { (s, t) -> "$s: $t" }
        renderChoices(v.findViewById(R.id.choicesBox), q.choices, q.answer, q.explain,
            "${q.choices[q.answer]}\n\n대본:\n$script")
        b.root.postDelayed({ tts.speakLines(lines) }, 350)
    }

    private fun showDictation(q: Question.Dictation) {
        val v = inflate(R.layout.view_q_type)
        v.findViewById<TextView>(R.id.txtKind).text = "✍️ 받아쓰기"
        v.findViewById<TextView>(R.id.txtPrompt).text = "들리는 대로 영어로 써 보세요"
        if (q.hintKo != null) {
            v.findViewById<TextView>(R.id.txtHint).apply { visibility = View.VISIBLE; text = "힌트: ${q.hintKo}" }
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
            val extra = if (r.typo) "오타가 조금 있었지만 인정! ✔ ${q.answer}" else null
            submitAnswer(r.correct, if (r.correct) extra else "정답: ${q.answer}", q.explain)
        }
        b.root.postDelayed({ tts.speak(q.tts) }, 350)
    }

    private fun showTypeTranslate(q: Question.TypeTranslate) {
        val v = inflate(R.layout.view_q_type)
        v.findViewById<TextView>(R.id.txtKind).text = "✍️ 영작"
        v.findViewById<TextView>(R.id.txtPrompt).text = q.ko
        val edit = v.findViewById<EditText>(R.id.editAnswer)
        edit.addTextChangedListener(SimpleWatcher { b.btnCheck.isEnabled = it.isNotBlank() })
        checkAction = {
            val r = Grader.grade(edit.text.toString(), q.answer, q.alts)
            val extra = if (r.typo) "오타가 조금 있었지만 인정! ✔ ${q.answer}" else null
            submitAnswer(r.correct, if (r.correct) extra else "정답: ${q.answer}", q.explain)
        }
    }

    private fun showOrder(q: Question.Order) {
        val v = inflate(R.layout.view_q_order)
        v.findViewById<TextView>(R.id.txtPrompt).text = q.ko
        val answerFlow = v.findViewById<FlowLayout>(R.id.answerFlow)
        val bankFlow = v.findViewById<FlowLayout>(R.id.bankFlow)

        val selected = ArrayList<String>()
        val tiles = (q.tokens + q.extras).shuffled()

        fun tileButton(word: String): Button = Button(this).apply {
            text = word; textSize = 15f; isAllCaps = false
            setTextColor(Color.parseColor("#4E342E"))
            background = getDrawable(R.drawable.bg_tile)
            backgroundTintList = null
            minWidth = 0; minimumWidth = 0
            setPadding(dp(14), dp(8), dp(14), dp(8))
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
            submitAnswer(ok, if (ok) null else "정답: ${q.en}", q.explain)
        }
    }

    /**
     * 짝 맞추기 — 탭-탭 대신 **손가락으로 선을 그어** 잇는다.
     * 놀이터의 선 잇기와 같은 조작이라 아이가 한 번 익히면 어디서든 통한다.
     */
    private fun showMatch(q: Question.Match) {
        b.btnCheck.visibility = View.GONE

        val hint = TextView(this).apply {
            text = "🔗 짝이 맞는 것끼리 손가락으로 이어요"
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
                if (ok) null else "${mistakes}번 헷갈렸지만 다 이었어요!",
                q.explain, penalty = false
            )
        }
        view.setPairs(q.pairs)
        view.startLoop()
    }

    private fun showSpeak(q: Question.Speak) {
        val v = inflate(R.layout.view_q_speak)
        v.findViewById<TextView>(R.id.txtEn).text = q.en
        v.findViewById<TextView>(R.id.txtKo).text = q.ko ?: ""
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
            txtHeard.text = "🎙 듣고 있어요… 문장을 읽어 주세요!"
            btnMic.isEnabled = false
            stt.start(
                onResult = { heard ->
                    runOnUiThread {
                        btnMic.isEnabled = true
                        val score = Grader.speakScore(heard, q.en)
                        txtHeard.text = "들린 말: \"$heard\" (유사도 ${score}%)"
                        if (Grader.gradeSpeak(heard, q.en)) {
                            submitAnswer(true, "발음 인식 성공! 유사도 ${score}%", q.explain)
                        } else {
                            speakFails++
                            sfx.wrong()
                            if (speakFails >= 2) btnSkip.visibility = View.VISIBLE
                            Toast.makeText(this, "조금 달라요! 다시 시도해 보세요 🐥", Toast.LENGTH_SHORT).show()
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
                                "잘 안 들렸어요. 다시 눌러서 또박또박 읽어 주세요!"
                            -1 -> "이 기기에서 음성인식을 쓸 수 없어요."
                            else -> "음성인식 오류($code). 다시 시도해 주세요."
                        }
                    }
                }
            )
        }
        btnSkip.setOnClickListener {
            recordSkill(q, false)
            session?.submitNoPenalty(false)
            showFeedback(false, "괜찮아요! 다음에 말해 봐요. 정답 문장: ${q.en}", q.explain, penalty = false)
        }
    }

    // ---------------- 수학 ----------------

    private fun showMath(q: Question.Math) {
        val v = inflate(R.layout.view_q_math)
        v.findViewById<TextView>(R.id.txtPrompt).text = q.prompt
        v.findViewById<TextView>(R.id.txtKind).text = when (q.visual?.kind) {
            com.piyak.english.model.MathVisual.CLOCK -> "🕐 시계 보기"
            com.piyak.english.model.MathVisual.SHAPES -> "🔺 도형"
            com.piyak.english.model.MathVisual.FRACTION -> "🍰 분수"
            com.piyak.english.model.MathVisual.BAR_GRAPH -> "📊 그래프"
            com.piyak.english.model.MathVisual.NUMBER_LINE -> "📏 수직선"
            com.piyak.english.model.MathVisual.ANGLE -> "📐 각도"
            // 배열 그림은 곱셈·나눗셈에 모두 쓰인다 — 문제 기호로 구분한다
            com.piyak.english.model.MathVisual.ARRAY ->
                if (q.prompt.contains("÷")) "➗ 나눗셈" else "✖️ 곱셈"
            com.piyak.english.model.MathVisual.EMOJI_OP ->
                if (q.prompt.contains("-")) "➖ 빼기" else "➕ 더하기"
            null -> "🔢 수학"
            else -> "🐥 그림 문제"
        }

        val visualView = v.findViewById<MathVisualView>(R.id.visual)
        if (q.visual != null) visualView.visual = q.visual else visualView.visibility = View.GONE

        // 그림을 손가락으로 하나씩 짚어 셀 수 있게 (정지 그림을 보기만 하는 것과 다르다)
        if (q.visual != null && visualView.countable) {
            val countBox = v.findViewById<LinearLayout>(R.id.countBox)
            val txtCount = v.findViewById<TextView>(R.id.txtCount)
            countBox.visibility = View.VISIBLE
            visualView.onCountChanged = { n ->
                txtCount.text = if (n == 0) "👆 그림을 하나씩 짚어 세어 보세요"
                else "👆 지금까지 $n 개 세었어요"
                if (n > 0) sfx.piyak()
            }
            v.findViewById<Button>(R.id.btnCountReset).setOnClickListener {
                visualView.clearCount()
            }
        }

        // 한국어로 문제를 읽어 준다 (아이용)
        val sayBtn = v.findViewById<Button>(R.id.btnSay)
        sayBtn.setOnClickListener { speakKorean(q.prompt) }
        @Suppress("KotlinConstantConditions")
        if (autoReadMath) b.root.postDelayed({ speakKorean(q.prompt) }, 350)

        when (q.input) {
            // 숫자 보기는 대부분 짧으니 버블로 (만지는 재미)
            "choice" -> if (com.piyak.english.ui.game.BubbleChoiceView.fits(q.choices)) {
                val grid = v.findViewById<android.widget.GridLayout>(R.id.choicesGrid)
                grid.visibility = View.VISIBLE
                val bubbles = com.piyak.english.ui.game.BubbleChoiceView(this).apply {
                    layoutParams = android.widget.GridLayout.LayoutParams().apply {
                        width = android.widget.GridLayout.LayoutParams.MATCH_PARENT
                        height = dp(280)
                        columnSpec = android.widget.GridLayout.spec(0, 2)
                    }
                }
                var selected = -1
                bubbles.onPick = { selected = it; sfx.piyak(); b.btnCheck.isEnabled = true }
                bubbles.setChoices(q.choices)
                grid.addView(bubbles)
                checkAction = {
                    val ok = selected == q.answerIndex
                    bubbles.reveal(q.answerIndex)
                    bubbles.lock()
                    submitAnswer(ok, if (ok) null else "정답: ${q.choices.getOrNull(q.answerIndex)}", q.explain)
                }
            } else {
                val grid = v.findViewById<android.widget.GridLayout>(R.id.choicesGrid)
                grid.visibility = View.VISIBLE
                var selected = -1
                val buttons = ArrayList<Button>()
                q.choices.forEachIndexed { i, c ->
                    val btn = Button(this).apply {
                        text = c
                        textSize = 19f
                        isAllCaps = false
                        setTextColor(Color.parseColor("#4E342E"))
                        backgroundTintList = ColorStateList.valueOf(Color.WHITE)
                        layoutParams = android.widget.GridLayout.LayoutParams().apply {
                            width = 0
                            height = dp(76)
                            columnSpec = android.widget.GridLayout.spec(
                                android.widget.GridLayout.UNDEFINED, 1f
                            )
                            setMargins(dp(5), dp(5), dp(5), dp(5))
                        }
                        setOnClickListener {
                            selected = i
                            buttons.forEach {
                                it.backgroundTintList = ColorStateList.valueOf(Color.WHITE)
                            }
                            backgroundTintList = ColorStateList.valueOf(Color.parseColor("#FFD54F"))
                            b.btnCheck.isEnabled = true
                        }
                    }
                    buttons.add(btn)
                    grid.addView(btn)
                }
                choiceButtons = buttons
                choiceAnswer = q.answerIndex
                checkAction = {
                    val ok = selected == q.answerIndex
                    submitAnswer(ok, if (ok) null else "정답: ${q.choices.getOrNull(q.answerIndex)}", q.explain)
                }
            }
            "text" -> {
                val edit = v.findViewById<EditText>(R.id.editAnswer)
                edit.visibility = View.VISIBLE
                edit.addTextChangedListener(SimpleWatcher { b.btnCheck.isEnabled = it.isNotBlank() })
                checkAction = {
                    val ok = com.piyak.english.engine.MathGrader.grade(
                        edit.text.toString(), q.answer, q.alts
                    )
                    submitAnswer(ok, if (ok) null else "정답: ${q.answer}", q.explain)
                }
            }
            // 저학년은 키패드 대신 버블을 탭한다 (자판을 치는 것보다 만지는 재미가 크다)
            else -> if (useBubbleForNumber(q)) {
                val grid = v.findViewById<android.widget.GridLayout>(R.id.choicesGrid)
                grid.visibility = View.VISIBLE
                val opts = com.piyak.english.engine.MiniGames
                    .wrongNumbers(q.answer.toInt(), 4)
                    .map { it.toString() }
                val answerIdx = opts.indexOf(q.answer.toInt().toString())
                val bubbles = com.piyak.english.ui.game.BubbleChoiceView(this).apply {
                    layoutParams = android.widget.GridLayout.LayoutParams().apply {
                        width = android.widget.GridLayout.LayoutParams.MATCH_PARENT
                        height = dp(280)
                        columnSpec = android.widget.GridLayout.spec(0, 2)
                    }
                }
                var selected = -1
                bubbles.onPick = { selected = it; sfx.piyak(); b.btnCheck.isEnabled = true }
                bubbles.setChoices(opts)
                grid.addView(bubbles)
                checkAction = {
                    val ok = selected == answerIdx
                    bubbles.reveal(answerIdx)
                    bubbles.lock()
                    val shown = q.answer + if (q.unit.isNotEmpty()) " ${q.unit}" else ""
                    submitAnswer(ok, if (ok) null else "정답: $shown", q.explain)
                }
            } else {
                val box = v.findViewById<LinearLayout>(R.id.numberBox)
                box.visibility = View.VISIBLE
                val show = v.findViewById<TextView>(R.id.txtAnswer)
                val pad = v.findViewById<NumberPadView>(R.id.numberPad)
                pad.allowFraction = q.answer.contains("/")
                pad.allowMinus = q.answer.startsWith("-") || q.alts.any { it.startsWith("-") }
                pad.allowDecimal = q.answer.contains(".") || q.alts.any { it.contains(".") }
                pad.onChange = { s ->
                    show.text = if (s.isEmpty()) "" else s + (if (q.unit.isNotEmpty()) " ${q.unit}" else "")
                    b.btnCheck.isEnabled = s.isNotEmpty()
                }
                checkAction = {
                    val ok = com.piyak.english.engine.MathGrader.grade(pad.value, q.answer, q.alts)
                    val shown = q.answer + if (q.unit.isNotEmpty()) " ${q.unit}" else ""
                    submitAnswer(ok, if (ok) null else "정답: $shown", q.explain)
                }
            }
        }
    }

    /**
     * 숫자 답 문제를 버블로 낼지 결정한다.
     * 유치원~초3 은 자판을 치는 것보다 만지는 편이 재미도 학습도 낫고,
     * 초4 이상은 직접 계산해 써 보는 게 중요하므로 키패드를 유지한다.
     */
    private fun useBubbleForNumber(q: Question.Math): Boolean {
        val lowGrade = trackId in setOf("math_k", "math_g1", "math_g2", "math_g3")
        if (!lowGrade) return false
        val n = q.answer.toIntOrNull() ?: return false   // 분수·소수는 키패드로
        return n in 0..200 && q.unit.isEmpty()
    }

    /** 한국어 TTS (수학 문제 읽어주기) */
    private fun speakKorean(s: String) {
        tts.speakKo(s.replace("___", "몇"))
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
                correct && cleared -> "이 오답은 완전히 클리어! 💊✨"
                correct -> "좋아요! 한 번 더 맞히면 클리어!"
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
        showScratch(false)   // 채점 결과를 가리지 않도록 연습장을 접는다
        b.btnCheck.visibility = View.GONE
        b.feedbackPanel.visibility = View.VISIBLE
        b.feedbackPanel.background = getDrawable(
            if (correct) R.drawable.bg_feedback_ok else R.drawable.bg_feedback_no
        )
        b.imgFeedback.setImageResource(if (correct) R.drawable.chick_happy else R.drawable.chick_sad)
        b.txtFeedback.text = if (correct) okLines.random() else noLines.random()
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
        b.txtHearts.text = if (reviewMode) "💊 복습" else "❤️ ${session?.hearts ?: 0}"
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
            b.imgResult.setImageResource(R.drawable.chick_sad)
            b.txtResultTitle.text = "하트가 다 떨어졌어요 💔"
            b.txtResultStats.text = "오답 복습으로 하트를 채우고\n다시 도전해 봐요!"
            db.setHearts(0)
            return
        }

        sfx.done()
        b.imgResult.setImageResource(R.drawable.chick_happy)
        val xp = s.xpEarned()
        var coins = 0
        if (reviewMode) {
            val h = (db.hearts() + 1).coerceAtMost(db.maxHearts())
            db.setHearts(h)
            db.addXp(xp)
            db.markToday()
            // 복습 보너스는 하루 한도까지만 (파밍 방지)
            if (db.bonusCountToday("review") < Wallet.REVIEW_DAILY_LIMIT) {
                coins = db.earnCoins(Wallet.REVIEW_BONUS, "REVIEW", "오답 복습 완료")
                db.addBonusCountToday("review")
            }
            b.txtResultTitle.text = "복습 완료! 💊"
            b.txtResultStats.text = "정답률 ${(s.accuracy * 100).toInt()}% · +${xp} XP\n하트 1개 회복! ❤️ $h"
        } else {
            db.setHearts(s.hearts)
            db.addXp(xp)
            // 코인은 이 레슨을 "처음" 깰 때만 — 다시 풀어도 0원이라 반복 파밍이 안 된다
            val firstClear = db.lessonStars(lessonId) == 0
            db.completeLesson(lessonId, trackId, s.stars(), s.accuracy)
            if (s.isPerfect) db.setMeta("perfect_count", (db.metaInt("perfect_count") + 1).toString())
            if (firstClear) {
                coins = db.earnCoins(
                    Wallet.lessonReward(s.firstTryCorrect, s.isPerfect), "LESSON",
                    "$lessonTitle (첫 시도 정답 ${s.firstTryCorrect}문제)"
                )
            }
            b.txtResultTitle.text = if (s.isPerfect) "퍼펙트! 💯" else "레슨 완료! 🎉"
            b.txtResultStats.text =
                "$lessonTitle\n${"⭐".repeat(s.stars())}\n정답률 ${(s.accuracy * 100).toInt()}% · +${xp} XP" +
                    if (s.isPerfect) " (퍼펙트 +5 포함)" else ""
        }
        if (coins > 0) {
            b.txtResultStats.append("\n\n💰 용돈 +${Wallet.format(coins)}  (지갑 ${Wallet.format(db.coins())})")
        } else if (!reviewMode) {
            b.txtResultStats.append("\n\n💰 이미 깬 레슨이라 용돈은 없어요")
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
                sb.append("\n\n🎉 ${st.def.emoji} ${st.def.title} 실력이 Lv.${st.level} 로 올랐어요!")
            }
        }
        val overall = com.piyak.english.engine.Skills.overallLevel(states)
        val rank = com.piyak.english.engine.Ranks.of(overall)
        if (startRank != null && rank.title != startRank!!.title) {
            sb.append("\n\n👑 칭호 승급! ${rank.emoji} ${rank.title}")
        }
        val goal = db.dailyGoal()
        val todayXp = db.xpToday()
        sb.append("\n\n🎯 오늘의 목표 $todayXp / $goal XP")
        if (com.piyak.english.engine.DailyGoal.isDone(todayXp, goal)) {
            sb.append("  ✅ 달성!")
            // 목표 달성은 하루 한 번만 집계 + 용돈 보너스
            if (db.metaLong("goal_met_day", -1) != Db.today()) {
                db.setMeta("goal_met_day", Db.today().toString())
                db.setMeta("goals_met", (db.metaInt("goals_met") + 1).toString())
                val bonus = db.earnCoins(Wallet.DAILY_GOAL_BONUS, "GOAL", "오늘의 목표 달성")
                if (bonus > 0) sb.append("\n💰 목표 달성 보너스 +${Wallet.format(bonus)}")
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
            Toast.makeText(this, "🏆 배지 획득: ${bd.emoji} ${bd.title}!", Toast.LENGTH_LONG).show()
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
