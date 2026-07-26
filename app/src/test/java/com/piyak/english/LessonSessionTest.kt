package com.piyak.english

import com.piyak.english.engine.LessonSession
import com.piyak.english.model.Question
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LessonSessionTest {

    private fun mcq(id: String) = Question.Mcq(id, "p", listOf("a", "b", "c", "d"), 0)
    private fun qs(n: Int) = (1..n).map { mcq("q$it") }

    @Test fun allCorrectIsPerfect() {
        val s = LessonSession(qs(3), hearts = 5)
        repeat(3) { assertTrue(s.submit(true)) }
        assertTrue(s.isFinished)
        assertTrue(s.isPerfect)
        assertEquals(3, s.firstTryCorrect)
        assertEquals(3 * 2 + 10 + 5, s.xpEarned())
        assertEquals(3, s.stars())
    }

    @Test fun wrongRequeuesAndCostsHeart() {
        val s = LessonSession(qs(2), hearts = 5)
        val first = s.current()!!
        s.submit(false) // q1 틀림 → 큐 끝으로
        assertEquals(4, s.hearts)
        assertEquals("q2", s.current()!!.id)
        s.submit(true) // q2 정답
        assertEquals(first.id, s.current()!!.id) // q1 재출제
        s.submit(true)
        assertTrue(s.isFinished)
        assertFalse(s.isPerfect)
        assertEquals(1, s.firstTryCorrect)
        assertEquals(1 * 2 + 10, s.xpEarned())
    }

    @Test fun heartsZeroFails() {
        val s = LessonSession(qs(3), hearts = 2)
        s.submit(false)
        s.submit(false)
        assertTrue(s.failed)
        assertTrue(s.isFinished)
        assertEquals(0, s.xpEarned())
    }

    @Test fun noHeartsModeNeverFails() {
        val s = LessonSession(qs(2), hearts = 1, useHearts = false)
        s.submit(false); s.submit(false); s.submit(false)
        assertFalse(s.failed)
    }

    @Test fun submitNoPenaltySkipsRequeue() {
        val s = LessonSession(qs(2), hearts = 5)
        s.submitNoPenalty(false) // 매칭 실수 — 하트 유지, 재출제 없음
        assertEquals(5, s.hearts)
        assertEquals("q2", s.current()!!.id)
        s.submit(true)
        assertTrue(s.isFinished)
        assertFalse(s.isPerfect)
    }

    @Test fun progressAdvancesOnlyOnCorrect() {
        val s = LessonSession(qs(4), hearts = 5)
        assertEquals(0f, s.progress)
        s.submit(true)
        assertEquals(0.25f, s.progress)
        s.submit(false)
        assertEquals(0.25f, s.progress)
    }

    @Test fun starsByAccuracy() {
        // 5문제 중 1개 틀림 → 80% → 별 2
        val s = LessonSession(qs(5), hearts = 5)
        s.submit(false)
        repeat(4) { s.submit(true) }
        s.submit(true) // 재출제분
        assertTrue(s.isFinished)
        assertEquals(2, s.stars())
    }
}
