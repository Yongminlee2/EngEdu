import XCTest
@testable import PeepEnglish

final class LettersTests: XCTestCase {

    func test_hasAllTwentySixLetters() {
        XCTAssertEqual(Letters.ALL.count, 26)
        let uppers = Letters.ALL.map { $0.upper }
        XCTAssertEqual(uppers, (65...90).map { Character(Unicode.Scalar($0)!) })   // 'A'..'Z'
        let lowers = Letters.ALL.map { $0.lower }
        XCTAssertEqual(lowers, (97...122).map { Character(Unicode.Scalar($0)!) })  // 'a'..'z'
    }

    func test_everyLetterHasWordAndEmoji() {
        for d in Letters.ALL {
            XCTAssertTrue(d.word.isNotBlank(), "\(d.upper): 단어 없음")
            XCTAssertTrue(d.ko.isNotBlank(), "\(d.upper): 뜻 없음")
            XCTAssertTrue(d.emoji.isNotBlank(), "\(d.upper): 이모지 없음")
            // 예시 단어는 그 글자로 시작해야 아이가 소리를 연결할 수 있다
            XCTAssertEqual(
                Character(d.word.first!.uppercased()), d.upper,
                "\(d.upper): 단어가 글자로 시작하지 않음 (\(d.word))"
            )
        }
    }

    /// 획 데이터가 실제로 그릴 수 있는 형태인지 (점 수·범위·길이)
    private func checkStrokes(_ name: String, _ strokes: [[Pt]]) {
        XCTAssertTrue(strokes.isNotEmpty(), "\(name): 획이 없음")
        XCTAssertTrue(strokes.count <= 4, "\(name): 획이 너무 많음(\(strokes.count))")
        for (i, s) in strokes.enumerated() {
            XCTAssertTrue(s.count >= 2, "\(name) 획\(i + 1): 점이 2개 미만")
            var len: Float = 0
            for j in 0..<Swift.max(0, s.count - 1) {
                len += hypot(s[j + 1].x - s[j].x, s[j + 1].y - s[j].y)
            }
            // 너무 짧은 획은 아이가 따라 그리기 어렵다 (i 의 점은 예외적으로 작은 원)
            XCTAssertTrue(len > 0.08, "\(name) 획\(i + 1): 길이가 너무 짧음(\(len))")
            for p in s {
                XCTAssertTrue((-0.02...1.02).contains(p.x), "\(name) 획\(i + 1): x 범위 벗어남(\(p.x))")
                XCTAssertTrue((-0.02...1.10).contains(p.y), "\(name) 획\(i + 1): y 범위 벗어남(\(p.y))")
            }
        }
    }

    func test_uppercaseStrokesAreDrawable() {
        for d in Letters.ALL { checkStrokes("\(d.upper)(대)", d.upperStrokes) }
    }

    func test_lowercaseStrokesAreDrawable() {
        for d in Letters.ALL { checkStrokes("\(d.lower)(소)", d.lowerStrokes) }
    }

    func test_progressKeysAreUnique() {
        var keys = Set<String>()
        for d in Letters.ALL {
            XCTAssertTrue(keys.insert(Letters.key(d, true)).inserted, "키 중복")
            XCTAssertTrue(keys.insert(Letters.key(d, false)).inserted, "키 중복")
        }
        XCTAssertEqual(keys.count, 52)
        XCTAssertEqual(Letters.key(Letters.ALL.first!, true), "A_U")
        XCTAssertEqual(Letters.key(Letters.ALL.first!, false), "a_L")
    }

    func test_letterGlyphSwitchesByCase() {
        let a = Letters.ALL.first!
        XCTAssertEqual(a.glyph(true), "A")
        XCTAssertEqual(a.glyph(false), "a")
        XCTAssertEqual(a.strokes(true), a.upperStrokes)
        XCTAssertEqual(a.strokes(false), a.lowerStrokes)
    }
}
