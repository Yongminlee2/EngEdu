import UIKit

// 문제 풀이 화면(LessonActivity)을 옮기며 호환 층에 더한 것. 나중에 Droid/ 로 합친다.

// MARK: - TextView.scrollTo

extension TextView {
    /// 안드로이드 TextView.scrollTo — ScrollingMovementMethod 를 단 글자의 스크롤 위치 (x 는 쓰지 않는다)
    func scrollTo(_ x: Int, _ y: Int) {
        guard let box = subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else { return }
        let maxY = max(0, box.contentSize.height - box.bounds.height)
        box.setContentOffset(CGPoint(x: 0, y: min(max(0, CGFloat(y)), maxY)), animated: false)
    }
}
