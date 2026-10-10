import XCTest
@testable import PeepEnglish

final class WalletTests: XCTestCase {

    func test_oneQuestionIsTenWon() {
        // 문제 하나는 1~10원 범위 안이어야 한다
        XCTAssertTrue((1...10).contains(Wallet.PER_QUESTION))
        XCTAssertTrue((1...10).contains(Wallet.PER_LETTER), "알파벳 한 글자도 문제 하나 수준")
        XCTAssertTrue(Wallet.PER_LETTER_REPEAT < Wallet.PER_LETTER, "반복 쓰기는 더 적게")
        XCTAssertEqual(
            Wallet.lessonReward(12, true),
            12 * Wallet.PER_QUESTION + Wallet.PERFECT_BONUS
        )
        XCTAssertEqual(Wallet.lessonReward(12, false), 120)
        // 틀린 문제는 한 푼도 안 준다 (첫 시도 정답만 계산)
        XCTAssertEqual(Wallet.lessonReward(8, false), 80)
        XCTAssertEqual(Wallet.lessonReward(0, false), 0)
    }

    func test_rewardsAreHardToFarm() {
        // 10,000원을 모으려면 첫 시도 정답이 1,000문제 가까이 필요하다
        let perPerfectLesson = Wallet.lessonReward(12, true)
        let lessonsFor10k = 10_000 / perPerfectLesson
        XCTAssertTrue(perPerfectLesson <= 200, "한 판에 너무 많이 벌면 안 됨")
        XCTAssertTrue(lessonsFor10k >= 60, "10,000원에 레슨 60판 이상 필요해야 함")
    }

    func test_moneyFormatting() {
        XCTAssertEqual(Wallet.formatNumber(0), "0")
        XCTAssertEqual(Wallet.formatNumber(150), "150")
        XCTAssertEqual(Wallet.formatNumber(1000), "1,000")
        XCTAssertEqual(Wallet.formatNumber(147520), "147,520")
        XCTAssertEqual(Wallet.formatNumber(-300), "-300")
    }

    func test_dailyBonusesAreCapped() {
        XCTAssertTrue((1...5).contains(Wallet.REVIEW_DAILY_LIMIT), "복습 보너스에 하루 한도가 있어야 함")
        // 하루에 보너스로만 벌 수 있는 최대치가 레슨 몇 판 수준을 넘지 않아야 한다
        let maxDailyBonus = Wallet.DAILY_GOAL_BONUS + Wallet.REVIEW_BONUS * Wallet.REVIEW_DAILY_LIMIT
        XCTAssertTrue(maxDailyBonus <= 300, "보너스만으로 하루 300원 넘게 벌면 안 됨")
        // 같은 글자를 반복해서 써도 무한히 벌 수는 없다
        XCTAssertTrue((2...10).contains(Wallet.LETTER_REPEAT_LIMIT))
    }

    func test_shopCatalogIsSane() {
        XCTAssertTrue(Shop.ITEMS.isNotEmpty())
        // id 중복 없음
        XCTAssertEqual(Set(Shop.ITEMS.map { $0.id }).count, Shop.ITEMS.count)
        for i in Shop.ITEMS {
            XCTAssertTrue(i.price > 0, "\(i.id): 가격이 0 이하")
            XCTAssertTrue(i.nameRes != 0, "\(i.id): 이름 리소스 없음")
            XCTAssertTrue(i.emoji.isNotBlank(), "\(i.id): 이모지 없음")
            if i.kind == .THEME {
                XCTAssertTrue(i.color.startsWith("#"), "\(i.id): 테마인데 색이 없음")
            }
        }
        // 가장 싼 물건도 레슨 한 판으로는 못 사야 "모으는 재미"가 있다
        let cheapest = Shop.ITEMS.map { $0.price }.min()!
        XCTAssertTrue(cheapest >= Wallet.lessonReward(12, true), "최저가가 너무 쌈")
    }

    func test_heartUpgradeHasCap() {
        XCTAssertTrue(Shop.MAX_HEARTS_CAP > Economy.MAX_HEARTS)
        XCTAssertEqual(Shop.MAX_HEARTS_CAP, 8)
    }

    func test_heartRefillRespectsUpgradedMax() {
        let base = 1_000_000
        let day = 100
        // 최대치를 7로 올린 경우 하루가 바뀌면 7까지 찬다
        XCTAssertEqual(Economy.heartsNow(2, base, day, base + 60_000, day + 1, max: 7), 7)
        // 30분당 1개 회복은 그대로, 상한만 달라진다
        XCTAssertEqual(Economy.heartsNow(2, base, day, base + 500 * 60_000, day, max: 7), 7)
        XCTAssertEqual(Economy.heartsNow(2, base, day, base + 500 * 60_000, day, max: 5), 5)
    }

    func test_payoutPresetsAreReasonable() {
        XCTAssertTrue(Shop.PAYOUT_PRESETS.isNotEmpty())
        XCTAssertTrue(Shop.PAYOUT_PRESETS == Shop.PAYOUT_PRESETS.sorted(), "정렬되어 있어야 함")
        XCTAssertTrue(Shop.PAYOUT_PRESETS.first! >= 1000, "최소 지급액이 너무 작음")
    }
}
