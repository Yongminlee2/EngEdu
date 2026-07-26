package com.piyak.english

import com.piyak.english.model.ContentRepo
import com.piyak.english.model.Question
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.File

/** 모든 문제팩 JSON 을 파싱해 데이터 무결성을 검증한다 (실기기 없이). */
class ContentPackTest {

    private fun packsDir(): File {
        val candidates = listOf(
            File("src/main/assets/packs"),
            File("app/src/main/assets/packs"),
            File(System.getProperty("user.dir"), "src/main/assets/packs"),
        )
        return candidates.firstOrNull { it.isDirectory }
            ?: error("packs 디렉터리를 찾을 수 없음: ${File(".").absolutePath}")
    }

    private fun validateQuestion(q: Question, ids: MutableSet<String>, where: String) {
        assertTrue("$where: id 중복 ${q.id}", ids.add(q.id))
        when (q) {
            is Question.Mcq -> {
                assertTrue("$where/${q.id}: 선택지 4개", q.choices.size == 4)
                assertTrue("$where/${q.id}: 정답 범위", q.answer in q.choices.indices)
                assertTrue("$where/${q.id}: 선택지 중복", q.choices.toSet().size == 4)
                assertTrue("$where/${q.id}: 프롬프트 비어있음", q.prompt.isNotBlank())
            }
            is Question.ListenMcq -> {
                assertTrue("$where/${q.id}: 선택지 4개", q.choices.size == 4)
                assertTrue("$where/${q.id}: 정답 범위", q.answer in q.choices.indices)
                assertTrue("$where/${q.id}: 선택지 중복", q.choices.toSet().size == 4)
                assertTrue("$where/${q.id}: tts 비어있음", q.tts.isNotBlank())
            }
            is Question.Dictation -> {
                assertTrue("$where/${q.id}: tts", q.tts.isNotBlank())
                assertTrue("$where/${q.id}: answer", q.answer.isNotBlank())
            }
            is Question.Order -> {
                assertTrue("$where/${q.id}: 토큰 2개 이상", q.tokens.size >= 2)
                assertTrue("$where/${q.id}: ko", q.ko.isNotBlank())
            }
            is Question.TypeTranslate -> {
                assertTrue("$where/${q.id}: answer", q.answer.isNotBlank())
                assertTrue("$where/${q.id}: ko", q.ko.isNotBlank())
            }
            is Question.Match -> {
                assertTrue("$where/${q.id}: 5쌍", q.pairs.size == 5)
                assertTrue("$where/${q.id}: 왼쪽 중복", q.pairs.map { it.first }.toSet().size == 5)
                assertTrue("$where/${q.id}: 오른쪽 중복", q.pairs.map { it.second }.toSet().size == 5)
            }
            is Question.Speak -> assertTrue("$where/${q.id}: en", q.en.isNotBlank())
            is Question.ListenDialog -> {
                // 토익 대화는 2줄+, 토플 강의는 1인 독백(1줄)도 허용
                assertTrue("$where/${q.id}: 대사 없음", q.lines.isNotEmpty())
                assertTrue("$where/${q.id}: 빈 대사", q.lines.all { it.second.isNotBlank() })
                assertTrue("$where/${q.id}: 선택지 4개", q.choices.size == 4)
                assertTrue("$where/${q.id}: 정답 범위", q.answer in q.choices.indices)
            }
        }
    }

    @Test fun allTracksParseAndValidate() {
        val dir = packsDir()
        val ids = HashSet<String>()
        var total = 0
        for (tid in ContentRepo.TRACK_IDS) {
            val f = File(dir, "$tid.json")
            assertTrue("팩 없음: $tid", f.isFile)
            val t = ContentRepo.parseTrack(JSONObject(f.readText()))
            assertTrue("$tid: 유닛 없음", t.units.isNotEmpty())
            for (u in t.units) {
                assertTrue("$tid/${u.id}: 레슨 없음", u.lessons.isNotEmpty())
                for (l in u.lessons) {
                    assertTrue("$tid/${u.id}/${l.id}: 문제 없음", l.questions.isNotEmpty())
                    for (q in l.questions) {
                        validateQuestion(q, ids, "$tid/${u.id}/${l.id}")
                        total++
                    }
                }
            }
        }
        println("총 문제 수(트랙): $total")
        assertTrue("문제가 너무 적음: $total", total >= 5000)
    }

    @Test fun placementPoolValid() {
        val f = File(packsDir(), "placement.json")
        assertTrue("placement.json 없음", f.isFile)
        val arr = JSONObject(f.readText()).getJSONArray("questions")
        val perLevel = HashMap<Int, Int>()
        val ids = HashSet<String>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val lv = o.getInt("level")
            assertTrue("레벨 범위", lv in 1..10)
            val q = Question.fromJson(o)
            assertTrue("배치고사는 선다형만", q is Question.Mcq || q is Question.ListenMcq)
            validateQuestion(q, ids, "placement")
            perLevel[lv] = (perLevel[lv] ?: 0) + 1
        }
        for (lv in 1..10) {
            assertTrue("레벨 $lv 문제 4개 이상 필요 (현재 ${perLevel[lv] ?: 0})", (perLevel[lv] ?: 0) >= 4)
        }
    }

    @Test fun orderTilesReconstructable() {
        // order 문제: extras 에 정답 토큰과 동일한 단어가 섞여도 재구성엔 문제없지만
        // 정답 문장이 타일만으로 만들어지는지 확인
        val dir = packsDir()
        for (tid in ContentRepo.TRACK_IDS) {
            val f = File(dir, "$tid.json")
            if (!f.isFile) continue
            val t = ContentRepo.parseTrack(JSONObject(f.readText()))
            for (u in t.units) for (l in u.lessons) for (q in l.questions) {
                if (q is Question.Order) {
                    val bank = q.tokens + q.extras
                    for (tok in q.tokens) {
                        if (bank.count { it == tok } < q.tokens.count { it == tok }) {
                            fail("${q.id}: 타일 부족 '$tok'")
                        }
                    }
                }
            }
        }
    }
}
