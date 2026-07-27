package com.piyak.english

import com.piyak.english.engine.Letters
import com.piyak.english.engine.Pt
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.hypot

class LettersTest {

    @Test fun hasAllTwentySixLetters() {
        assertEquals(26, Letters.ALL.size)
        val uppers = Letters.ALL.map { it.upper }
        assertEquals(('A'..'Z').toList(), uppers)
        val lowers = Letters.ALL.map { it.lower }
        assertEquals(('a'..'z').toList(), lowers)
    }

    @Test fun everyLetterHasWordAndEmoji() {
        for (d in Letters.ALL) {
            assertTrue("${d.upper}: 단어 없음", d.word.isNotBlank())
            assertTrue("${d.upper}: 뜻 없음", d.ko.isNotBlank())
            assertTrue("${d.upper}: 이모지 없음", d.emoji.isNotBlank())
            // 예시 단어는 그 글자로 시작해야 아이가 소리를 연결할 수 있다
            assertEquals(
                "${d.upper}: 단어가 글자로 시작하지 않음 (${d.word})",
                d.upper, d.word.first().uppercaseChar()
            )
        }
    }

    /** 획 데이터가 실제로 그릴 수 있는 형태인지 (점 수·범위·길이) */
    private fun checkStrokes(name: String, strokes: List<List<Pt>>) {
        assertTrue("$name: 획이 없음", strokes.isNotEmpty())
        assertTrue("$name: 획이 너무 많음(${strokes.size})", strokes.size <= 4)
        for ((i, s) in strokes.withIndex()) {
            assertTrue("$name 획${i + 1}: 점이 2개 미만", s.size >= 2)
            var len = 0f
            for (j in 0 until s.size - 1) {
                len += hypot(s[j + 1].x - s[j].x, s[j + 1].y - s[j].y)
            }
            // 너무 짧은 획은 아이가 따라 그리기 어렵다 (i 의 점은 예외적으로 작은 원)
            assertTrue("$name 획${i + 1}: 길이가 너무 짧음($len)", len > 0.08f)
            for (p in s) {
                assertTrue("$name 획${i + 1}: x 범위 벗어남(${p.x})", p.x in -0.02f..1.02f)
                assertTrue("$name 획${i + 1}: y 범위 벗어남(${p.y})", p.y in -0.02f..1.10f)
            }
        }
    }

    @Test fun uppercaseStrokesAreDrawable() {
        for (d in Letters.ALL) checkStrokes("${d.upper}(대)", d.upperStrokes)
    }

    @Test fun lowercaseStrokesAreDrawable() {
        for (d in Letters.ALL) checkStrokes("${d.lower}(소)", d.lowerStrokes)
    }

    @Test fun progressKeysAreUnique() {
        val keys = HashSet<String>()
        for (d in Letters.ALL) {
            assertTrue("키 중복", keys.add(Letters.key(d, true)))
            assertTrue("키 중복", keys.add(Letters.key(d, false)))
        }
        assertEquals(52, keys.size)
        assertEquals("A_U", Letters.key(Letters.ALL.first(), true))
        assertEquals("a_L", Letters.key(Letters.ALL.first(), false))
    }

    @Test fun letterGlyphSwitchesByCase() {
        val a = Letters.ALL.first()
        assertEquals('A', a.glyph(true))
        assertEquals('a', a.glyph(false))
        assertEquals(a.upperStrokes, a.strokes(true))
        assertEquals(a.lowerStrokes, a.strokes(false))
    }
}
