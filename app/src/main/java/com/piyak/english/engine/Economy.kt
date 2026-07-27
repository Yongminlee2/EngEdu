package com.piyak.english.engine

import kotlin.math.min

/** XP 레벨·하트·스트릭 순수 계산 로직 */
object Economy {
    const val MAX_HEARTS = 5
    const val HEART_REFILL_MS = 30L * 60 * 1000 // 30분당 1개

    /** 레벨 n 도달에 필요한 누적 XP = 60 * n(n+1)/2  (레벨1=60, 2=180, 3=360…) */
    fun xpForLevel(n: Int): Int = 60 * n * (n + 1) / 2

    /** 현재 누적 XP 의 레벨 (0부터) */
    fun levelFor(xp: Int): Int {
        var n = 0
        while (xpForLevel(n + 1) <= xp) n++
        return n
    }

    /** 다음 레벨까지 진행률 0~1 */
    fun levelProgress(xp: Int): Float {
        val lv = levelFor(xp)
        val cur = xpForLevel(lv)
        val next = xpForLevel(lv + 1)
        return (xp - cur).toFloat() / (next - cur)
    }

    /**
     * 하트 자동 회복 계산.
     * @param saved 저장된 하트 수, @param savedAtDay 저장 시점의 epochDay, @param savedAt 저장 시각 ms
     * @return 현재 하트 수 (새 날이면 풀 회복, 아니면 30분당 1개)
     */
    fun heartsNow(
        saved: Int, savedAt: Long, savedAtDay: Long, now: Long, nowDay: Long,
        max: Int = MAX_HEARTS,
    ): Int {
        if (saved >= max) return max
        if (nowDay > savedAtDay) return max
        val refills = ((now - savedAt) / HEART_REFILL_MS).toInt()
        return min(max, saved + refills)
    }

    /**
     * 스트릭 계산. @param days 학습한 epochDay 집합, @param today 오늘 epochDay
     * @return (현재 스트릭, 최고 스트릭). 오늘 안 했어도 어제까지 이어졌으면 현재 스트릭 유지.
     */
    fun streak(days: Set<Long>, today: Long): Pair<Int, Int> {
        if (days.isEmpty()) return 0 to 0
        // 현재 스트릭: 오늘 또는 어제부터 뒤로 연속
        var cur = 0
        var d = if (today in days) today else today - 1
        while (d in days) { cur++; d-- }
        // 최고 스트릭
        var best = 0
        var run = 0
        var prev = Long.MIN_VALUE
        for (day in days.sorted()) {
            run = if (day == prev + 1) run + 1 else 1
            if (run > best) best = run
            prev = day
        }
        return cur to best
    }
}
