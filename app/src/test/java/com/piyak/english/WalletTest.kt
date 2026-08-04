package com.piyak.english

import com.piyak.english.engine.Economy
import com.piyak.english.engine.Shop
import com.piyak.english.engine.ShopKind
import com.piyak.english.engine.Wallet
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class WalletTest {

    @Test fun oneQuestionIsTenWon() {
        // 문제 하나는 1~10원 범위 안이어야 한다
        assertTrue(Wallet.PER_QUESTION in 1..10)
        assertTrue("알파벳 한 글자도 문제 하나 수준", Wallet.PER_LETTER in 1..10)
        assertTrue("반복 쓰기는 더 적게", Wallet.PER_LETTER_REPEAT < Wallet.PER_LETTER)
        assertEquals(
            12 * Wallet.PER_QUESTION + Wallet.PERFECT_BONUS,
            Wallet.lessonReward(12, perfect = true)
        )
        assertEquals(120, Wallet.lessonReward(12, perfect = false))
        // 틀린 문제는 한 푼도 안 준다 (첫 시도 정답만 계산)
        assertEquals(80, Wallet.lessonReward(8, perfect = false))
        assertEquals(0, Wallet.lessonReward(0, perfect = false))
    }

    @Test fun rewardsAreHardToFarm() {
        // 10,000원을 모으려면 첫 시도 정답이 1,000문제 가까이 필요하다
        val perPerfectLesson = Wallet.lessonReward(12, perfect = true)
        val lessonsFor10k = 10_000 / perPerfectLesson
        assertTrue("한 판에 너무 많이 벌면 안 됨", perPerfectLesson <= 200)
        assertTrue("10,000원에 레슨 60판 이상 필요해야 함", lessonsFor10k >= 60)
    }

    @Test fun moneyFormatting() {
        assertEquals("0", Wallet.formatNumber(0))
        assertEquals("150", Wallet.formatNumber(150))
        assertEquals("1,000", Wallet.formatNumber(1000))
        assertEquals("147,520", Wallet.formatNumber(147520))
        assertEquals("-300", Wallet.formatNumber(-300))
    }

    @Test fun dailyBonusesAreCapped() {
        assertTrue("복습 보너스에 하루 한도가 있어야 함", Wallet.REVIEW_DAILY_LIMIT in 1..5)
        // 하루에 보너스로만 벌 수 있는 최대치가 레슨 몇 판 수준을 넘지 않아야 한다
        val maxDailyBonus = Wallet.DAILY_GOAL_BONUS + Wallet.REVIEW_BONUS * Wallet.REVIEW_DAILY_LIMIT
        assertTrue("보너스만으로 하루 300원 넘게 벌면 안 됨", maxDailyBonus <= 300)
        // 같은 글자를 반복해서 써도 무한히 벌 수는 없다
        assertTrue(Wallet.LETTER_REPEAT_LIMIT in 2..10)
    }

    @Test fun shopCatalogIsSane() {
        assertTrue(Shop.ITEMS.isNotEmpty())
        // id 중복 없음
        assertEquals(Shop.ITEMS.size, Shop.ITEMS.map { it.id }.toSet().size)
        for (i in Shop.ITEMS) {
            assertTrue("${i.id}: 가격이 0 이하", i.price > 0)
            assertTrue("${i.id}: 이름 없음", i.name.isNotBlank())
            assertTrue("${i.id}: 이모지 없음", i.emoji.isNotBlank())
            if (i.kind == ShopKind.THEME) {
                assertTrue("${i.id}: 테마인데 색이 없음", i.color.startsWith("#"))
            }
        }
        // 가장 싼 물건도 레슨 한 판으로는 못 사야 "모으는 재미"가 있다
        val cheapest = Shop.ITEMS.minOf { it.price }
        assertTrue("최저가가 너무 쌈", cheapest >= Wallet.lessonReward(12, true))
    }

    @Test fun heartUpgradeHasCap() {
        assertTrue(Shop.MAX_HEARTS_CAP > Economy.MAX_HEARTS)
        assertEquals(8, Shop.MAX_HEARTS_CAP)
    }

    @Test fun heartRefillRespectsUpgradedMax() {
        val base = 1_000_000L
        val day = 100L
        // 최대치를 7로 올린 경우 하루가 바뀌면 7까지 찬다
        assertEquals(7, Economy.heartsNow(2, base, day, base + 60_000, day + 1, max = 7))
        // 30분당 1개 회복은 그대로, 상한만 달라진다
        assertEquals(7, Economy.heartsNow(2, base, day, base + 500L * 60_000, day, max = 7))
        assertEquals(5, Economy.heartsNow(2, base, day, base + 500L * 60_000, day, max = 5))
    }

    @Test fun payoutPresetsAreReasonable() {
        assertTrue(Shop.PAYOUT_PRESETS.isNotEmpty())
        assertTrue("정렬되어 있어야 함", Shop.PAYOUT_PRESETS == Shop.PAYOUT_PRESETS.sorted())
        assertTrue("최소 지급액이 너무 작음", Shop.PAYOUT_PRESETS.first() >= 1000)
    }
}
