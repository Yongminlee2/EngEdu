import XCTest
@testable import PeepEnglish

/// 과목별 배치고사가 서로 섞이지 않는지 검증한다
final class PlacementSubjectTests: XCTestCase {

    func test_eachSubjectHasItsOwnLevelRange() {
        XCTAssertEqual(Placement.maxLevel(.ENGLISH), 10)
        XCTAssertEqual(Placement.maxLevel(.MATH), 13)
        // 수학은 13단계까지 올라갈 수 있어야 한다
        XCTAssertEqual(Placement.nextLevel(13, true, 13), 13)
        XCTAssertEqual(Placement.nextLevel(10, true, 10), 10)
        XCTAssertEqual(Placement.nextLevel(1, false, 13), 1)
    }

    func test_progressKeysAreSeparatePerSubject() {
        XCTAssertNotEqual(Placement.levelKey(.ENGLISH), Placement.levelKey(.MATH))
        XCTAssertNotEqual(Placement.doneKey(.ENGLISH), Placement.doneKey(.MATH))
        XCTAssertEqual(Placement.levelKey(.ENGLISH), "placement_level")
        XCTAssertEqual(Placement.levelKey(.MATH), "math_placement_level")
    }

    func test_levelNamesMatchTheSubject() {
        // 이름은 리소스라 Context 없는 시험에서는 id 존재만 본다
        XCTAssertTrue(Placement.LEVEL_NAMES[1]! != 0)
        // 수학은 학년 이름을 그대로 쓴다
        XCTAssertEqual(MathGrades.forLevel(1).title, MathGrades.ALL.first!.title)
        XCTAssertEqual(MathGrades.forLevel(13).title, MathGrades.ALL.last!.title)
    }

    /// 영어 전용 앱 — 수학 배치고사 팩이 섞여 들어오면 안 된다
    func test_onlyEnglishPlacementPackShips() throws {
        let eng = try JSONObject(TestSupport.readText(TestSupport.pack("placement"))).getJSONArray("questions")
        XCTAssertTrue(eng.length() > 0)
        XCTAssertTrue(!TestSupport.isFile(TestSupport.pack("math_placement")), "수학 배치고사 팩은 삐약수학으로 갔다")
        // 영어 배치고사는 1~10 범위여야 한다
        for i in 0..<eng.length() {
            XCTAssertTrue((1...10).contains(eng.getJSONObject(i).getInt("level")))
        }
    }

    /// 시작 화면이 팩을 전부 파싱하지 않도록 색인이 있어야 한다
    func test_packIndexCoversEveryTrack() throws {
        let f = TestSupport.pack("index")
        XCTAssertTrue(TestSupport.isFile(f), "index.json 이 없으면 시작 화면이 팩 전체를 파싱한다")
        let idx = try JSONObject(TestSupport.readText(f))
        for tid in ContentRepo.TRACK_IDS {
            XCTAssertTrue(idx.has(tid), "색인에 트랙 없음: \(tid)")
            let e = idx.getJSONObject(tid)
            XCTAssertTrue(e.getInt("lessons") > 0, "\(tid): 레슨 수가 0")
            XCTAssertTrue(e.getInt("questions") > 0, "\(tid): 문제 수가 0")
        }
        // 색인의 합이 실제 규모와 맞는지 (영어만 약 1,490 레슨)
        let totalLessons = ContentRepo.TRACK_IDS.sumOf { idx.getJSONObject($0).getInt("lessons") }
        XCTAssertTrue(totalLessons > 1000, "전체 레슨 수가 이상함: \(totalLessons)")
    }
}
