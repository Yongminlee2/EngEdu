package com.piyak.english.ui

import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.piyak.english.db.Db
import com.piyak.english.model.ContentRepo

/**
 * 단계(연령) 선택 후 들어오는 화면 — 그 단계의 코스들만 조용히 보여준다.
 *
 * 홈에 트랙 10개가 다 쏟아져 "고르다 지치는" 문제를 풀기 위한 중간층.
 * 기초 코스(10레벨)는 레벨이 곧 학년이라, 학년 카드가 레벨 필터로 연결된다
 * (초1~2 = Lv.1 … 고급 = Lv.10 — Placement.LEVEL_NAMES 와 같은 매핑).
 */
class StageActivity : AppCompatActivity() {

    /** 카드 한 장: 이모지, 제목, 부제, 눌렀을 때 (트랙 id, 레벨범위) 또는 특수 화면 */
    private data class Entry(
        val emoji: String, val title: String, val sub: String,
        val color: String,
        val track: String? = null, val lvMin: Int = 0, val lvMax: Int = 99,
        val special: String? = null,   // "alphabet" | "playground"
        /** codex 일러스트 이름 — 비어 있으면 이모지로 그린다 */
        val art: String = "",
    )

    private fun entriesFor(stage: String): Pair<String, List<Entry>> = when (stage) {
        "kinder" -> "🐣 유치원 영어" to listOf(
            Entry("✏️", "알파벳 쓰기", "A부터 Z까지 손으로 그려요", "#FFF3D6", special = "alphabet", art = "ck_write"),
            Entry("🐣", "초등영어 첫걸음", "파닉스 · 그림낱말 · 문장", "#E8F6EA", track = "elem", art = "stage_kinder"),
            Entry("🎠", "놀이터", "풍선 터뜨리기 · 담기 · 선 잇기", "#E3F4FD", special = "playground", art = "scene_park"),
        )
        "elementary" -> "📗 초등 영어" to listOf(
            Entry("🐣", "초등영어 코스", "알파벳부터 문장까지 놀면서", "#E8F6EA", track = "elem", art = "stage_elementary"),
            Entry("1️⃣", "기초 · 초등 1~2학년", "첫 단어와 인사", "#FFF3D6", track = "basic", lvMin = 1, lvMax = 1, art = "scene_greeting"),
            Entry("3️⃣", "기초 · 초등 3~4학년", "일상 단어와 짧은 문장", "#FFE9CF", track = "basic", lvMin = 2, lvMax = 2, art = "scene_home"),
            Entry("5️⃣", "기초 · 초등 5~6학년", "문장 만들기가 익숙해져요", "#FDE2E2", track = "basic", lvMin = 3, lvMax = 3, art = "word_pencil"),
        )
        "middle" -> "📘 중등 · 고등 영어" to listOf(
            Entry("🌱", "기초 · 중학 1학년", "", "#E8F6EA", track = "basic", lvMin = 4, lvMax = 4, art = "scene_school"),
            Entry("🌿", "기초 · 중학 2학년", "", "#DFF2E5", track = "basic", lvMin = 5, lvMax = 5, art = "word_book"),
            Entry("🍀", "기초 · 중학 3학년", "", "#D5EEDC", track = "basic", lvMin = 6, lvMax = 6, art = "ck_think"),
            Entry("🌳", "기초 · 고등 1학년", "", "#E3F4FD", track = "basic", lvMin = 7, lvMax = 7, art = "word_test"),
            Entry("🌲", "기초 · 고등 2~3학년", "", "#DBEEFB", track = "basic", lvMin = 8, lvMax = 8, art = "word_graduate"),
            Entry("📖", "문법 집중", "규칙을 확실하게", "#F3EDFB", track = "grammar", art = "ck_book"),
            Entry("📚", "독해 집중", "지문 읽고 답하기", "#EFE6FA", track = "reading", art = "scene_library"),
        )
        "adult" -> "✈️ 성인 · 실전 영어" to listOf(
            Entry("💼", "기초 · 성인 중급", "", "#FFF3D6", track = "basic", lvMin = 9, lvMax = 9, art = "scene_office"),
            Entry("🎓", "기초 · 고급", "", "#FFE9CF", track = "basic", lvMin = 10, lvMax = 10, art = "word_graduate"),
            Entry("✈️", "일상 · 여행 회화", "혼자 여행 가서 써먹기", "#E3F4FD", track = "daily", art = "scene_travel"),
            Entry("📊", "토익", "파트별 실전 연습", "#E8F6EA", track = "toeic", art = "word_test"),
            Entry("🏛", "토플", "아카데믹 영어", "#F3EDFB", track = "toefl", art = "scene_school"),
        )
        else -> "🎯 영역별 훈련" to listOf(
            Entry("🎧", "듣기", "귀가 뚫리는 연습", "#E3F4FD", track = "listening", art = "ck_listen"),
            Entry("🎤", "말하기", "소리 내어 따라 하기", "#FDE2E2", track = "speaking", art = "ck_speak"),
            Entry("✍️", "쓰기", "받아쓰기와 영작", "#E8F6EA", track = "writing", art = "ck_write"),
            Entry("📖", "문법", "규칙 다지기", "#F3EDFB", track = "grammar", art = "ck_book"),
            Entry("📚", "독해", "읽고 이해하기", "#FFF3D6", track = "reading", art = "scene_library"),
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val stage = intent.getStringExtra("stage") ?: "skills"
        val (title, entries) = entriesFor(stage)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(10), dp(16), dp(24))
            setBackgroundColor(Color.parseColor(Db.get(this@StageActivity).themeColor()))
        }

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(Button(this).apply {
            text = "◀"
            minWidth = 0; minimumWidth = 0
            background = null
            textSize = 20f
            setOnClickListener { finish() }
        })
        header.addView(TextView(this).apply {
            text = title
            textSize = 21f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            setTextColor(Color.parseColor("#4E342E"))
        })
        root.addView(header)

