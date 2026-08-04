package com.piyak.english.engine

import com.piyak.english.R

/**
 * 용돈 지갑. 단위는 원(₩).
 *
 * 설계 원칙: **모으기 어렵게.**
 * - 첫 시도에 맞힌 문제만 10원. 틀렸다가 맞히면 0원.
 * - 같은 레슨을 다시 풀면 0원 (레슨 첫 완료 때만 지급) → 쉬운 레슨 반복 파밍 불가
 * - 복습·출석 보너스는 하루 한도가 있다
 */
object Wallet {
    /** 첫 시도 정답 1문제 (문제당 1~10원 범위의 최대값) */
    const val PER_QUESTION = 10

    /** 레슨을 다 맞혔을 때 보너스 */
    const val PERFECT_BONUS = 20

    /** 알파벳 한 글자 첫 완성 — 문제 한 개와 같은 값 */
    const val PER_LETTER = 10

    /** 알파벳을 반복해서 쓸 때 (같은 글자 5회까지만) */
    const val PER_LETTER_REPEAT = 3
    const val LETTER_REPEAT_LIMIT = 5

    /** 오늘의 목표 달성 (하루 1회) */
    const val DAILY_GOAL_BONUS = 50

    /** 오답 복습 레슨 완료 (하루 한도 있음) */
    const val REVIEW_BONUS = 20
    const val REVIEW_DAILY_LIMIT = 3

    /** 레벨테스트 첫 완료 */
    const val PLACEMENT_BONUS = 100

    /** 레슨 첫 완료 보상 = 첫 시도 정답 수 × 10원 (+ 퍼펙트 보너스) */
    fun lessonReward(firstTryCorrect: Int, perfect: Boolean): Int =
        firstTryCorrect * PER_QUESTION + if (perfect) PERFECT_BONUS else 0

    /** 1,234 → "1,234원" */
    /**
     * 자릿수만 넣은 숫자 ("1,234"). 안드로이드에 기대지 않으므로 단위테스트가 쓴다.
     */
    fun formatNumber(won: Int): String = "%,d".format(won)

    /**
     * 화면에 뜨는 금액. 통화는 **원(₩) 그대로**다 — 부모가 실제로 주는 돈이 원화라서
     * 달러로 바꾸면 오히려 거짓말이 된다. 대신 언어마다 "1,200 won" 처럼 읽어 준다.
     */
    fun format(ctx: android.content.Context, won: Int): String =
        ctx.getString(R.string.wallet_amount, formatNumber(won))
}

enum class ShopKind { CONSUMABLE, UPGRADE, STICKER, THEME }

data class ShopItem(
    val id: String,
    val emoji: String,
    /** 화면에 뜰 이름·설명은 **문자열 리소스 id** 다 — 폰 언어를 따라가야 하므로 */
    val nameRes: Int,
    val descRes: Int,
    val price: Int,
    val kind: ShopKind,
    /** 소모품이 한 번에 몇 개 들어오는지 */
    val amount: Int = 1,
    /** 테마용 배경색 */
    val color: String = "",
)

object Shop {
    const val MAX_HEARTS_CAP = 8

    val ITEMS: List<ShopItem> = listOf(
        // --- 소모품 ---
        ShopItem(
            "heart_refill", "💖", R.string.shop_heart_refill,
            R.string.shop_heart_refill_d, 300, ShopKind.CONSUMABLE
        ),
        ShopItem(
            "hint3", "💡", R.string.shop_hint3,
            R.string.shop_hint3_d, 200, ShopKind.CONSUMABLE, amount = 3
        ),
        // --- 영구 업그레이드 ---
        ShopItem(
            "heart_up", "❤️‍🔥", R.string.shop_heart_up,
            R.string.shop_heart_up_d, 1500, ShopKind.UPGRADE
        ),
        // --- 스티커 (홈 칭호 옆에 자랑) ---
        ShopItem("st_star", "🌟", R.string.shop_st_star, R.string.shop_sticker_d, 400, ShopKind.STICKER),
        ShopItem("st_rocket", "🚀", R.string.shop_st_rocket, R.string.shop_sticker_d, 400, ShopKind.STICKER),
        ShopItem("st_crown", "👑", R.string.shop_st_crown, R.string.shop_sticker_d, 600, ShopKind.STICKER),
        ShopItem("st_rainbow", "🌈", R.string.shop_st_rainbow, R.string.shop_sticker_d, 400, ShopKind.STICKER),
        ShopItem("st_dino", "🦕", R.string.shop_st_dino, R.string.shop_sticker_d, 600, ShopKind.STICKER),
        ShopItem("st_cake", "🎂", R.string.shop_st_cake, R.string.shop_sticker_d, 400, ShopKind.STICKER),
        ShopItem("st_medal", "🏅", R.string.shop_st_medal, R.string.shop_sticker_d, 800, ShopKind.STICKER),
        ShopItem("st_unicorn", "🦄", R.string.shop_st_unicorn, R.string.shop_sticker_d, 1000, ShopKind.STICKER),
        // --- 테마 (홈 배경색) ---
        ShopItem("th_sky", "🩵", R.string.shop_th_sky, R.string.shop_th_sky_d, 800, ShopKind.THEME, color = "#E3F4FD"),
        ShopItem("th_mint", "🍃", R.string.shop_th_mint, R.string.shop_th_mint_d, 800, ShopKind.THEME, color = "#E4F6EF"),
        ShopItem("th_pink", "🌸", R.string.shop_th_pink, R.string.shop_th_pink_d, 800, ShopKind.THEME, color = "#FDECF1"),
        ShopItem("th_lav", "💜", R.string.shop_th_lav, R.string.shop_th_lav_d, 800, ShopKind.THEME, color = "#F0EAFB"),
    )

    fun byId(id: String): ShopItem? = ITEMS.firstOrNull { it.id == id }

    /** 기본(무료) 테마 */
    const val DEFAULT_THEME_COLOR = "#FFF8E7"

    /** 현금 지급 시 고를 수 있는 금액 */
    val PAYOUT_PRESETS = listOf(1000, 3000, 5000, 10000)
}

/** 지갑 기록 한 줄 */
data class WalletLog(val at: Long, val kind: String, val amount: Int, val note: String) {
    val isEarn: Boolean get() = amount > 0
}
