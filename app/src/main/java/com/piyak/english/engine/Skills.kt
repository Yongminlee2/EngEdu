package com.piyak.english.engine

import kotlin.math.min

/** 실력 영역 정의 (홈 대시보드의 여섯 줄) */
data class SkillDef(val id: String, val emoji: String, val title: String, val color: String)

/** 한 영역의 현재 상태 */
data class SkillState(
    val def: SkillDef,
    val correct: Int,
    val attempts: Int,
) {
    val level: Int get() = Skills.levelFor(correct)
    /** 다음 레벨까지 진행률 0~1 */
    val progress: Float get() = Skills.progressFor(correct)
    /** 정답률 0~100 (시도 없으면 0) */
    val accuracy: Int get() = if (attempts == 0) 0 else correct * 100 / attempts
    val nextLevelNeed: Int get() = (Skills.correctForLevel(level + 1) - correct).coerceAtLeast(0)
}

object Skills {
    const val MAX_LEVEL = 10

    val ALL = listOf(
        SkillDef("listening", "🎧", "듣기", "#AEE3F0"),
        SkillDef("speaking", "🎤", "말하기", "#F7C6C7"),
        SkillDef("writing", "✍️", "쓰기", "#CFE8B8"),
        SkillDef("grammar", "📖", "문법", "#F3D7B0"),
        SkillDef("reading", "📚", "독해", "#D8CBF0"),
        SkillDef("vocab", "🔤", "어휘", "#FFE082"),
    )

    fun def(id: String): SkillDef = ALL.firstOrNull { it.id == id } ?: ALL.last()

    /** 레벨 n 도달에 필요한 누적 정답 수 = 10 * n(n+1)/2 (Lv1=10, Lv2=30, Lv3=60 … Lv10=550) */
    fun correctForLevel(n: Int): Int = 10 * n * (n + 1) / 2

    fun levelFor(correct: Int): Int {
        var n = 0
        while (n < MAX_LEVEL && correctForLevel(n + 1) <= correct) n++
        return n
    }

    fun progressFor(correct: Int): Float {
        val lv = levelFor(correct)
        if (lv >= MAX_LEVEL) return 1f
        val cur = correctForLevel(lv)
        val next = correctForLevel(lv + 1)
        return ((correct - cur).toFloat() / (next - cur)).coerceIn(0f, 1f)
    }

    /** 여섯 영역 레벨의 평균 = 종합 실력 레벨 (소수 첫째 자리) */
    fun overallLevel(states: List<SkillState>): Float {
        if (states.isEmpty()) return 0f
        return states.sumOf { it.level }.toFloat() / states.size
    }

    /** 가장 약한 영역 (연습 안 한 영역 우선) */
    fun weakest(states: List<SkillState>): SkillState? =
        states.minByOrNull { it.level * 1000 + it.correct }
}

/** 칭호: 종합 실력이 오를수록 병아리가 자란다 */
data class Rank(val emoji: String, val title: String, val minOverall: Float)

object Ranks {
    val ALL = listOf(
        Rank("🥚", "알 속의 새싹", 0f),
        Rank("🐣", "갓 깬 병아리", 0.7f),
        Rank("🐥", "삐약이", 1.5f),
        Rank("🐤", "씩씩한 병아리", 2.5f),
        Rank("🐦", "재잘재잘 참새", 3.5f),
        Rank("🕊️", "자유로운 비둘기", 4.5f),
        Rank("🦜", "수다쟁이 앵무새", 5.5f),
        Rank("🦉", "지혜로운 부엉이", 6.5f),
        Rank("🦅", "하늘의 독수리", 7.5f),
        Rank("👑", "영어 마스터", 9f),
    )

    fun of(overall: Float): Rank = ALL.last { overall >= it.minOverall }

    /** 다음 칭호 (최고면 null) */
    fun next(overall: Float): Rank? = ALL.firstOrNull { it.minOverall > overall }

    /** 현재 칭호에서 다음 칭호까지 진행률 0~1 */
    fun progress(overall: Float): Float {
        val cur = of(overall)
        val nxt = next(overall) ?: return 1f
        return ((overall - cur.minOverall) / (nxt.minOverall - cur.minOverall)).coerceIn(0f, 1f)
    }
}

/** 오늘의 목표 */
object DailyGoal {
    val OPTIONS = listOf(20, 50, 100, 200)
    const val DEFAULT = 50

    fun progress(todayXp: Int, goal: Int): Float =
        if (goal <= 0) 1f else min(1f, todayXp.toFloat() / goal)

    fun isDone(todayXp: Int, goal: Int): Boolean = todayXp >= goal
}
