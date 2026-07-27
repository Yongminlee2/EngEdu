package com.piyak.english

import com.piyak.english.engine.MathGrader
import com.piyak.english.engine.Skills
import com.piyak.english.model.ContentRepo
import com.piyak.english.model.MathGrades
import com.piyak.english.model.MathVisual
import com.piyak.english.model.Question
import com.piyak.english.model.Subject
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class MathTest {

    private fun packsDir(): File {
        val candidates = listOf(
            File("src/main/assets/packs"),
            File("app/src/main/assets/packs"),
            File(System.getProperty("user.dir"), "src/main/assets/packs"),
        )
        return candidates.firstOrNull { it.isDirectory }
            ?: error("packs 디렉터리를 찾을 수 없음")
    }

    // ---------------- 채점기 ----------------

    @Test fun parsesNumbersFractionsAndUnits() {
        assertEquals(7.0, MathGrader.parse("7")!!, 1e-9)
        assertEquals(0.75, MathGrader.parse("3/4")!!, 1e-9)
        assertEquals(1200.0, MathGrader.parse("1,200")!!, 1e-9)
        assertEquals(12.0, MathGrader.parse("12 cm")!!, 1e-9)
        assertEquals(-5.0, MathGrader.parse("-5")!!, 1e-9)
        assertNull(MathGrader.parse(""))
        assertNull(MathGrader.parse("3/0"))
    }

    @Test fun fractionAndDecimalAreTheSameAnswer() {
        assertTrue(MathGrader.grade("3/4", "0.75"))
        assertTrue(MathGrader.grade("0.75", "3/4"))
        assertTrue(MathGrader.grade("6/8", "3/4"))
        assertFalse(MathGrader.grade("2/4", "3/4"))
    }

    @Test fun unitsAndSpacesAreForgiven() {
        assertTrue(MathGrader.grade(" 12 ", "12"))
        assertTrue(MathGrader.grade("12cm", "12"))
        assertTrue(MathGrader.grade("1,000", "1000"))
        assertFalse(MathGrader.grade("", "12"))
    }

    @Test fun expressionAnswersAreNormalized() {
        assertTrue(MathGrader.grade("(x+2)(x+3)", "(x+2)(x+3)"))
        assertTrue(MathGrader.grade("(x + 2)(x + 3)", "(x+2)(x+3)"))
        assertTrue(MathGrader.grade("(x+3)(x+2)", "(x+2)(x+3)", listOf("(x+3)(x+2)")))
        assertFalse(MathGrader.grade("(x+1)(x+3)", "(x+2)(x+3)"))
    }

    @Test fun reduceAndGcd() {
        assertEquals(3 to 4, MathGrader.reduce(6, 8))
        assertEquals(1 to 3, MathGrader.reduce(5, 15))
        assertEquals(6, MathGrader.gcd(12, 18))
        assertEquals(36, MathGrader.lcm(12, 18))
    }

    // ---------------- 과목·학년 구조 ----------------

    @Test fun subjectsHaveDistinctTracks() {
        val eng = Subject.ENGLISH.tracks
        val math = Subject.MATH.tracks
        assertTrue(eng.isNotEmpty() && math.isNotEmpty())
        assertTrue("과목 간 트랙이 겹치면 안 됨", eng.intersect(math.toSet()).isEmpty())
        assertEquals(13, math.size)
        assertEquals(ContentRepo.TRACK_IDS.size, eng.size + math.size)
    }

    @Test fun mathGradesAreOrderedAndComplete() {
        assertEquals(13, MathGrades.ALL.size)
        // 배치고사 레벨 1~13 이 학년과 1:1로 대응해야 한다
        for (lv in 1..13) {
            val g = MathGrades.forLevel(lv)
            assertEquals(lv, MathGrades.levelOf(g.trackId))
        }
        // 범위를 벗어난 레벨도 안전하게 잘린다
        assertEquals(MathGrades.ALL.first(), MathGrades.forLevel(0))
        assertEquals(MathGrades.ALL.last(), MathGrades.forLevel(99))
        assertEquals(3, MathGrades.STAGES.size)
        assertEquals(13, MathGrades.STAGES.sumOf { MathGrades.byStage(it).size })
    }

    @Test fun mathSkillsAreSeparateFromEnglish() {
        val eng = Skills.ALL.map { it.id }.toSet()
        val math = Skills.MATH.map { it.id }.toSet()
        assertTrue("영어·수학 영역 id 가 겹치면 안 됨", eng.intersect(math).isEmpty())
        assertEquals(6, math.size)
        assertEquals(Skills.MATH, Skills.forSubject(Subject.MATH))
        assertEquals(Skills.ALL, Skills.forSubject(Subject.ENGLISH))
    }

    // ---------------- 콘텐츠 ----------------

    @Test fun everyMathTrackHasEnoughQuestions() {
        val dir = packsDir()
        var grand = 0
        for (g in MathGrades.ALL) {
            val f = File(dir, "${g.trackId}.json")
            assertTrue("팩 없음: ${g.trackId}", f.isFile)
            val t = ContentRepo.parseTrack(JSONObject(f.readText()))
            val qs = t.units.flatMap { u -> u.lessons.flatMap { it.questions } }
            assertTrue("${g.trackId}: 문제가 너무 적음 (${qs.size})", qs.size >= 300)
            grand += qs.size
        }
        println("수학 총 문제 수: $grand")
        assertTrue("수학 전체 문제 수 부족: $grand", grand >= 8000)
    }

    @Test fun mathQuestionsAreWellFormed() {
        val dir = packsDir()
        val ids = HashSet<String>()
        val skillCount = HashMap<String, Int>()
        for (g in MathGrades.ALL) {
            val f = File(dir, "${g.trackId}.json")
            if (!f.isFile) continue
            val t = ContentRepo.parseTrack(JSONObject(f.readText()))
            for (u in t.units) for (l in u.lessons) for (q in l.questions) {
                assertTrue("${g.trackId}: 수학 팩에 수학 문제가 아닌 게 있음 (${q.id})", q is Question.Math)
                val m = q as Question.Math
                assertTrue("id 중복 ${m.id}", ids.add(m.id))
                assertTrue("${m.id}: 문제 문구 없음", m.prompt.isNotBlank())
                assertTrue("${m.id}: 해설 없음", !m.explain.isNullOrBlank())
                when (m.input) {
                    "choice" -> {
                        assertEquals("${m.id}: 선택지 4개 아님", 4, m.choices.size)
                        assertEquals("${m.id}: 선택지 중복", 4, m.choices.toSet().size)
                        assertTrue("${m.id}: 정답 인덱스 범위", m.answerIndex in m.choices.indices)
                    }
                    else -> assertTrue("${m.id}: 답 없음", m.answer.isNotBlank())
                }
                m.visual?.let {
                    assertTrue("${m.id}: 알 수 없는 그림 ${it.kind}", it.kind in MathVisual.KINDS)
                }
                skillCount[m.skill] = (skillCount[m.skill] ?: 0) + 1
            }
        }
        println("수학 영역별 문제 수: $skillCount")
        // 여섯 영역 모두 Lv.3(누적 정답 60) 을 찍을 만큼은 있어야 대시보드가 의미를 갖는다
        for (s in Skills.MATH) {
            val n = skillCount[s.id] ?: 0
            assertTrue("수학 영역 '${s.id}' 문제가 너무 적음: $n", n >= 70)
        }
    }

    /** 숫자 입력 문제의 정답이 실제로 채점기를 통과하는지 — 생성기 오타를 잡는다 */
    @Test fun mathAnswersPassTheirOwnGrader() {
        val dir = packsDir()
        var checked = 0
        for (g in MathGrades.ALL) {
            val f = File(dir, "${g.trackId}.json")
            if (!f.isFile) continue
            val t = ContentRepo.parseTrack(JSONObject(f.readText()))
            for (u in t.units) for (l in u.lessons) for (q in l.questions) {
                val m = q as? Question.Math ?: continue
                if (m.input == "choice") continue
                assertTrue(
                    "${m.id}: 정답 '${m.answer}' 이 채점기를 통과하지 못함",
                    MathGrader.grade(m.answer, m.answer, m.alts)
                )
                checked++
            }
        }
        assertTrue("검사한 문제가 없음", checked > 1000)
    }

    @Test fun mathPlacementLaddersAcrossGrades() {
        val f = File(packsDir(), "math_placement.json")
        assertTrue("math_placement.json 없음", f.isFile)
        val arr = JSONObject(f.readText()).getJSONArray("questions")
        val perLevel = HashMap<Int, Int>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val lv = o.getInt("level")
            assertTrue("레벨 범위(1~13)를 벗어남: $lv", lv in 1..13)
            Question.fromJson(o) // 파싱되는지
            perLevel[lv] = (perLevel[lv] ?: 0) + 1
        }
        // 학년마다 문제가 있어야 적응형 사다리가 작동한다
        for (lv in 1..13) {
            assertTrue("배치고사에 레벨 $lv 문제가 없음", (perLevel[lv] ?: 0) >= 3)
        }
    }
}
