import UIKit

/// 단어 타일용 간단한 플로우 레이아웃 (왼→오, 넘치면 다음 줄)
final class FlowLayout: ViewGroup {

    var hGap = FlowLayout.dp(8)
    var vGap = FlowLayout.dp(8)

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
        // 자식 그림자가 부모 경계에서 잘리지 않게
        clipChildren = false
        clipToPadding = false
    }
    required init?(coder: NSCoder) { fatalError() }

    private static func dp(_ v: Int) -> Int { Int(Float(v) * Resources.shared.displayMetrics.density) }

    /// 크기를 지정한 자식(레슨 노드 72×72)은 그대로, wrap_content 인 것만 내용에 맞춰 잰다
    private func measureChildForFlow(_ c: View, _ maxW: Int) {
        let lp = c.layoutParams
        let wSpec = (lp != nil && lp!.width > 0)
            ? MeasureSpec.makeMeasureSpec(lp!.width, MeasureSpec.EXACTLY)
            : MeasureSpec.makeMeasureSpec(maxW, MeasureSpec.AT_MOST)
        let hSpec = (lp != nil && lp!.height > 0)
            ? MeasureSpec.makeMeasureSpec(lp!.height, MeasureSpec.EXACTLY)
            : MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        c.measure(wSpec, hSpec)
    }

    override func onMeasure(_ widthMeasureSpec: Int, _ heightMeasureSpec: Int) {
        let maxW = MeasureSpec.getSize(widthMeasureSpec) - paddingLeft - paddingRight
        var x = 0
        var y = 0
        var rowH = 0
        for i in 0..<childCount {
            let c = children[i]
            if c.visibility == View.GONE { continue }
            measureChildForFlow(c, maxW)
            if x + c.measuredWidth > maxW && x > 0 {
                x = 0; y += rowH + vGap; rowH = 0
            }
            x += c.measuredWidth + hGap
            rowH = max(rowH, c.measuredHeight)
        }
        let h = y + rowH + paddingTop + paddingBottom
        setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), View.resolveSize(h, heightMeasureSpec))
    }

    override func onLayout(_ changed: Bool, _ l: Int, _ t: Int, _ r: Int, _ b: Int) {
        let maxW = r - l - paddingLeft - paddingRight
        var x = 0
        var y = paddingTop
        var rowH = 0
        for i in 0..<childCount {
            let c = children[i]
            if c.visibility == View.GONE { continue }
            if x + c.measuredWidth > maxW && x > 0 {
                x = 0; y += rowH + vGap; rowH = 0
            }
            c.layout(paddingLeft + x, y, paddingLeft + x + c.measuredWidth, y + c.measuredHeight)
            x += c.measuredWidth + hGap
            rowH = max(rowH, c.measuredHeight)
        }
    }
}
