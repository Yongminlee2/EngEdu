package com.piyak.english.engine

/** 배치고사(레벨테스트) 적응형 사다리 — 순수 로직 */
object Placement {
    const val TOTAL = 25
    const val START_LEVEL = 3

    val LEVEL_NAMES = mapOf(
        1 to "초등 1~2학년", 2 to "초등 3~4학년", 3 to "초등 5~6학년",
        4 to "중학 1학년", 5 to "중학 2학년", 6 to "중학 3학년",
        7 to "고등 1학년", 8 to "고등 2~3학년", 9 to "성인·토익 중급", 10 to "고급·토플",
    )

    /** 맞으면 +1, 틀리면 -1 (1~10 클램프) */
    fun nextLevel(cur: Int, correct: Boolean): Int =
        (if (correct) cur + 1 else cur - 1).coerceIn(1, 10)

    /** 최종 배치: 최근 10문항의 출제 레벨 중앙값 */
    fun placeLevel(history: List<Pair<Int, Boolean>>): Int {
        if (history.isEmpty()) return 1
        val recent = history.takeLast(10).map { it.first }.sorted()
        return recent[recent.size / 2]
    }
}
