package com.piyak.english

import com.piyak.english.engine.Placement
import com.piyak.english.model.ContentRepo
import com.piyak.english.model.MathGrades
import com.piyak.english.model.Subject
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** 과목별 배치고사가 서로 섞이지 않는지 검증한다 */
class PlacementSubjectTest {

    private fun packsDir(): File {
        val candidates = listOf(
            File("src/main/assets/packs"),
            File("app/src/main/assets/packs"),
            File(System.getProperty("user.dir"), "src/main/assets/packs"),
        )
        return candidates.firstOrNull { it.isDirectory } ?: error("packs 디렉터리 없음")
    }

    @Test fun eachSubjectHasItsOwnLevelRange() {
        assertEquals(10, Placement.maxLevel(Subject.ENGLISH))
        assertEquals(13, Placement.maxLevel(Subject.MATH))
        // 수학은 13단계까지 올라갈 수 있어야 한다
        assertEquals(13, Placement.nextLevel(13, correct = true, max = 13))
        assertEquals(10, Placement.nextLevel(10, correct = true, max = 10))
        assertEquals(1, Placement.nextLevel(1, correct = false, max = 13))
    }

    @Test fun progressKeysAreSeparatePerSubject() {
        assertNotEquals(Placement.levelKey(Subject.ENGLISH), Placement.levelKey(Subject.MATH))
        assertNotEquals(Placement.doneKey(Subject.ENGLISH), Placement.doneKey(Subject.MATH))
        assertEquals("placement_level", Placement.levelKey(Subject.ENGLISH))
        assertEquals("math_placement_level", Placement.levelKey(Subject.MATH))
    }

    @Test fun levelNamesMatchTheSubject() {
        assertEquals("초등 1~2학년", Placement.levelName(Subject.ENGLISH, 1))
        // 수학은 학년 이름을 그대로 쓴다
        assertEquals(MathGrades.ALL.first().title, Placement.levelName(Subject.MATH, 1))
        assertEquals(MathGrades.ALL.last().title, Placement.levelName(Subject.MATH, 13))
    }

    /** 영어 전용 앱 — 수학 배치고사 팩이 섞여 들어오면 안 된다 */
    @Test fun onlyEnglishPlacementPackShips() {
        val dir = packsDir()
        val eng = JSONObject(File(dir, "placement.json").readText()).getJSONArray("questions")
        assertTrue(eng.length() > 0)
        assertTrue("수학 배치고사 팩은 삐약수학으로 갔다", !File(dir, "math_placement.json").isFile)
        // 영어 배치고사는 1~10 범위여야 한다
        for (i in 0 until eng.length()) {
            assertTrue(eng.getJSONObject(i).getInt("level") in 1..10)
        }
    }

    /** 시작 화면이 팩을 전부 파싱하지 않도록 색인이 있어야 한다 */
    @Test fun packIndexCoversEveryTrack() {
        val f = File(packsDir(), "index.json")
        assertTrue("index.json 이 없으면 시작 화면이 팩 전체를 파싱한다", f.isFile)
        val idx = JSONObject(f.readText())
        for (tid in ContentRepo.TRACK_IDS) {
            assertTrue("색인에 트랙 없음: $tid", idx.has(tid))
            val e = idx.getJSONObject(tid)
            assertTrue("$tid: 레슨 수가 0", e.getInt("lessons") > 0)
            assertTrue("$tid: 문제 수가 0", e.getInt("questions") > 0)
        }
        // 색인의 합이 실제 규모와 맞는지 (영어만 약 1,490 레슨)
        val totalLessons = ContentRepo.TRACK_IDS.sumOf { idx.getJSONObject(it).getInt("lessons") }
        assertTrue("전체 레슨 수가 이상함: $totalLessons", totalLessons > 1000)
    }
}
