package com.piyak.english

import com.piyak.english.engine.Grader
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GraderTest {

    @Test fun normalizeBasics() {
        assertEquals("i am a student", Grader.normalize("I'm a student."))
        assertEquals("do not worry", Grader.normalize("  Don't   worry!  "))
        assertEquals("it is nice", Grader.normalize("It’s nice")) // 유니코드 아포스트로피
        assertEquals("hello", Grader.normalize("Hello!!!"))
    }

    @Test fun gradeExact() {
        assertTrue(Grader.grade("I am happy", "I'm happy.").correct)
        assertTrue(Grader.grade("i am happy", "I AM HAPPY").correct)
        assertFalse(Grader.grade("", "hello").correct)
    }

    @Test fun gradeAlts() {
        val r = Grader.grade("I would like a coffee", "I'd like a coffee", listOf("I want a coffee"))
        assertTrue(r.correct)
        assertTrue(Grader.grade("I want a coffee", "I'd like a coffee", listOf("I want a coffee")).correct)
    }

    @Test fun gradeTypoTolerance() {
        // 길이 >4 → 편집거리 1 허용
        val r = Grader.grade("aple", "apple")
        assertTrue(r.correct); assertTrue(r.typo)
        // 길이 >10 → 거리 2 허용
        assertTrue(Grader.grade("beautifl day", "beautiful day").correct)
        // 짧은 단어(4자 이하)는 오타 불허
        assertFalse(Grader.grade("ct", "cat").correct)
        // 심한 오타는 불허
        assertFalse(Grader.grade("aplle pie yum", "apple").correct)
    }

    @Test fun gradeOrder() {
        assertTrue(Grader.gradeOrder(listOf("I", "like", "cats"), listOf("I", "like", "cats")))
        assertFalse(Grader.gradeOrder(listOf("like", "I", "cats"), listOf("I", "like", "cats")))
        assertFalse(Grader.gradeOrder(listOf("I", "like"), listOf("I", "like", "cats")))
    }

    @Test fun speakLongSentence() {
        val target = "I would like to book a table for two people"
        assertTrue(Grader.gradeSpeak("I would like to book a table for two people", target))
        // 10 단어 중 2개 오차 → 0.8 ≥ 0.75 통과
        assertTrue(Grader.gradeSpeak("I would like to book table for two person", target))
        // 절반만 말하면 탈락
        assertFalse(Grader.gradeSpeak("I would like", target))
    }

    @Test fun speakShortSentence() {
        // 3단어: 1오차 허용
        assertTrue(Grader.gradeSpeak("good morning everyone", "Good morning, everyone!"))
        assertTrue(Grader.gradeSpeak("good morning friend", "Good morning, everyone!"))
        assertFalse(Grader.gradeSpeak("good", "Good morning, everyone!"))
        // 1~2단어: 정확히
        assertTrue(Grader.gradeSpeak("Hello", "hello"))
        assertFalse(Grader.gradeSpeak("Hallo there", "hello"))
    }

    @Test fun speakScoreRange() {
        assertEquals(100, Grader.speakScore("hello world", "Hello, world!"))
        assertTrue(Grader.speakScore("totally different words here", "hello world") < 50)
    }

    @Test fun levenshteinBasics() {
        assertEquals(0, Grader.levenshtein("abc", "abc"))
        assertEquals(1, Grader.levenshtein("abc", "abd"))
        assertEquals(3, Grader.levenshtein("", "abc"))
    }
}
