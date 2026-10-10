import XCTest
@testable import PeepEnglish

final class EconomyTests: XCTestCase {

    func test_levels() {
        XCTAssertEqual(Economy.levelFor(0), 0)
        XCTAssertEqual(Economy.levelFor(59), 0)
        XCTAssertEqual(Economy.levelFor(60), 1)
        XCTAssertEqual(Economy.levelFor(179), 1)
        XCTAssertEqual(Economy.levelFor(180), 2)
        XCTAssertEqual(Economy.xpForLevel(1), 60)
        XCTAssertEqual(Economy.xpForLevel(2), 180)
    }

    func test_heartsRefill30Min() {
        let base = 1_000_000
        let day = 100
        // 29분 → 회복 없음
        XCTAssertEqual(Economy.heartsNow(2, base, day, base + 29 * 60_000, day), 2)
        // 30분 → +1
        XCTAssertEqual(Economy.heartsNow(2, base, day, base + 30 * 60_000, day), 3)
        // 오래 지나도 최대 5
        XCTAssertEqual(Economy.heartsNow(2, base, day, base + 500 * 60_000, day), 5)
        // 날짜가 바뀌면 풀 회복
        XCTAssertEqual(Economy.heartsNow(0, base, day, base + 60_000, day + 1), 5)
    }

    func test_streakCurrentAndBest() {
        let today = 1000
        // 오늘 포함 3일 연속, 과거에 5일 연속
        let days: Set<Int> = [today, today - 1, today - 2, today - 10, today - 11, today - 12, today - 13, today - 14]
        let (cur, best) = Economy.streak(days, today)
        XCTAssertEqual(cur, 3)
        XCTAssertEqual(best, 5)
    }

    func test_streakYesterdayStillCounts() {
        let today = 1000
        let (cur, _) = Economy.streak([today - 1, today - 2], today)
        XCTAssertEqual(cur, 2) // 오늘 아직 안 했어도 유지
        let (cur2, _) = Economy.streak([today - 2, today - 3], today)
        XCTAssertEqual(cur2, 0) // 하루 건너뛰면 끊김
    }

    func test_placementLadder() {
        XCTAssertEqual(Placement.nextLevel(3, true), 4)
        XCTAssertEqual(Placement.nextLevel(3, false), 2)
        XCTAssertEqual(Placement.nextLevel(10, true), 10)
        XCTAssertEqual(Placement.nextLevel(1, false), 1)
    }

    func test_placementMedian() {
        // 마지막 10개: 5,6,5,6,7,6,5,6,7,6 → 정렬 중앙값(인덱스5) = 6
        let hist = [3, 4, 5, 6, 5, 6, 7, 6, 5, 6, 7, 6].map { ($0, true) }
        XCTAssertEqual(Placement.placeLevel(hist), 6)
        XCTAssertEqual(Placement.placeLevel([]), 1)
    }
}
