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

        b.btnClose.setOnClickListener { confirmQuit() }
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
        }
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
        var selected = -1
        val buttons = ArrayList<Button>()
        choices.forEachIndexed { i, c ->
            val btn = choiceButton(c)
            btn.setOnClickListener {
                selected = i
                buttons.forEach { it.backgroundTintList = ColorStateList.valueOf(Color.WHITE) }
                btn.backgroundTintList = ColorStateList.valueOf(Color.parseColor("#FFD54F"))
                b.btnCheck.isEnabled = true
            }
            buttons.add(btn)
            box.addView(btn)
        }
        checkAction = {
            val ok = selected == answer
            submitAnswer(ok, if (ok) null else "정답: $answerText", explain)
        }
    }

    private fun showMcq(q: Question.Mcq) {
        val v = inflate(R.layout.view_q_mcq)
        v.findViewById<TextView>(R.id.txtKind).text = if (q.passage != null) "📖 독해" else "🔤 고르기"
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

    private fun showMatch(q: Question.Match) {
        val v = inflate(R.layout.view_q_match)
        val leftCol = v.findViewById<LinearLayout>(R.id.leftCol)
        val rightCol = v.findViewById<LinearLayout>(R.id.rightCol)
        b.btnCheck.visibility = View.GONE

        var mistakes = 0
        var matched = 0
        var selLeft: Button? = null
        var selLeftIdx = -1
        val rightOrder = q.pairs.indices.shuffled()

        fun colBtn(text: String): Button = choiceButton(text).apply { textSize = 14f }

        val leftBtns = q.pairs.mapIndexed { i, p ->
            colBtn(p.first).also { btn ->
                btn.setOnClickListener {
                    selLeft?.backgroundTintList = ColorStateList.valueOf(Color.WHITE)
                    selLeft = btn; selLeftIdx = i
                    btn.backgroundTintList = ColorStateList.valueOf(Color.parseColor("#FFD54F"))
                }
                leftCol.addView(btn)
            }
        }
        for (ri in rightOrder) {
            val btn = colBtn(q.pairs[ri].second)
            btn.setOnClickListener {
                val l = selLeft ?: return@setOnClickListener
                if (ri == selLeftIdx) {
                    sfx.piyak()
                    l.isEnabled = false; btn.isEnabled = false
                    l.backgroundTintList = ColorStateList.valueOf(Color.parseColor("#C8E6C9"))
                    btn.backgroundTintList = ColorStateList.valueOf(Color.parseColor("#C8E6C9"))
                    selLeft = null; selLeftIdx = -1
                    matched++
                    if (matched == q.pairs.size) {
                        val ok = mistakes == 0
                        session?.submitNoPenalty(ok)
                        showFeedback(ok,
                            if (ok) null else "오터치 ${mistakes}번! 그래도 다 맞췄어요",
                            q.explain, penalty = false)
                    }
                } else {
                    mistakes++
                    sfx.wrong()
                    btn.backgroundTintList = ColorStateList.valueOf(Color.parseColor("#FFCDD2"))
                    btn.postDelayed({
                        if (btn.isEnabled) btn.backgroundTintList = ColorStateList.valueOf(Color.WHITE)
                    }, 400)
                }
            }
            rightCol.addView(btn)
        }
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
            session?.submitNoPenalty(false)
            showFeedback(false, "괜찮아요! 다음에 말해 봐요. 정답 문장: ${q.en}", q.explain, penalty = false)
        }
    }

    // ---------------- 채점·피드백 ----------------

    /** 일반 제출 (하트·재출제 규칙 적용) */
    private fun submitAnswer(correct: Boolean, note: String?, explain: String?) {
        val s = session ?: return
        val q = s.current() ?: return
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
        if (reviewMode) {
            val h = (db.hearts() + 1).coerceAtMost(Economy.MAX_HEARTS)
            db.setHearts(h)
            db.addXp(xp)
            db.markToday()
            b.txtResultTitle.text = "복습 완료! 💊"
            b.txtResultStats.text = "정답률 ${(s.accuracy * 100).toInt()}% · +${xp} XP\n하트 1개 회복! ❤️ $h"
        } else {
            db.setHearts(s.hearts)
            db.addXp(xp)
            db.completeLesson(lessonId, trackId, s.stars(), s.accuracy)
            if (s.isPerfect) db.setMeta("perfect_count", (db.metaInt("perfect_count") + 1).toString())
            b.txtResultTitle.text = if (s.isPerfect) "퍼펙트! 💯" else "레슨 완료! 🎉"
            b.txtResultStats.text =
                "$lessonTitle\n${"⭐".repeat(s.stars())}\n정답률 ${(s.accuracy * 100).toInt()}% · +${xp} XP" +
                    if (s.isPerfect) " (퍼펙트 +5 포함)" else ""
        }
        checkBadges()
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
