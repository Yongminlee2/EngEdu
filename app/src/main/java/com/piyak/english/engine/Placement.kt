package com.piyak.english.engine

import com.piyak.english.R

/** 배치고사(레벨테스트) 적응형 사다리 — 순수 로직 */
object Placement {
    const val TOTAL = 25
    const val START_LEVEL = 3

    /** 영어는 10단계, 수학은 학년 13단계 */
    const val MAX_LEVEL_ENGLISH = 10
    const val MAX_LEVEL_MATH = 13

    // 레벨 이름은 문자열 리소스 id — 폰 언어를 따라간다
    val LEVEL_NAMES = mapOf(
        1 to R.string.lv_1, 2 to R.string.lv_2, 3 to R.string.lv_3,
        4 to R.string.lv_4, 5 to R.string.lv_5, 6 to R.string.lv_6,
        7 to R.string.lv_7, 8 to R.string.lv_8, 9 to R.string.lv_9, 10 to R.string.lv_10,
    )

    fun maxLevel(subject: com.piyak.english.model.Subject): Int =
        if (subject == com.piyak.english.model.Subject.MATH) MAX_LEVEL_MATH else MAX_LEVEL_ENGLISH

    /** 레벨 이름 — 리소스라 Context 가 필요하다 (수학 학년명은 이 앱에선 죽은 경로) */
    fun levelName(ctx: android.content.Context, subject: com.piyak.english.model.Subject, level: Int): String =
        if (subject == com.piyak.english.model.Subject.MATH)
            com.piyak.english.model.MathGrades.forLevel(level).title
        else LEVEL_NAMES[level]?.let { ctx.getString(it) } ?: "?"

    /** 진행도 저장 키 (과목별로 따로 기억한다) */
    fun levelKey(subject: com.piyak.english.model.Subject): String =
        if (subject == com.piyak.english.model.Subject.MATH) "math_placement_level" else "placement_level"

    fun doneKey(subject: com.piyak.english.model.Subject): String =
        if (subject == com.piyak.english.model.Subject.MATH) "math_placement_done" else "placement_done"

    /** 맞으면 +1, 틀리면 -1 (과목의 최대 단계까지) */
    fun nextLevel(cur: Int, correct: Boolean, max: Int = MAX_LEVEL_ENGLISH): Int =
        (if (correct) cur + 1 else cur - 1).coerceIn(1, max)

    /** 최종 배치: 최근 10문항의 출제 레벨 중앙값 */
    fun placeLevel(history: List<Pair<Int, Boolean>>): Int {
        if (history.isEmpty()) return 1
        val recent = history.takeLast(10).map { it.first }.sorted()
        return recent[recent.size / 2]
    }
}
