import Foundation

/// 용돈 지갑. 단위는 원(₩).
///
/// 설계 원칙: **모으기 어렵게.** 첫 시도 정답만 10원, 같은 레슨 재도전은 0원,
/// 복습·출석 보너스는 하루 한도가 있다.
enum Wallet {
    /// 첫 시도 정답 1문제 (문제당 1~10원 범위의 최대값)
    static let PER_QUESTION = 10

    /// 레슨을 다 맞혔을 때 보너스
    static let PERFECT_BONUS = 20

    /// 알파벳 한 글자 첫 완성 — 문제 한 개와 같은 값
    static let PER_LETTER = 10

    /// 알파벳을 반복해서 쓸 때 (같은 글자 5회까지만)
    static let PER_LETTER_REPEAT = 3
    static let LETTER_REPEAT_LIMIT = 5

    /// 오늘의 목표 달성 (하루 1회)
    static let DAILY_GOAL_BONUS = 50

    /// 오답 복습 레슨 완료 (하루 한도 있음)
    static let REVIEW_BONUS = 20
    static let REVIEW_DAILY_LIMIT = 3

    /// 레벨테스트 첫 완료
    static let PLACEMENT_BONUS = 100

    /// 레슨 첫 완료 보상 = 첫 시도 정답 수 × 10원 (+ 퍼펙트 보너스)
    static func lessonReward(_ firstTryCorrect: Int, _ perfect: Bool) -> Int {
        firstTryCorrect * PER_QUESTION + (perfect ? PERFECT_BONUS : 0)
    }

    /// 자릿수만 넣은 숫자 ("1,234"). 단위테스트가 쓴다.
    static func formatNumber(_ won: Int) -> String { "%,d".format(won) }

    /// 화면에 뜨는 금액. 통화는 원(₩) 그대로, 언어마다 "1,200 won" 처럼 읽어 준다.
    static func format(_ ctx: Context, _ won: Int) -> String {
        ctx.getString(R.string.wallet_amount, formatNumber(won))
    }
}

enum ShopKind: String, KotlinEnum { case CONSUMABLE, UPGRADE, STICKER, THEME }

struct ShopItem: Equatable {
    var id: String
    var emoji: String
    /// 화면에 뜰 이름·설명은 **문자열 리소스 id** 다
    var nameRes: Int
    var descRes: Int
    var price: Int
    var kind: ShopKind
    /// 소모품이 한 번에 몇 개 들어오는지
    var amount: Int
    /// 테마용 배경색
    var color: String

    init(_ id: String, _ emoji: String, _ nameRes: Int, _ descRes: Int, _ price: Int, _ kind: ShopKind,
         amount: Int = 1, color: String = "") {
        self.id = id
        self.emoji = emoji
        self.nameRes = nameRes
        self.descRes = descRes
        self.price = price
        self.kind = kind
        self.amount = amount
        self.color = color
    }
}

enum Shop {
    static let MAX_HEARTS_CAP = 8

    static let ITEMS: [ShopItem] = [
        // --- 소모품 ---
        ShopItem("heart_refill", "💖", R.string.shop_heart_refill,
                 R.string.shop_heart_refill_d, 300, .CONSUMABLE),
        ShopItem("hint3", "💡", R.string.shop_hint3,
                 R.string.shop_hint3_d, 200, .CONSUMABLE, amount: 3),
        // --- 영구 업그레이드 ---
        ShopItem("heart_up", "❤️‍🔥", R.string.shop_heart_up,
                 R.string.shop_heart_up_d, 1500, .UPGRADE),
        // --- 스티커 (홈 칭호 옆에 자랑) ---
        ShopItem("st_star", "🌟", R.string.shop_st_star, R.string.shop_sticker_d, 400, .STICKER),
        ShopItem("st_rocket", "🚀", R.string.shop_st_rocket, R.string.shop_sticker_d, 400, .STICKER),
        ShopItem("st_crown", "👑", R.string.shop_st_crown, R.string.shop_sticker_d, 600, .STICKER),
        ShopItem("st_rainbow", "🌈", R.string.shop_st_rainbow, R.string.shop_sticker_d, 400, .STICKER),
        ShopItem("st_dino", "🦕", R.string.shop_st_dino, R.string.shop_sticker_d, 600, .STICKER),
        ShopItem("st_cake", "🎂", R.string.shop_st_cake, R.string.shop_sticker_d, 400, .STICKER),
        ShopItem("st_medal", "🏅", R.string.shop_st_medal, R.string.shop_sticker_d, 800, .STICKER),
        ShopItem("st_unicorn", "🦄", R.string.shop_st_unicorn, R.string.shop_sticker_d, 1000, .STICKER),
        // --- 테마 (홈 배경색) ---
        ShopItem("th_sky", "🩵", R.string.shop_th_sky, R.string.shop_th_sky_d, 800, .THEME, color: "#E3F4FD"),
        ShopItem("th_mint", "🍃", R.string.shop_th_mint, R.string.shop_th_mint_d, 800, .THEME, color: "#E4F6EF"),
        ShopItem("th_pink", "🌸", R.string.shop_th_pink, R.string.shop_th_pink_d, 800, .THEME, color: "#FDECF1"),
        ShopItem("th_lav", "💜", R.string.shop_th_lav, R.string.shop_th_lav_d, 800, .THEME, color: "#F0EAFB"),
    ]

    static func byId(_ id: String) -> ShopItem? { ITEMS.first { $0.id == id } }

    /// 기본(무료) 테마
    static let DEFAULT_THEME_COLOR = "#FFF8E7"

    /// 현금 지급 시 고를 수 있는 금액
    static let PAYOUT_PRESETS = [1000, 3000, 5000, 10000]
}

/// 지갑 기록 한 줄
struct WalletLog: Equatable {
    var at: Int
    var kind: String
    var amount: Int
    var note: String

    init(_ at: Int, _ kind: String, _ amount: Int, _ note: String) {
        self.at = at
        self.kind = kind
        self.amount = amount
        self.note = note
    }

    var isEarn: Bool { amount > 0 }
}
