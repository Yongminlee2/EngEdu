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
import com.piyak.english.R
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
        val emoji: String, val title: Int, val sub: Int,
        val color: String,
        val track: String? = null, val lvMin: Int = 0, val lvMax: Int = 99,
        val special: String? = null,   // "alphabet" | "playground"
        /** codex 일러스트 이름 — 비어 있으면 이모지로 그린다 */
        val art: String = "",
    )

    private fun entriesFor(stage: String): Pair<String, List<Entry>> = when (stage) {
        "kinder" -> "🐣 " + getString(R.string.stage_kinder) to listOf(
            Entry("✏️", R.string.st_alpha, R.string.st_alpha_sub, "#FFF3D6", special = "alphabet", art = "ck_write"),
            Entry("🐣", R.string.st_first, R.string.st_first_sub, "#E8F6EA", track = "elem", art = "stage_kinder"),
            Entry("🎠", R.string.st_play, R.string.st_play_sub, "#E3F4FD", special = "playground", art = "scene_park"),
        )
        "elementary" -> "📗 " + getString(R.string.stage_elem) to listOf(
            Entry("🐣", R.string.st_elem_course, R.string.st_elem_course_sub, "#E8F6EA", track = "elem", art = "stage_elementary"),
            Entry("1️⃣", R.string.st_g12, R.string.st_g12_sub, "#FFF3D6", track = "basic", lvMin = 1, lvMax = 1, art = "scene_greeting"),
            Entry("3️⃣", R.string.st_g34, R.string.st_g34_sub, "#FFE9CF", track = "basic", lvMin = 2, lvMax = 2, art = "scene_home"),
            Entry("5️⃣", R.string.st_g56, R.string.st_g56_sub, "#FDE2E2", track = "basic", lvMin = 3, lvMax = 3, art = "word_pencil"),
        )
        "middle" -> "📘 " + getString(R.string.stage_middle) to listOf(
            Entry("🌱", R.string.st_m1, 0, "#E8F6EA", track = "basic", lvMin = 4, lvMax = 4, art = "scene_school"),
            Entry("🌿", R.string.st_m2, 0, "#DFF2E5", track = "basic", lvMin = 5, lvMax = 5, art = "word_book"),
            Entry("🍀", R.string.st_m3, 0, "#D5EEDC", track = "basic", lvMin = 6, lvMax = 6, art = "ck_think"),
            Entry("🌳", R.string.st_h1, 0, "#E3F4FD", track = "basic", lvMin = 7, lvMax = 7, art = "word_test"),
            Entry("🌲", R.string.st_h23, 0, "#DBEEFB", track = "basic", lvMin = 8, lvMax = 8, art = "word_graduate"),
            Entry("📖", R.string.st_grammar, R.string.st_grammar_sub, "#F3EDFB", track = "grammar", art = "ck_book"),
            Entry("📚", R.string.st_reading, R.string.st_reading_sub, "#EFE6FA", track = "reading", art = "scene_library"),
        )
        "adult" -> "✈️ " + getString(R.string.stage_adult) to listOf(
            Entry("💼", R.string.st_adult_mid, 0, "#FFF3D6", track = "basic", lvMin = 9, lvMax = 9, art = "scene_office"),
            Entry("🎓", R.string.st_adult_adv, 0, "#FFE9CF", track = "basic", lvMin = 10, lvMax = 10, art = "word_graduate"),
            Entry("✈️", R.string.st_travel, R.string.st_travel_sub, "#E3F4FD", track = "daily", art = "scene_travel"),
            Entry("📊", R.string.st_toeic, R.string.st_toeic_sub, "#E8F6EA", track = "toeic", art = "word_test"),
            Entry("🏛", R.string.st_toefl, R.string.st_toefl_sub, "#F3EDFB", track = "toefl", art = "scene_school"),
        )
        else -> "🎯 " + getString(R.string.stage_skills) to listOf(
            Entry("🎧", R.string.sk_listen, R.string.st_listen_sub, "#E3F4FD", track = "listening", art = "ck_listen"),
            Entry("🎤", R.string.sk_speak, R.string.st_speak_sub, "#FDE2E2", track = "speaking", art = "ck_speak"),
            Entry("✍️", R.string.sk_write, R.string.st_write_sub, "#E8F6EA", track = "writing", art = "ck_write"),
            Entry("📖", R.string.sk_grammar, R.string.st_gram_sub, "#F3EDFB", track = "grammar", art = "ck_book"),
            Entry("📚", R.string.sk_read, R.string.st_read_sub, "#FFF3D6", track = "reading", art = "scene_library"),
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
            // 둥실둥실 떠 있는 느낌
            android.animation.ObjectAnimator.ofFloat(
                this, android.view.View.TRANSLATION_Y, 0f, dp(7).toFloat()
            ).apply {
                duration = 1700L
                repeatCount = android.animation.ValueAnimator.INFINITE
                repeatMode = android.animation.ValueAnimator.REVERSE
                interpolator = android.view.animation.AccelerateDecelerateInterpolator()
                start()
            }
        })

        val db = Db.get(this)
        val done = db.completedLessonIds()

        for (e in entries) {
            // 진행률: 트랙 전체 또는 학년(레벨) 범위만 센다
            var progress = ""
            var lessonTotal = -1
            if (e.track != null) {
                ContentRepo.track(this, e.track)?.let { t ->
                    val units = t.units.filter { it.level in e.lvMin..e.lvMax }
                    val total = units.sumOf { it.lessons.size }
                    lessonTotal = total
                    val d = units.sumOf { u -> u.lessons.count { it.id in done } }
                    if (total > 0) progress = getString(R.string.stage_progress, d, total)
                }
            }
            // 비한국어 폰: 걸러져서 풀 문제가 하나도 없는 트랙 카드는 숨긴다 (예: 한국어 독해)
            if (!com.piyak.english.i18n.Tpl.isKorean && lessonTotal == 0) continue

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
                                .putExtra("stageTitle", getString(e.title))
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
                text = getString(e.title)
                textSize = 17f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                setTextColor(Color.parseColor("#4E342E"))
            })
            val subLine = listOf(if (e.sub != 0) getString(e.sub) else "", progress)
                .filter { it.isNotEmpty() }.joinToString("  ·  ")
            if (subLine.isNotEmpty()) col.addView(TextView(this).apply {
                text = subLine
                textSize = 13f
                setTextColor(Color.parseColor("#8D6E63"))
            })
            card.addView(col)
            card.addView(TextView(this).apply {
                text = "▶"; textSize = 16f; setTextColor(Color.parseColor("#C9A25E"))
                setPadding(dp(8), 0, 0, 0)   // 긴 번역 부제와 맞붙지 않게
            })
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
