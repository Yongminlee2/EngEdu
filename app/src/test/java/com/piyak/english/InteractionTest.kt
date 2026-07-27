package com.piyak.english

import com.piyak.english.audio.Sfx
import com.piyak.english.model.ContentRepo
import com.piyak.english.model.Question
import com.piyak.english.model.Subject
import com.piyak.english.ui.game.BubbleChoiceView
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** 일반 문제의 상호작용(버블 보기 / 선 잇기)이 실제 콘텐츠에 잘 맞는지 */
class InteractionTest {

    private fun packsDir(): File {
        val candidates = listOf(
            File("src/main/assets/packs"),
            File("app/src/main/assets/packs"),
            File(System.getProperty("user.dir"), "src/main/assets/packs"),
        )
        return candidates.firstOrNull { it.isDirectory } ?: error("packs 디렉터리 없음")
    }

    @Test fun effectSoundDefaultsQuietEnoughForSpeech() {
        // 효과음이 크면 듣기·말하기 음성을 덮는다
        assertTrue("기본 효과음이 너무 큼", Sfx.DEFAULT_VOLUME_PERCENT <= 40)
        assertTrue("기본 효과음이 0이면 피드백이 사라진다", Sfx.DEFAULT_VOLUME_PERCENT > 0)
    }

    @Test fun bubbleModeOnlyForShortChoices() {
        assertTrue(BubbleChoiceView.fits(listOf("12", "13", "14", "15")))
        assertTrue(BubbleChoiceView.fits(listOf("🍎", "🍌", "🐶", "🐱")))
        assertTrue(BubbleChoiceView.fits(listOf("apple", "banana", "dog", "cat")))
        // 짧은 한글 낱말은 버블에 들어간다
        assertTrue(BubbleChoiceView.fits(listOf("사과", "고양이", "무지개", "아이스크림")))
        // 긴 문장은 버블에 안 들어간다 → 읽기 편한 버튼 목록으로
        assertFalse(
            BubbleChoiceView.fits(
                listOf(
                    "나는 사과를 좋아해요.", "이것은 내 개예요.",
                    "해는 뜨거워요.", "나는 별을 봐요."
                )
            )
        )
        // 보기가 4개가 아니면 버블 배치가 깨진다
        assertFalse(BubbleChoiceView.fits(listOf("1", "2", "3")))
    }

    /** 한글은 글자 수가 적어도 폭이 넓다 — 글자 수로 재면 문장이 버블에 들어가 버린다 */
    @Test fun widthScoreCountsWideCharactersAsTwo() {
        assertEquals(4, BubbleChoiceView.widthScore("사과"))
        assertEquals(5, BubbleChoiceView.widthScore("apple"))
        assertEquals(2, BubbleChoiceView.widthScore("🍎"))
        assertEquals(2, BubbleChoiceView.widthScore("12"))
        // 11자짜리 한글 문장은 폭 점수가 기준을 훌쩍 넘는다
        assertTrue(BubbleChoiceView.widthScore("나는 사과를 좋아해요.") > BubbleChoiceView.MAX_WIDTH_SCORE)
    }

    /** 실제 팩에서 버블이 얼마나 쓰이는지 — 아예 안 쓰이면 의미가 없다 */
    @Test fun realContentActuallyUsesBubbles() {
        val dir = packsDir()
        var bubble = 0
        var list = 0
        for (tid in Subject.ENGLISH.tracks + Subject.MATH.tracks) {
            val f = File(dir, "$tid.json")
            if (!f.isFile) continue
            val t = ContentRepo.parseTrack(JSONObject(f.readText()))
            for (u in t.units) for (l in u.lessons) for (q in l.questions) {
                val choices = when (q) {
                    is Question.Mcq -> q.choices
                    is Question.ListenMcq -> q.choices
                    is Question.ListenDialog -> q.choices
                    is Question.Math -> if (q.input == "choice") q.choices else null
                    else -> null
                } ?: continue
                if (BubbleChoiceView.fits(choices)) bubble++ else list++
            }
        }
        println("버블로 뜨는 문제 $bubble · 목록으로 뜨는 문제 $list")
        assertTrue("버블이 전혀 안 쓰인다", bubble > 500)
        // 긴 보기는 버튼 목록으로 남아야 읽기 편하다
        assertTrue("모든 문제가 버블이면 문장형 보기가 답답해진다", list > 0)
    }

    /** 짝 맞추기는 선 잇기로 바뀌었다 — 5쌍이어야 좌우 배치가 맞는다 */
    @Test fun matchQuestionsHaveConsistentPairCount() {
        val dir = packsDir()
        var checked = 0
        for (tid in Subject.ENGLISH.tracks) {
            val f = File(dir, "$tid.json")
            if (!f.isFile) continue
            val t = ContentRepo.parseTrack(JSONObject(f.readText()))
            for (u in t.units) for (l in u.lessons) for (q in l.questions) {
                val m = q as? Question.Match ?: continue
                assertEquals("${m.id}: 5쌍이 아님", 5, m.pairs.size)
                // 오른쪽 값이 겹치면 아무 데나 이어도 맞아 버린다
                assertEquals("${m.id}: 오른쪽 값 중복", 5, m.pairs.map { it.second }.toSet().size)
                checked++
            }
        }
        println("짝 맞추기 문제 수: $checked")
        assertTrue("짝 맞추기 문제가 없다", checked > 0)
    }
}