        // 단계 대표 일러스트 (발주서 #04) — 화면의 얼굴
        val hero = resources.getIdentifier("stage_$stage", "drawable", packageName)
        if (hero != 0) root.addView(android.widget.ImageView(this).apply {
            setImageResource(hero)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(132)
            ).apply { topMargin = dp(2); bottomMargin = dp(4) }
        })

        val db = Db.get(this)
        val done = db.completedLessonIds()

        for (e in entries) {
            // 진행률: 트랙 전체 또는 학년(레벨) 범위만 센다
            var progress = ""
            if (e.track != null) {
                ContentRepo.track(this, e.track)?.let { t ->
                    val units = t.units.filter { it.level in e.lvMin..e.lvMax }
                    val total = units.sumOf { it.lessons.size }
                    val d = units.sumOf { u -> u.lessons.count { it.id in done } }
                    if (total > 0) progress = "$d / $total 레슨"
                }
            }

            val card = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(dp(18), dp(16), dp(16), dp(16))
                background = GradientDrawable().apply {
                    cornerRadius = dp(24).toFloat()
                    setColor(Color.WHITE)
                    setStroke(dp(3), Color.parseColor(darken(e.color)))
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { topMargin = dp(12) }
                setOnClickListener {
                    when (e.special) {
                        "alphabet" -> startActivity(Intent(this@StageActivity, AlphabetActivity::class.java))
                        "playground" -> startActivity(
                            Intent(this@StageActivity, PlaygroundActivity::class.java)
                                .putExtra("subject", "english")
                        )
                        else -> startActivity(
                            Intent(this@StageActivity, TrackActivity::class.java)
                                .putExtra("track", e.track)
                                .putExtra("lvMin", e.lvMin)
                                .putExtra("lvMax", e.lvMax)
                                .putExtra("stageTitle", e.title)
                        )
                    }
                }
            }
            // 동그라미 안에 일러스트 (없는 것만 이모지)
            val artId = if (e.art.isEmpty()) 0
                else resources.getIdentifier(e.art, "drawable", packageName)
            if (artId != 0) card.addView(android.widget.ImageView(this).apply {
                setImageResource(artId)
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor(e.color))
                }
                val pad = dp(4)
                setPadding(pad, pad, pad, pad)
                layoutParams = LinearLayout.LayoutParams(dp(64), dp(64))
            }) else card.addView(TextView(this).apply {
                text = e.emoji
                textSize = 26f
                gravity = Gravity.CENTER
                background = GradientDrawable().apply {
                    shape = GradientDrawable.OVAL
                    setColor(Color.parseColor(e.color))
                }
                layoutParams = LinearLayout.LayoutParams(dp(54), dp(54))
            })
            val col = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                setPadding(dp(14), 0, 0, 0)
            }
            col.addView(TextView(this).apply {
                text = e.title
                textSize = 17f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(Color.parseColor("#4E342E"))
            })
            val subLine = listOf(e.sub, progress).filter { it.isNotEmpty() }.joinToString("  ·  ")
            if (subLine.isNotEmpty()) col.addView(TextView(this).apply {
                text = subLine
                textSize = 13f
                setTextColor(Color.parseColor("#8D6E63"))
            })
            card.addView(col)
            card.addView(TextView(this).apply { text = "▶"; textSize = 16f; setTextColor(Color.parseColor("#C9A25E")) })
            root.addView(card)
        }

        setContentView(ScrollView(this).apply { addView(root); isFillViewport = true })
    }

    /** 테두리용 — 파스텔을 살짝 진하게 */
    private fun darken(hex: String): String {
        val c = Color.parseColor(hex)
        fun d(v: Int) = (v * 0.82f).toInt().coerceAtLeast(0)
        return String.format("#%02X%02X%02X", d(Color.red(c)), d(Color.green(c)), d(Color.blue(c)))
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
}
