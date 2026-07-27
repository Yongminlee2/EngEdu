package com.piyak.english.engine

/**
 * 용돈 지갑. 단위는 원(₩).
 *
 * 설계 원칙: **모으기 어렵게.**
 * - 첫 시도에 맞힌 문제만 10원. 틀렸다가 맞히면 0원.
 * - 같은 레슨을 다시 풀면 0원 (레슨 첫 완료 때만 지급) → 쉬운 레슨 반복 파밍 불가
 * - 복습·출석 보너스는 하루 한도가 있다
 */
object Wallet {
    /** 첫 시도 정답 1문제 */
    const val PER_QUESTION = 10

    /** 레슨을 다 맞혔을 때 보너스 */
    const val PERFECT_BONUS = 30

    /** 알파벳 한 글자 첫 완성 */
    const val PER_LETTER = 50

    /** 오늘의 목표 달성 (하루 1회) */
    const val DAILY_GOAL_BONUS = 100

    /** 오답 복습 레슨 완료 (하루 한도 있음) */
    const val REVIEW_BONUS = 50
    const val REVIEW_DAILY_LIMIT = 3

    /** 레벨테스트 첫 완료 */
    const val PLACEMENT_BONUS = 200

    /** 레슨 첫 완료 보상 = 첫 시도 정답 수 × 10원 (+ 퍼펙트 보너스) */
    fun lessonReward(firstTryCorrect: Int, perfect: Boolean): Int =
        firstTryCorrect * PER_QUESTION + if (perfect) PERFECT_BONUS else 0

    /** 1,234 → "1,234원" */
    fun format(won: Int): String = "%,d원".format(won)
}

enum class ShopKind { CONSUMABLE, UPGRADE, STICKER, THEME }

data class ShopItem(
    val id: String,
    val emoji: String,
    val name: String,
    val desc: String,
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
            "heart_refill", "💖", "하트 가득 채우기",
            "하트를 최대치까지 즉시 회복해요", 300, ShopKind.CONSUMABLE
        ),
        ShopItem(
            "hint3", "💡", "힌트권 3개",
            "4지선다에서 오답 2개를 지워 줘요", 200, ShopKind.CONSUMABLE, amount = 3
        ),
        // --- 영구 업그레이드 ---
        ShopItem(
            "heart_up", "❤️‍🔥", "하트 최대치 +1",
            "하트를 한 개 더 가질 수 있어요 (최대 8개)", 1500, ShopKind.UPGRADE
        ),
        // --- 스티커 (홈 칭호 옆에 자랑) ---
        ShopItem("st_star", "🌟", "반짝 별 스티커", "홈 화면에 붙일 수 있어요", 400, ShopKind.STICKER),
        ShopItem("st_rocket", "🚀", "로켓 스티커", "홈 화면에 붙일 수 있어요", 400, ShopKind.STICKER),
        ShopItem("st_crown", "👑", "왕관 스티커", "홈 화면에 붙일 수 있어요", 600, ShopKind.STICKER),
        ShopItem("st_rainbow", "🌈", "무지개 스티커", "홈 화면에 붙일 수 있어요", 400, ShopKind.STICKER),
        ShopItem("st_dino", "🦕", "공룡 스티커", "홈 화면에 붙일 수 있어요", 600, ShopKind.STICKER),
        ShopItem("st_cake", "🎂", "케이크 스티커", "홈 화면에 붙일 수 있어요", 400, ShopKind.STICKER),
        ShopItem("st_medal", "🏅", "금메달 스티커", "홈 화면에 붙일 수 있어요", 800, ShopKind.STICKER),
        ShopItem("st_unicorn", "🦄", "유니콘 스티커", "홈 화면에 붙일 수 있어요", 1000, ShopKind.STICKER),
        // --- 테마 (홈 배경색) ---
        ShopItem("th_sky", "🩵", "하늘 테마", "홈 배경이 하늘색이 돼요", 800, ShopKind.THEME, color = "#E3F4FD"),
        ShopItem("th_mint", "🍃", "민트 테마", "홈 배경이 민트색이 돼요", 800, ShopKind.THEME, color = "#E4F6EF"),
        ShopItem("th_pink", "🌸", "벚꽃 테마", "홈 배경이 분홍색이 돼요", 800, ShopKind.THEME, color = "#FDECF1"),
        ShopItem("th_lav", "💜", "라벤더 테마", "홈 배경이 보라색이 돼요", 800, ShopKind.THEME, color = "#F0EAFB"),
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
