package com.piyak.english

import com.piyak.english.engine.GameReward
import com.piyak.english.engine.MiniGames
import com.piyak.english.model.Subject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class MiniGamesTest {

    private val rnd = Random(42)

    @Test fun everySubjectHasGames() {
        assertTrue(MiniGames.forSubject(Subject.MATH).isNotEmpty())
        assertTrue(MiniGames.forSubject(Subject.ENGLISH).isNotEmpty())
        // id 중복 없음
        assertEquals(MiniGames.ALL.size, MiniGames.ALL.map { it.id }.toSet().size)
        for (g in MiniGames.ALL) {
            assertTrue(g.titleRes != 0 && g.descRes != 0 && g.emoji.isNotBlank())
            assertTrue(g.color.startsWith("#"))
        }
    }

    /** 풍선 게임: 정답이 반드시 보기 안에 있어야 터뜨릴 수 있다 */
    @Test fun balloonRoundsAlwaysContainTheAnswer() {
        for (level in 1..5) {
            repeat(200) {
                val r = MiniGames.balloonMath(level, rnd)
                assertTrue("보기에 정답이 없음: $r", r.options.contains(r.answer))
                assertEquals("보기 중복", r.options.size, r.options.toSet().size)
                assertTrue("보기가 너무 적음", r.options.size >= 4)
                // 뺄셈 답이 음수면 아이가 혼란스럽다
                assertTrue("음수 답: ${r.question}", r.answer.toInt() >= 0)
            }
        }
    }

    @Test fun englishBalloonUsesPicturesAndHasAnswer() {
        repeat(100) {
            val r = MiniGames.balloonEnglish(rnd)
            assertTrue(r.options.contains(r.answer))
            assertEquals(r.options.size, r.options.toSet().size)
            assertTrue("읽어 줄 낱말이 없음", !r.speak.isNullOrBlank())
        }
    }

    @Test fun basketTargetsStayCountable() {
        for (level in 1..3) {
            repeat(100) {
                val r = MiniGames.basketRound(level, rnd)
                val n = r.answer.toInt()
                assertTrue("담을 개수가 이상함: $n", n in 1..15)
                assertTrue("그림이 없음", !r.emoji.isNullOrBlank())
            }
        }
    }

    /** 선 잇기: 4쌍이고 답이 겹치면 안 된다 (겹치면 어느 쪽에 이어도 맞아 버린다) */
    @Test fun lineMathPairsHaveDistinctAnswers() {
        repeat(100) {
            val pairs = MiniGames.lineMath(3, rnd)
            assertEquals(4, pairs.size)
            assertEquals("답이 겹침: $pairs", 4, pairs.map { it.second }.toSet().size)
            assertEquals("문제가 겹침: $pairs", 4, pairs.map { it.first }.toSet().size)
        }
    }

    @Test fun lineEnglishPairsAreDistinct() {
        repeat(100) {
            val pairs = MiniGames.lineEnglish(rnd)
            assertEquals(4, pairs.size)
            assertEquals(4, pairs.map { it.first }.toSet().size)
            assertEquals(4, pairs.map { it.second }.toSet().size)
        }
    }

    @Test fun wrongNumbersNeverRepeatOrGoNegative() {
        for (answer in 0..30) {
            val list = MiniGames.wrongNumbers(answer, 6, rnd)
            assertEquals(6, list.size)
            assertEquals("중복", 6, list.toSet().size)
            assertTrue("정답이 빠짐", list.contains(answer))
            assertTrue("음수 포함", list.all { it >= 0 })
        }
    }

    /** 게임으로 용돈을 무한히 벌 수 없어야 한다 */
    @Test fun gameRewardsAreCapped() {
        val max = 10 * GameReward.SCORE_PER_HIT
        assertEquals(GameReward.MAX_COINS, GameReward.coinsFor(max, max))
        assertEquals(0, GameReward.coinsFor(0, max))
        assertTrue(GameReward.coinsFor(max / 2, max) < GameReward.MAX_COINS)
        // 하루 최대 게임 용돈이 레슨 한 판 보상을 넘지 않아야 공부가 손해가 아니다
        val dailyMax = GameReward.MAX_COINS * GameReward.DAILY_PAID_ROUNDS
        val perLesson = com.piyak.english.engine.Wallet.lessonReward(12, perfect = true)
        assertTrue("게임이 공부보다 돈이 되면 안 됨: $dailyMax vs $perLesson", dailyMax <= perLesson)
    }

    @Test fun scoreToStarsAndXp() {
        val max = 100
        assertEquals(3, GameReward.stars(100, max))
        assertEquals(2, GameReward.stars(70, max))
        assertEquals(1, GameReward.stars(10, max))
        assertEquals(0, GameReward.stars(0, max))
        assertTrue(GameReward.xpFor(100) in 1..30)
        assertEquals(0, GameReward.xpFor(0))
    }
}
