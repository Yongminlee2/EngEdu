package com.piyak.english

import com.piyak.english.engine.Economy
import com.piyak.english.engine.Placement
import org.junit.Assert.assertEquals
import org.junit.Test

class EconomyTest {

    @Test fun levels() {
        assertEquals(0, Economy.levelFor(0))
        assertEquals(0, Economy.levelFor(59))
        assertEquals(1, Economy.levelFor(60))
        assertEquals(1, Economy.levelFor(179))
        assertEquals(2, Economy.levelFor(180))
        assertEquals(60, Economy.xpForLevel(1))
        assertEquals(180, Economy.xpForLevel(2))
    }

    @Test fun heartsRefill30Min() {
        val base = 1_000_000L
        val day = 100L
        // 29분 → 회복 없음
        assertEquals(2, Economy.heartsNow(2, base, day, base + 29 * 60_000, day))
        // 30분 → +1
        assertEquals(3, Economy.heartsNow(2, base, day, base + 30 * 60_000, day))
        // 오래 지나도 최대 5
        assertEquals(5, Economy.heartsNow(2, base, day, base + 500 * 60_000, day))
        // 날짜가 바뀌면 풀 회복
        assertEquals(5, Economy.heartsNow(0, base, day, base + 60_000, day + 1))
    }

    @Test fun streakCurrentAndBest() {
        val today = 1000L
        // 오늘 포함 3일 연속, 과거에 5일 연속
        val days = setOf(today, today - 1, today - 2, today - 10, today - 11, today - 12, today - 13, today - 14)
        val (cur, best) = Economy.streak(days, today)
        assertEquals(3, cur)
        assertEquals(5, best)
    }

    @Test fun streakYesterdayStillCounts() {
        val today = 1000L
        val (cur, _) = Economy.streak(setOf(today - 1, today - 2), today)
        assertEquals(2, cur) // 오늘 아직 안 했어도 유지
        val (cur2, _) = Economy.streak(setOf(today - 2, today - 3), today)
        assertEquals(0, cur2) // 하루 건너뛰면 끊김
    }

    @Test fun placementLadder() {
        assertEquals(4, Placement.nextLevel(3, true))
        assertEquals(2, Placement.nextLevel(3, false))
        assertEquals(10, Placement.nextLevel(10, true))
        assertEquals(1, Placement.nextLevel(1, false))
    }

    @Test fun placementMedian() {
        // 마지막 10개: 5,6,5,6,7,6,5,6,7,6 → 정렬 중앙값(인덱스5) = 6
        val hist = listOf(3, 4, 5, 6, 5, 6, 7, 6, 5, 6, 7, 6).map { it to true }
        assertEquals(6, Placement.placeLevel(hist))
        assertEquals(1, Placement.placeLevel(emptyList()))
    }
}
