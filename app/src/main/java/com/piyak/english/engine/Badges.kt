package com.piyak.english.engine

import com.piyak.english.R

/** 배지 정의 + 획득 판정 (순수 로직) */
data class BadgeDef(val id: String, val emoji: String, val titleRes: Int, val descRes: Int)

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
        BadgeDef("first_lesson", "🐣", R.string.bg_first_lesson, R.string.bg_first_lesson_d),
        BadgeDef("lessons_10", "📚", R.string.bg_lessons_10, R.string.bg_lessons_10_d),
        BadgeDef("lessons_50", "🎓", R.string.bg_lessons_50, R.string.bg_lessons_50_d),
        BadgeDef("lessons_200", "👑", R.string.bg_lessons_200, R.string.bg_lessons_200_d),
        BadgeDef("perfect_10", "💯", R.string.bg_perfect_10, R.string.bg_perfect_10_d),
        BadgeDef("streak_7", "🔥", R.string.bg_streak_7, R.string.bg_streak_7_d),
        BadgeDef("streak_30", "🌋", R.string.bg_streak_30, R.string.bg_streak_30_d),
        BadgeDef("xp_1000", "⭐", R.string.bg_xp_1000, R.string.bg_xp_1000_d),
        BadgeDef("xp_5000", "🌟", R.string.bg_xp_5000, R.string.bg_xp_5000_d),
        BadgeDef("placement", "🎯", R.string.bg_placement, R.string.bg_placement_d),
        BadgeDef("review_50", "💊", R.string.bg_review_50, R.string.bg_review_50_d),
        BadgeDef("unit_master", "🏆", R.string.bg_unit_master, R.string.bg_unit_master_d),
        BadgeDef("goal_first", "🎯", R.string.bg_goal_first, R.string.bg_goal_first_d),
        BadgeDef("goal_10", "🎪", R.string.bg_goal_10, R.string.bg_goal_10_d),
        BadgeDef("ear_master", "🎧", R.string.bg_ear, R.string.bg_ear_d),
        BadgeDef("mouth_master", "🎤", R.string.bg_mouth, R.string.bg_mouth_d),
        BadgeDef("hand_master", "✍️", R.string.bg_hand, R.string.bg_hand_d),
        BadgeDef("grammar_master", "📖", R.string.bg_grammar, R.string.bg_grammar_d),
        BadgeDef("all_rounder", "🌈", R.string.bg_all, R.string.bg_all_d),
        // 수학
        BadgeDef("m_calc_master", "➕", R.string.bg_m_calc, R.string.bg_m_calc_d),
        BadgeDef("m_shape_master", "🔺", R.string.bg_m_shape, R.string.bg_m_shape_d),
        BadgeDef("m_word_master", "🧩", R.string.bg_m_word, R.string.bg_m_word_d),
        BadgeDef("m_all_rounder", "🧮", R.string.bg_m_all, R.string.bg_m_all_d),
        BadgeDef("both_subjects", "🎓", R.string.bg_both, R.string.bg_both_d),
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
