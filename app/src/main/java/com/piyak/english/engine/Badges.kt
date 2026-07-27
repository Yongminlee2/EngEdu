package com.piyak.english.engine

/** 배지 정의 + 획득 판정 (순수 로직) */
data class BadgeDef(val id: String, val emoji: String, val title: String, val desc: String)

data class StatsSnapshot(
    val lessonsDone: Int,
    val perfectCount: Int,
    val xp: Int,
    val streakBest: Int,
    val placementDone: Boolean,
    val reviewCleared: Int,
    val unitsCompleted: Map<String, Int>, // trackId → 완료 유닛 수
    val skillLevels: Map<String, Int> = emptyMap(), // 영역 id → 레벨
    val goalsMet: Int = 0, // 일일 목표 달성 횟수
)

object Badges {
    val ALL = listOf(
        BadgeDef("first_lesson", "🐣", "첫걸음", "첫 레슨 완료"),
        BadgeDef("lessons_10", "📚", "공부벌레", "레슨 10개 완료"),
        BadgeDef("lessons_50", "🎓", "모범생", "레슨 50개 완료"),
        BadgeDef("lessons_200", "👑", "영어왕", "레슨 200개 완료"),
        BadgeDef("perfect_10", "💯", "완벽주의", "퍼펙트 레슨 10회"),
        BadgeDef("streak_7", "🔥", "일주일 불꽃", "7일 연속 학습"),
        BadgeDef("streak_30", "🌋", "한달 화산", "30일 연속 학습"),
        BadgeDef("xp_1000", "⭐", "별 헤는 밤", "누적 XP 1,000"),
        BadgeDef("xp_5000", "🌟", "슈퍼스타", "누적 XP 5,000"),
        BadgeDef("placement", "🎯", "제자리 찾기", "레벨테스트 완료"),
        BadgeDef("review_50", "💊", "오답 청소부", "오답 50개 클리어"),
        BadgeDef("unit_master", "🏆", "유닛 정복자", "한 트랙의 유닛 5개 완료"),
        BadgeDef("goal_first", "🎯", "목표 달성", "오늘의 목표 첫 달성"),
        BadgeDef("goal_10", "🎪", "목표 사냥꾼", "일일 목표 10번 달성"),
        BadgeDef("ear_master", "🎧", "귀가 트였다", "듣기 실력 Lv.5"),
        BadgeDef("mouth_master", "🎤", "입이 트였다", "말하기 실력 Lv.5"),
        BadgeDef("hand_master", "✍️", "손이 풀렸다", "쓰기 실력 Lv.5"),
        BadgeDef("grammar_master", "📖", "문법 도사", "문법 실력 Lv.5"),
        BadgeDef("all_rounder", "🌈", "만능 삐약이", "영어 모든 영역 Lv.3 이상"),
        // 수학
        BadgeDef("m_calc_master", "➕", "계산왕", "수학 계산 실력 Lv.5"),
        BadgeDef("m_shape_master", "🔺", "도형 박사", "수학 도형 실력 Lv.5"),
        BadgeDef("m_word_master", "🧩", "문장제 해결사", "수학 문장제 실력 Lv.5"),
        BadgeDef("m_all_rounder", "🧮", "수학 만능", "수학 모든 영역 Lv.3 이상"),
        BadgeDef("both_subjects", "🎓", "두 과목 척척", "영어·수학 모두 Lv.3 이상 영역 보유"),
    )

    fun check(s: StatsSnapshot, already: Set<String>): List<BadgeDef> {
        val earned = ArrayList<BadgeDef>()
        fun give(id: String, cond: Boolean) {
            if (cond && id !in already) ALL.firstOrNull { it.id == id }?.let { earned.add(it) }
        }
        give("first_lesson", s.lessonsDone >= 1)
        give("lessons_10", s.lessonsDone >= 10)
        give("lessons_50", s.lessonsDone >= 50)
        give("lessons_200", s.lessonsDone >= 200)
        give("perfect_10", s.perfectCount >= 10)
        give("streak_7", s.streakBest >= 7)
        give("streak_30", s.streakBest >= 30)
        give("xp_1000", s.xp >= 1000)
        give("xp_5000", s.xp >= 5000)
        give("placement", s.placementDone)
        give("review_50", s.reviewCleared >= 50)
        give("unit_master", s.unitsCompleted.values.any { it >= 5 })
        give("goal_first", s.goalsMet >= 1)
        give("goal_10", s.goalsMet >= 10)
        give("ear_master", (s.skillLevels["listening"] ?: 0) >= 5)
        give("mouth_master", (s.skillLevels["speaking"] ?: 0) >= 5)
        give("hand_master", (s.skillLevels["writing"] ?: 0) >= 5)
        give("grammar_master", (s.skillLevels["grammar"] ?: 0) >= 5)
        give("all_rounder", Skills.ALL.all { (s.skillLevels[it.id] ?: 0) >= 3 })
        give("m_calc_master", (s.skillLevels["m_calc"] ?: 0) >= 5)
        give("m_shape_master", (s.skillLevels["m_shape"] ?: 0) >= 5)
        give("m_word_master", (s.skillLevels["m_word"] ?: 0) >= 5)
        give("m_all_rounder", Skills.MATH.all { (s.skillLevels[it.id] ?: 0) >= 3 })
        give(
            "both_subjects",
            Skills.ALL.any { (s.skillLevels[it.id] ?: 0) >= 3 } &&
                Skills.MATH.any { (s.skillLevels[it.id] ?: 0) >= 3 }
        )
        return earned
    }
}
