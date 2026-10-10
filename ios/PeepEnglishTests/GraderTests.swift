import XCTest
@testable import PeepEnglish

final class GraderTests: XCTestCase {

    func test_normalizeBasics() {
        XCTAssertEqual(Grader.normalize("I'm a student."), "i am a student")
        XCTAssertEqual(Grader.normalize("  Don't   worry!  "), "do not worry")
        XCTAssertEqual(Grader.normalize("It’s nice"), "it is nice") // 유니코드 아포스트로피
        XCTAssertEqual(Grader.normalize("Hello!!!"), "hello")
    }

    func test_gradeExact() {
        XCTAssertTrue(Grader.grade("I am happy", "I'm happy.").correct)
        XCTAssertTrue(Grader.grade("i am happy", "I AM HAPPY").correct)
        XCTAssertFalse(Grader.grade("", "hello").correct)
    }

    func test_gradeAlts() {
        let r = Grader.grade("I would like a coffee", "I'd like a coffee", ["I want a coffee"])
        XCTAssertTrue(r.correct)
        XCTAssertTrue(Grader.grade("I want a coffee", "I'd like a coffee", ["I want a coffee"]).correct)
    }

    func test_gradeTypoTolerance() {
        // 길이 >4 → 편집거리 1 허용
        let r = Grader.grade("aple", "apple")
        XCTAssertTrue(r.correct); XCTAssertTrue(r.typo)
        // 길이 >10 → 거리 2 허용
        XCTAssertTrue(Grader.grade("beautifl day", "beautiful day").correct)
        // 짧은 단어(4자 이하)는 오타 불허
        XCTAssertFalse(Grader.grade("ct", "cat").correct)
        // 심한 오타는 불허
        XCTAssertFalse(Grader.grade("aplle pie yum", "apple").correct)
    }

    func test_gradeOrder() {
        XCTAssertTrue(Grader.gradeOrder(["I", "like", "cats"], ["I", "like", "cats"]))
        XCTAssertFalse(Grader.gradeOrder(["like", "I", "cats"], ["I", "like", "cats"]))
        XCTAssertFalse(Grader.gradeOrder(["I", "like"], ["I", "like", "cats"]))
    }

    func test_speakLongSentence() {
        let target = "I would like to book a table for two people"
        XCTAssertTrue(Grader.gradeSpeak("I would like to book a table for two people", target))
        // 10 단어 중 2개 오차 → 0.8 ≥ 0.75 통과
        XCTAssertTrue(Grader.gradeSpeak("I would like to book table for two person", target))
        // 절반만 말하면 탈락
        XCTAssertFalse(Grader.gradeSpeak("I would like", target))
    }

    func test_speakShortSentence() {
        // 3단어: 1오차 허용
        XCTAssertTrue(Grader.gradeSpeak("good morning everyone", "Good morning, everyone!"))
        XCTAssertTrue(Grader.gradeSpeak("good morning friend", "Good morning, everyone!"))
        XCTAssertFalse(Grader.gradeSpeak("good", "Good morning, everyone!"))
        // 1~2단어: 정확히
        XCTAssertTrue(Grader.gradeSpeak("Hello", "hello"))
        XCTAssertFalse(Grader.gradeSpeak("Hallo there", "hello"))
    }

    func test_speakScoreRange() {
        XCTAssertEqual(Grader.speakScore("hello world", "Hello, world!"), 100)
        XCTAssertTrue(Grader.speakScore("totally different words here", "hello world") < 50)
    }

    func test_levenshteinBasics() {
        XCTAssertEqual(Grader.levenshtein("abc", "abc"), 0)
        XCTAssertEqual(Grader.levenshtein("abc", "abd"), 1)
        XCTAssertEqual(Grader.levenshtein("", "abc"), 3)
    }
}
