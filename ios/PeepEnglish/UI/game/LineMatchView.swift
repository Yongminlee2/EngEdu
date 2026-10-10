import UIKit

/// 선으로 잇기.
/// 한쪽 항목에서 손가락을 눌러 반대쪽 항목까지 끌면 선이 그어진다.
/// 짝이 맞으면 선이 남고, 틀리면 선이 사라진다. 네 쌍을 다 이으면 끝.
final class LineMatchView: GameView {

    private final class Node {
        let text: String
        let key: Int
        var box: RectF
        init(_ text: String, _ key: Int, _ box: RectF = RectF()) { self.text = text; self.key = key; self.box = box }
    }

    private let rnd = XorWowRandom(seed: System.currentTimeMillis())
    // 코틀린 left/right — 아이폰은 View.left/right 와 겹쳐 이름을 바꿨다
    private var leftNodes: [Node] = []
    private var rightNodes: [Node] = []
    /// key → key (이어진 짝). 코틀린 LinkedHashMap 처럼 넣은 순서를 지킨다
    private var matched: [(Int, Int)] = []

    private var dragFrom: Node?
    private var dragX: Float = 0
    private var dragY: Float = 0
    private var shakeKey = -1
    private var shakeTime: Float = 0

    private let colors = ["#FF8A80", "#FFD54F", "#80CBC4", "#81D4FA", "#B39DDB", "#A5D6A7"].map { Color.parseColor($0) }

    private let boxPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private let strokePaint: Paint = {
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.style = .STROKE
        p.color = Color.parseColor("#FFE082")
        return p
    }()
    private let linePaint: Paint = {
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.style = .STROKE
        p.strokeCap = .ROUND
        return p
    }()
    private let textPaint: Paint = {
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.textAlign = .CENTER
        p.color = Color.parseColor("#4E342E")
        p.isFakeBoldText = true
        return p
    }()

    var isCleared: Bool { !leftNodes.isEmpty && matched.count == leftNodes.count }

    /// 항목 글자(이모지) → 일러스트. 있으면 카드에 그림을 그린다
    var artResolver: ((String) -> Drawable?)?

    /// 다 이었을 때 넘어가기를 한 번만 예약하려고 둔 표시
    private var finishPosted = false

    /// 오른쪽 칸에서 선을 시작했는가 (놓을 때 반대쪽에서 짝을 찾는다)
    private var dragStartedRight = false

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func matchedHasKey(_ k: Int) -> Bool { matched.contains { $0.0 == k } }
    private func matchedHasValue(_ v: Int) -> Bool { matched.contains { $0.1 == v } }
    private func putMatched(_ k: Int, _ v: Int) {
        if let i = matched.firstIndex(where: { $0.0 == k }) { matched[i].1 = v } else { matched.append((k, v)) }
    }

    /// (왼쪽, 오른쪽) 짝 목록을 넣는다
    func setPairs(_ pairs: [Pair<String, String>]) {
        leftNodes.removeAll(); rightNodes.removeAll(); matched.removeAll()
        finishPosted = false
        for (i, p) in pairs.enumerated() { leftNodes.append(Node(p.first, i)) }
        pairs.enumerated().map { Node($0.element.second, $0.offset) }.shuffled(random: rnd).forEach { rightNodes.append($0) }
        layoutNodes()
        invalidate()
    }

    override func onSizeChanged(_ w: Int, _ h: Int, _ oldw: Int, _ oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        strokePaint.strokeWidth = dp(2.5)
        linePaint.strokeWidth = dp(6)
        layoutNodes()
    }

    private func layoutNodes() {
        if width == 0 || height == 0 || leftNodes.isEmpty { return }
        let n = leftNodes.count
        let boxW = Float(width) * 0.36
        let boxH = (Float(height) * 0.82) / Float(n) - dp(10)
        let topPad = Float(height) * 0.09
        textPaint.textSize = (boxH * 0.42).coerceAtMost(dp(24))
        for i in 0..<n {
            let top = topPad + (boxH + dp(10)) * Float(i)
            leftNodes[i].box = RectF(dp(10), top, dp(10) + boxW, top + boxH)
            rightNodes[i].box = RectF(Float(width) - dp(10) - boxW, top, Float(width) - dp(10), top + boxH)
        }
    }

    override func update(_ dt: Float) {
        if shakeTime > 0 {
            shakeTime -= dt
            if shakeTime <= 0 { shakeKey = -1 }
        }
    }

    override func render(_ canvas: Canvas) {
        // 이어진 선
        for (lk, rk) in matched {
            guard let l = leftNodes.first(where: { $0.key == lk }) else { continue }
            guard let r = rightNodes.first(where: { $0.key == rk }) else { continue }
            linePaint.color = colors[lk % colors.count]
            canvas.drawLine(l.box.right, l.box.centerY(), r.box.left, r.box.centerY(), linePaint)
        }
        // 끌고 있는 선
        if let it = dragFrom {
            linePaint.color = Color.parseColor("#8D6E63")
            let sx = dragStartedRight ? it.box.left : it.box.right
            canvas.drawLine(sx, it.box.centerY(), dragX, dragY, linePaint)
        }

        drawColumn(canvas, leftNodes, true)
        drawColumn(canvas, rightNodes, false)
    }

