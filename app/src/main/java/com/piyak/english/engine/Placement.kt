package com.piyak.english.engine

/** 배치고사(레벨테스트) 적응형 사다리 — 순수 로직 */
object Placement {
    const val TOTAL = 25
    const val START_LEVEL = 3

    /** 영어는 10단계, 수학은 학년 13단계 */
    const val MAX_LEVEL_ENGLISH = 10
    const val MAX_LEVEL_MATH = 13

    val LEVEL_NAMES = mapOf(
        1 to "초등 1~2학년", 2 to "초등 3~4학년", 3 to "초등 5~6학년",
        4 to "중학 1학년", 5 to "중학 2학년", 6 to "중학 3학년",
        7 to "고등 1학년", 8 to "고등 2~3학년", 9 to "성인·토익 중급", 10 to "고급·토플",
    )

    fun maxLevel(subject: com.piyak.english.model.Subject): Int =
        if (subject == com.piyak.english.model.Subject.MATH) MAX_LEVEL_MATH else MAX_LEVEL_ENGLISH

    /** 수학은 학년 이름을 그대로 쓴다 */
    fun levelName(subject: com.piyak.english.model.Subject, level: Int): String =
        if (subject == com.piyak.english.model.Subject.MATH)
            com.piyak.english.model.MathGrades.forLevel(level).title
        else LEVEL_NAMES[level] ?: "?"

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
