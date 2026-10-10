import XCTest
@testable import PeepEnglish

final class MiniGamesTests: XCTestCase {

    /// 코틀린 Random(42) — 시험 하나마다 새 인스턴스라 매번 같은 수열에서 시작한다
    private let rnd = XorWowRandom(seed: 42)

    func test_everySubjectHasGames() {
        XCTAssertTrue(MiniGames.forSubject(.MATH).isNotEmpty())
        XCTAssertTrue(MiniGames.forSubject(.ENGLISH).isNotEmpty())
        // id 중복 없음
        XCTAssertEqual(Set(MiniGames.ALL.map { $0.id }).count, MiniGames.ALL.count)
        for g in MiniGames.ALL {
            XCTAssertTrue(g.titleRes != 0 && g.descRes != 0 && g.emoji.isNotBlank())
            XCTAssertTrue(g.color.startsWith("#"))
        }
    }

    /// 풍선 게임: 정답이 반드시 보기 안에 있어야 터뜨릴 수 있다
    func test_balloonRoundsAlwaysContainTheAnswer() {
        for level in 1...5 {
            for _ in 0..<200 {
                let r = MiniGames.balloonMath(level, rnd)
                XCTAssertTrue(r.options.contains(r.answer), "보기에 정답이 없음: \(r)")
                XCTAssertEqual(Set(r.options).count, r.options.count, "보기 중복")
                XCTAssertTrue(r.options.count >= 4, "보기가 너무 적음")
                // 뺄셈 답이 음수면 아이가 혼란스럽다
                XCTAssertTrue(Int(r.answer)! >= 0, "음수 답: \(r.question)")
            }
        }
    }

    func test_englishBalloonUsesPicturesAndHasAnswer() {
        for _ in 0..<100 {
            let r = MiniGames.balloonEnglish(rnd)
            XCTAssertTrue(r.options.contains(r.answer))
            XCTAssertEqual(Set(r.options).count, r.options.count)
            XCTAssertTrue(!r.speak.isNullOrBlank(), "읽어 줄 낱말이 없음")
        }
    }

    func test_basketTargetsStayCountable() {
        for level in 1...3 {
            for _ in 0..<100 {
                let r = MiniGames.basketRound(level, rnd)
                let n = Int(r.answer)!
                XCTAssertTrue((1...15).contains(n), "담을 개수가 이상함: \(n)")
                XCTAssertTrue(!r.emoji.isNullOrBlank(), "그림이 없음")
            }
        }
    }

    /// 선 잇기: 4쌍이고 답이 겹치면 안 된다 (겹치면 어느 쪽에 이어도 맞아 버린다)
    func test_lineMathPairsHaveDistinctAnswers() {
        for _ in 0..<100 {
            let pairs = MiniGames.lineMath(3, rnd)
            XCTAssertEqual(pairs.count, 4)
            XCTAssertEqual(Set(pairs.map { $0.second }).count, 4, "답이 겹침: \(pairs)")
            XCTAssertEqual(Set(pairs.map { $0.first }).count, 4, "문제가 겹침: \(pairs)")
        }
    }

    func test_lineEnglishPairsAreDistinct() {
        for _ in 0..<100 {
            let pairs = MiniGames.lineEnglish(rnd)
            XCTAssertEqual(pairs.count, 4)
            XCTAssertEqual(Set(pairs.map { $0.first }).count, 4)
            XCTAssertEqual(Set(pairs.map { $0.second }).count, 4)
        }
    }

    func test_wrongNumbersNeverRepeatOrGoNegative() {
        for answer in 0...30 {
            let list = MiniGames.wrongNumbers(answer, 6, rnd)
            XCTAssertEqual(list.count, 6)
            XCTAssertEqual(Set(list).count, 6, "중복")
            XCTAssertTrue(list.contains(answer), "정답이 빠짐")
            XCTAssertTrue(list.allSatisfy { $0 >= 0 }, "음수 포함")
        }
    }

    /// 게임으로 용돈을 무한히 벌 수 없어야 한다
    func test_gameRewardsAreCapped() {
        let max = 10 * GameReward.SCORE_PER_HIT
        XCTAssertEqual(GameReward.coinsFor(max, max), GameReward.MAX_COINS)
        XCTAssertEqual(GameReward.coinsFor(0, max), 0)
        XCTAssertTrue(GameReward.coinsFor(max / 2, max) < GameReward.MAX_COINS)
        // 하루 최대 게임 용돈이 레슨 한 판 보상을 넘지 않아야 공부가 손해가 아니다
        let dailyMax = GameReward.MAX_COINS * GameReward.DAILY_PAID_ROUNDS
        let perLesson = Wallet.lessonReward(12, true)
        XCTAssertTrue(dailyMax <= perLesson, "게임이 공부보다 돈이 되면 안 됨: \(dailyMax) vs \(perLesson)")
    }

    func test_scoreToStarsAndXp() {
        let max = 100
        XCTAssertEqual(GameReward.stars(100, max), 3)
        XCTAssertEqual(GameReward.stars(70, max), 2)
        XCTAssertEqual(GameReward.stars(10, max), 1)
        XCTAssertEqual(GameReward.stars(0, max), 0)
        XCTAssertTrue((1...30).contains(GameReward.xpFor(100)))
        XCTAssertEqual(GameReward.xpFor(0), 0)
    }
}