    private func drawColumn(_ canvas: Canvas, _ nodes: [Node], _ isLeft: Bool) {
        for node in nodes {
            let done = isLeft ? matchedHasKey(node.key) : matchedHasValue(node.key)
            let shaking = shakeKey == node.key && shakeTime > 0
            let dx: Float = shaking ? Float(sin(Double(shakeTime) * 60.0)) * dp(5) : 0
            let box = RectF(node.box)
            box.offset(dx, 0)

            boxPaint.color = done ? colors[node.key % colors.count] : Color.WHITE
            canvas.drawRoundRect(box, dp(16), dp(16), boxPaint)
            strokePaint.color = done ? Color.parseColor("#66BB6A") : Color.parseColor("#FFE082")
            canvas.drawRoundRect(box, dp(16), dp(16), strokePaint)

            if let art = artResolver?(node.text) {
                let half = (box.height() * 0.42).toInt()
                art.setBounds(
                    (box.centerX() - Float(half)).toInt(), (box.centerY() - Float(half)).toInt(),
                    (box.centerX() + Float(half)).toInt(), (box.centerY() + Float(half)).toInt()
                )
                art.draw(canvas)
            } else {
                let isEmoji = isEmojiText(node.text)
                textPaint.textSize = isEmoji ? box.height() * 0.55 : (box.height() * 0.36).coerceAtMost(dp(22))
                // 긴 한글·영어가 칸 밖으로 나가지 않게 폭에 맞춰 줄인다
                let maxW = box.width() - dp(18)
                if !isEmoji && textPaint.measureText(node.text) > maxW {
                    textPaint.textSize *= maxW / textPaint.measureText(node.text)
                }
                textPaint.color = done ? Color.WHITE : Color.parseColor("#4E342E")
                canvas.drawText(node.text, box.centerX(), box.centerY() + textPaint.textSize * 0.35, textPaint)
            }

            // 연결점
            boxPaint.color = done ? Color.parseColor("#66BB6A") : Color.parseColor("#FFB300")
            let cx = isLeft ? box.right : box.left
            canvas.drawCircle(cx, box.centerY(), dp(7), boxPaint)
        }
    }

    override func onTouchEvent(_ event: MotionEvent) -> Bool {
        switch event.actionMasked {
        case MotionEvent.ACTION_DOWN:
            // 아직 안 이어진 항목에서 시작 — 왼쪽·오른쪽 어느 쪽에서 그어도 된다.
            // 칸 둘레로 여유를 두고, 그래도 없으면 가장 가까운 칸을 잡아 준다.
            let freeLeft = leftNodes.filter { !matchedHasKey($0.key) }
            let freeRight = rightNodes.filter { !matchedHasValue($0.key) }
            func pick(_ list: [Node]) -> Node? {
                if let n = list.first(where: { grown($0.box).contains(event.x, event.y) }) { return n }
                if let m = list.minByOrNull({ hypotf(event.x - $0.box.centerX(), event.y - $0.box.centerY()) }),
                   hypotf(event.x - m.box.centerX(), event.y - m.box.centerY()) < m.box.height() * 1.2 {
                    return m
                }
                return nil
            }
            // 누른 지점이 어느 쪽에 가까운지 보고 그쪽에서 먼저 찾는다
            let fromRight = event.x > Float(width) / 2
            dragFrom = fromRight ? (pick(freeRight) ?? pick(freeLeft)) : (pick(freeLeft) ?? pick(freeRight))
            if let f = dragFrom { dragStartedRight = rightNodes.contains { $0 === f } } else { dragStartedRight = false }
            dragX = event.x; dragY = event.y
            parent?.requestDisallowInterceptTouchEvent(true)
            invalidate()
            return true
        case MotionEvent.ACTION_MOVE:
            if dragFrom != nil {
                dragX = event.x; dragY = event.y
                invalidate()
            }
            return true
        case MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL:
            let from = dragFrom
            dragFrom = nil
            if let from {
                // 시작한 반대쪽에서 짝을 찾는다 (오른쪽에서 시작했으면 왼쪽에서)
                let targets = dragStartedRight
                    ? leftNodes.filter { !matchedHasKey($0.key) }
                    : rightNodes.filter { !matchedHasValue($0.key) }
                var hit = targets.first { grown($0.box).contains(event.x, event.y) }
                if hit == nil, let m = targets.minByOrNull({ hypotf(event.x - $0.box.centerX(), event.y - $0.box.centerY()) }),
                   hypotf(event.x - m.box.centerX(), event.y - m.box.centerY()) < m.box.height() * 1.1 {
                    hit = m
                }
                if let hit {
                    if hit.key == from.key {
                        putMatched(from.key, hit.key)
                        onHit?()
                        if isCleared && !finishPosted {
                            finishPosted = true
                            // 다 이어진 모습을 잠깐 보여 준 뒤 넘어간다
                            postDelayed({ [weak self] in self?.onFinish?() }, 900)
                        }
                    } else {
                        shakeKey = hit.key
                        shakeTime = 0.35
                        onMiss?()
                    }
                }
            }
            invalidate()
            return true
        default:
            return true
        }
    }

    /// 손가락 오차를 감안해 칸을 조금 넓힌 판정 영역
    private func grown(_ b: RectF) -> RectF {
        let pad = dp(12)
        return RectF(b.left - pad, b.top - pad * 0.6, b.right + pad, b.bottom + pad * 0.6)
    }

    /// 가장 가까운 오른쪽 항목까지의 거리 (시험·디버깅용)
    func nearestRightDistance(_ x: Float, _ y: Float) -> Float {
        rightNodes.map { hypotf(x - $0.box.centerX(), y - $0.box.centerY()) }.min() ?? Float.greatestFiniteMagnitude
    }
}
