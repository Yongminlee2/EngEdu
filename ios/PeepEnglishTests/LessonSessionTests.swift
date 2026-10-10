import XCTest
@testable import PeepEnglish

final class LessonSessionTests: XCTestCase {

    private func mcq(_ id: String) -> Question { Question.Mcq(id, "p", ["a", "b", "c", "d"], 0) }
    private func qs(_ n: Int) -> [Question] { (1...n).map { mcq("q\($0)") } }

    func test_allCorrectIsPerfect() {
        let s = LessonSession(qs(3), hearts: 5)
        for _ in 0..<3 { XCTAssertTrue(s.submit(true)) }
        XCTAssertTrue(s.isFinished)
        XCTAssertTrue(s.isPerfect)
        XCTAssertEqual(s.firstTryCorrect, 3)
        XCTAssertEqual(s.xpEarned(), 3 * 2 + 10 + 5)
        XCTAssertEqual(s.stars(), 3)
    }

    func test_wrongRequeuesAndCostsHeart() {
        let s = LessonSession(qs(2), hearts: 5)
        let first = s.current()!
        s.submit(false) // q1 틀림 → 큐 끝으로
        XCTAssertEqual(s.hearts, 4)
        XCTAssertEqual(s.current()!.id, "q2")
        s.submit(true) // q2 정답
        XCTAssertEqual(s.current()!.id, first.id) // q1 재출제
        s.submit(true)
        XCTAssertTrue(s.isFinished)
        XCTAssertFalse(s.isPerfect)
        XCTAssertEqual(s.firstTryCorrect, 1)
        XCTAssertEqual(s.xpEarned(), 1 * 2 + 10)
    }

    func test_heartsZeroFails() {
        let s = LessonSession(qs(3), hearts: 2)
        s.submit(false)
        s.submit(false)
        XCTAssertTrue(s.failed)
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.xpEarned(), 0)
    }

    func test_noHeartsModeNeverFails() {
        let s = LessonSession(qs(2), hearts: 1, useHearts: false)
        s.submit(false); s.submit(false); s.submit(false)
        XCTAssertFalse(s.failed)
    }

    func test_submitNoPenaltySkipsRequeue() {
        let s = LessonSession(qs(2), hearts: 5)
        s.submitNoPenalty(false) // 매칭 실수 — 하트 유지, 재출제 없음
        XCTAssertEqual(s.hearts, 5)
        XCTAssertEqual(s.current()!.id, "q2")
        s.submit(true)
        XCTAssertTrue(s.isFinished)
        XCTAssertFalse(s.isPerfect)
    }

    func test_progressAdvancesOnlyOnCorrect() {
        let s = LessonSession(qs(4), hearts: 5)
        XCTAssertEqual(s.progress, 0)
        s.submit(true)
        XCTAssertEqual(s.progress, 0.25)
        s.submit(false)
        XCTAssertEqual(s.progress, 0.25)
    }

    func test_starsByAccuracy() {
        // 5문제 중 1개 틀림 → 80% → 별 2
        let s = LessonSession(qs(5), hearts: 5)
        s.submit(false)
        for _ in 0..<4 { s.submit(true) }
        s.submit(true) // 재출제분
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.stars(), 2)
    }
}
