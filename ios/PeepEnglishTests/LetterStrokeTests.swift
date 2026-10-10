import XCTest
@testable import PeepEnglish

/// 알파벳 따라쓰기 획 데이터 검사.
/// 따라쓰기 판(TraceView)은 획을 일정 간격으로 리샘플링해 "체크포인트"를 만들고 첫 점에 시작 번호를 그린다.
/// **점이 없는 획이 하나라도 있으면 그 첫 점을 꺼내다 죽는다.** 그래서 52글자 전체를 뷰와 같은 계산으로 돌려 본다.
final class LetterStrokeTests: XCTestCase {

    /// TraceView.resample 과 같은 계산 (여기서 깨지면 화면에서도 깨진다)
    private func resample(_ pts: [Pt], _ spacing: Float) -> [Pt] {
        if pts.count < 2 { return pts }
        var out: [Pt] = []
        out.append(pts[0])
        var carry: Float = 0
        for i in 0..<(pts.count - 1) {
            let a = pts[i]
            let b = pts[i + 1]
            let seg = hypot(b.x - a.x, b.y - a.y)
            if seg <= 0.0001 { continue }
            var d = spacing - carry
            while d <= seg {
                let t = d / seg
                out.append(Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t))
                d += spacing
            }
            carry = seg - (d - spacing)
        }
        if out.last! != pts.last! { out.append(pts.last!) }
        return out
    }

    private func length(_ pts: [Pt]) -> Float {
        var sum: Float = 0
        for i in 0..<Swift.max(0, pts.count - 1) {
            sum += hypot(pts[i + 1].x - pts[i].x, pts[i + 1].y - pts[i].y)
        }
        return sum
    }

    func test_everyStrokeCanBeTraced() {
        // 뷰에서 쓰는 값과 같은 비율 (박스 크기의 3.5%)
        let spacing: Float = 0.035
        var checked = 0
        for d in Letters.ALL { for upper in [true, false] {
            let strokes = d.strokes(upper)
            let name = "\(d.glyph(upper))(\(upper ? "대" : "소"))"
            XCTAssertTrue(strokes.isNotEmpty(), "\(name): 획이 하나도 없다")
            for (i, s) in strokes.enumerated() {
                XCTAssertTrue(s.count >= 2, "\(name) \(i + 1)번 획: 점이 2개 미만이라 그릴 수 없다")
                XCTAssertTrue(
                    length(s) > 0.001,
                    "\(name) \(i + 1)번 획: 길이가 0이라 시작점만 있고 갈 곳이 없다"
                )
                let rs = resample(s, spacing)
                // 체크포인트가 비면 시작 번호를 그릴 때 첫 점을 꺼내다 죽는다
                XCTAssertTrue(rs.isNotEmpty(), "\(name) \(i + 1)번 획: 체크포인트가 비었다")
                XCTAssertTrue(rs.count >= 2, "\(name) \(i + 1)번 획: 체크포인트가 너무 적다")
                checked += 1
            }
        } }
        print("검사한 획: \(checked) (글자 \(Letters.ALL.count * 2)개)")
        XCTAssertTrue(checked >= Letters.ALL.count * 2, "검사된 획이 너무 적다")
    }

    /// 획이 글자 칸을 크게 벗어나면 화면 밖에 그려져 따라 그릴 수 없다.
    /// g·j·p·q·y 의 꼬리는 기준선 아래로 내려가는 게 정상이라 아래쪽만 넉넉히 본다.
    func test_everyStrokeStaysInsideTheBox() {
        for d in Letters.ALL { for upper in [true, false] {
            let name = "\(d.glyph(upper))(\(upper ? "대" : "소"))"
            for (i, s) in d.strokes(upper).enumerated() {
                for p in s {
                    XCTAssertTrue(
                        p.x >= -0.05 && p.x <= 1.05 && p.y >= -0.05 && p.y <= 1.10,
                        "\(name) \(i + 1)번 획: 점이 칸 밖에 있다 (\(p.x), \(p.y))"
                    )
                }
            }
        } }
    }

    /// 획이 판정 오차(박스의 13%)보다 짧으면 한 번만 스쳐도 완성된다 — 그런 획이 있으면 안 된다.
    func test_noStrokeIsShorterThanTheTouchTolerance() {
        let tol: Float = 0.13
        var tooShort: [String] = []
        for d in Letters.ALL { for upper in [true, false] {
            for (i, s) in d.strokes(upper).enumerated() {
                let len = length(s)
                if len < tol {
                    tooShort.append("\(d.glyph(upper))\(upper ? "대" : "소")-\(i + 1)획(\("%.3f".format(len)))")
                }
            }
        } }
        XCTAssertTrue(tooShort.isEmpty, "스쳐도 완성되는 짧은 획: \(tooShort)")
    }
}
