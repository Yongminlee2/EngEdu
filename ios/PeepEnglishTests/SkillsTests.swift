import XCTest
@testable import PeepEnglish

final class SkillsTests: XCTestCase {

    private func state(_ id: String, _ correct: Int, _ attempts: Int? = nil) -> SkillState {
        SkillState(Skills.def(id), correct: correct, attempts: attempts ?? correct)
    }

    func test_skillLevelThresholds() {
        XCTAssertEqual(Skills.levelFor(0), 0)
        XCTAssertEqual(Skills.levelFor(9), 0)
        XCTAssertEqual(Skills.levelFor(10), 1)
        XCTAssertEqual(Skills.levelFor(29), 1)
        XCTAssertEqual(Skills.levelFor(30), 2)
        XCTAssertEqual(Skills.levelFor(60), 3)
        XCTAssertEqual(Skills.levelFor(550), 10)
        // 최대 레벨 상한
        XCTAssertEqual(Skills.levelFor(99999), 10)
    }

    func test_skillProgressBetweenLevels() {
        // Lv1(10)~Lv2(30) 사이 20문제 구간의 절반 = 20정답
        XCTAssertEqual(Skills.progressFor(20), 0.5, accuracy: 0.001)
        XCTAssertEqual(Skills.progressFor(10), 0, accuracy: 0.001)
        XCTAssertEqual(Skills.progressFor(550), 1, accuracy: 0.001)
    }

    func test_skillStateDerivedValues() {
        let s = state("listening", 30, 40)
        XCTAssertEqual(s.level, 2)
        XCTAssertEqual(s.accuracy, 75)
        XCTAssertEqual(s.nextLevelNeed, 30) // Lv3 = 60정답 필요
        XCTAssertEqual(state("vocab", 0, 0).accuracy, 0) // 0으로 나누지 않음
    }

    func test_overallIsAverageOfSkillLevels() {
        let states = [
            state("listening", 60), // Lv3
            state("speaking", 10),  // Lv1
            state("writing", 30),   // Lv2
            state("grammar", 0),    // Lv0
            state("reading", 0),    // Lv0
            state("vocab", 0),      // Lv0
        ]
        XCTAssertEqual(Skills.overallLevel(states), 1, accuracy: 0.001) // (3+1+2+0+0+0)/6
        XCTAssertEqual(Skills.overallLevel([]), 0, accuracy: 0.001)
    }

    func test_weakestPrefersUntouchedSkill() {
        let states = [
            state("listening", 60),
            state("speaking", 0),
            state("writing", 30),
        ]
        XCTAssertEqual(Skills.weakest(states)!.def.id, "speaking")
    }

    func test_ranksProgressWithOverallLevel() {
        XCTAssertEqual(Ranks.of(0).emoji, "🥚")
        XCTAssertEqual(Ranks.of(1.5).emoji, "🐥")
        XCTAssertEqual(Ranks.of(10).emoji, "👑")
        // 다음 칭호와 진행률
        XCTAssertEqual(Ranks.next(0)!.emoji, "🐣")
        XCTAssertTrue(Ranks.next(10) == nil)
        XCTAssertEqual(Ranks.progress(0), 0, accuracy: 0.001)
        XCTAssertEqual(Ranks.progress(10), 1, accuracy: 0.001)
        XCTAssertTrue(Ranks.progress(0.35) > 0.4) // 0.7 구간의 절반쯤
    }

    func test_dailyGoalProgress() {
        XCTAssertEqual(DailyGoal.progress(25, 50), 0.5, accuracy: 0.001)
        XCTAssertEqual(DailyGoal.progress(80, 50), 1, accuracy: 0.001) // 초과해도 1을 넘지 않음
        XCTAssertTrue(DailyGoal.isDone(50, 50))
        XCTAssertFalse(DailyGoal.isDone(49, 50))
    }

    func test_questionSkillDefaults() {
        XCTAssertEqual(Question.Mcq("q1", "p", ["a", "b", "c", "d"], 0).skill, "vocab")
        XCTAssertEqual(Question.Mcq("q2", "p", ["a", "b", "c", "d"], 0, passage: "text").skill, "reading")
        XCTAssertEqual(Question.ListenMcq("q3", "hi", "p", ["a", "b", "c", "d"], 0).skill, "listening")
        XCTAssertEqual(Question.Dictation("q4", "hi", "hi").skill, "listening")
        XCTAssertEqual(Question.Order("q5", "안녕", "hi there").skill, "writing")
        XCTAssertEqual(Question.TypeTranslate("q6", "안녕", "hi").skill, "writing")
        XCTAssertEqual(Question.Speak("q7", "hi").skill, "speaking")
    }

    func test_skillTagOverridesDefault() {
        // 문법 문제는 형태가 mcq 라서 팩의 skill 태그로만 구분된다
        let q = Question.Mcq("q8", "I ___ a student.", ["am", "is", "are", "be"], 0)
        XCTAssertEqual(q.skill, "vocab")
        q.skillTag = "grammar"
        XCTAssertEqual(q.skill, "grammar")
    }
}
