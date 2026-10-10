import UIKit

/// 일반 문제의 4지선다를 "둥둥 떠다니는 버블"로 보여 준다.
/// 시간 압박이 없다 — 사라지지 않고 제자리에서 천천히 흔들릴 뿐이다.
/// 짧은 보기일 때만 쓴다(fits 참고).
final class BubbleChoiceView: GameView {

    /// 버블에 들어갈 수 있는 최대 "폭 점수" (한글·이모지는 알파벳보다 두 배 넓다)
    static let MAX_WIDTH_SCORE = 12

    /// 한글·한자·가나·이모지는 2칸, 나머지는 1칸. 코드포인트 단위로 센다.
    static func widthScore(_ s: String) -> Int {
        var score = 0
        for u in s.unicodeScalars {
            let cp = Int(u.value)
            if (0x1100...0x11FF).contains(cp) ||    // 한글 자모
                (0x3040...0x30FF).contains(cp) ||   // 가나
                (0x3130...0x318F).contains(cp) ||   // 한글 호환 자모
                (0x4E00...0x9FFF).contains(cp) ||   // 한자
                (0xAC00...0xD7A3).contains(cp) ||   // 한글 음절
                cp >= 0x2000 {                      // 이모지·기호
                score += 2
            } else {
                score += 1
            }
        }
        return score
    }

    /// 보기 4개가 모두 버블에 들어갈 만큼 짧은가
    static func fits(_ choices: [String]) -> Bool {
        choices.count == 4 && choices.allSatisfy { widthScore($0) <= MAX_WIDTH_SCORE }
    }

    private final class Bubble {
        let text: String
        let index: Int
        var cx: Float = 0
        var cy: Float = 0
        var baseY: Float = 0
        var phase: Float = 0
        var pop: Float = 0      // 눌렀을 때 살짝 커졌다 돌아오는 연출
        var color: Int = 0
        init(_ text: String, _ index: Int, phase: Float = 0, color: Int = 0) {
            self.text = text; self.index = index; self.phase = phase; self.color = color
        }
    }

    private let rnd = XorWowRandom(seed: System.currentTimeMillis())
    private var bubbles: [Bubble] = []
    private var selected = -1
    private var radius: Float = 0

    /// 위아래로 둥둥 뜨는 폭 (반지름 대비) — placeBubbles 가 이 몫을 미리 빼둔다
    private let BOB_RATIO: Float = 0.10

    private let palette = ["#FF8A80", "#FFD54F", "#80CBC4", "#81D4FA", "#B39DDB", "#A5D6A7"].map { Color.parseColor($0) }

    private let fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private let ring: Paint = { let p = Paint(Paint.ANTI_ALIAS_FLAG); p.style = .STROKE; return p }()
    private let textPaint: Paint = {
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.textAlign = .CENTER
        p.isFakeBoldText = true
        return p
    }()

    /// 보기를 골랐을 때 (인덱스)
    var onPick: ((Int) -> Void)?

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setChoices(_ choices: [String]) {
        bubbles.removeAll()
        selected = -1
        let colors = palette.shuffled(random: rnd)
        for (i, c) in choices.enumerated() {
            bubbles.append(Bubble(c, i, phase: rnd.nextFloat() * 6.28, color: colors[i % colors.count]))
        }
        placeBubbles()
        startLoop()
        invalidate()
    }

    /// 정답·오답이 정해진 뒤 더 이상 움직이지 않게
    func lock() { stopLoop() }

    override func onSizeChanged(_ w: Int, _ h: Int, _ oldw: Int, _ oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        placeBubbles()
    }

    private func placeBubbles() {
        if width == 0 || height == 0 || bubbles.isEmpty { return }
        // 2 x 2 배치. 0.42 = 칸의 84%가 지름, 나머지가 서로의 여유 공간.
        // 둥둥 뜨고(BOB) 고르면 커지는(POP·선택) 몫을 미리 빼야 윗줄·아랫줄이 잘리지 않는다.
        let cols = 2
        let cellW = Float(width) / Float(cols)
        let rows = (bubbles.count + cols - 1) / cols
        let cellH = Float(height) / Float(rows)
        let raw = min(cellW, cellH) * 0.42
        // 커진 상태(1.06 × 1.10)에 흔들림(0.10)까지 더해도 칸 안에 들어오도록
        let grow: Float = 1.06 * 1.10
        radius = min(raw, (cellH / 2) / (grow + BOB_RATIO))
        for (i, b) in bubbles.enumerated() {
            let r = i / cols
            let c = i % cols
            b.cx = cellW * (Float(c) + 0.5)
            b.baseY = cellH * (Float(r) + 0.5)
            b.cy = b.baseY
        }
    }

    override func update(_ dt: Float) {
        for b in bubbles {
            b.phase += dt * 1.6
            // 위아래로 천천히 둥둥
            b.cy = b.baseY + Float(sin(Double(b.phase))) * radius * BOB_RATIO
            if b.pop > 0 { b.pop = (b.pop - dt * 3.2).coerceAtLeast(0) }
        }
    }

    override func render(_ canvas: Canvas) {
        for b in bubbles {
            let chosen = b.index == selected
            let r = radius * (1 + b.pop * 0.10) * (chosen ? 1.06 : 1)

            // 그림자
            fill.color = Color.parseColor("#14000000")
            canvas.drawCircle(b.cx, b.cy + r * 0.10, r, fill)

            fill.color = chosen ? b.color : Color.WHITE
            canvas.drawCircle(b.cx, b.cy, r, fill)

            ring.color = chosen ? Color.parseColor("#66BB6A") : b.color
            ring.strokeWidth = dp(chosen ? 5 : 3.5)
            canvas.drawCircle(b.cx, b.cy, r, ring)

            // 반짝임
            fill.color = Color.parseColor("#40FFFFFF")
            canvas.drawCircle(b.cx - r * 0.34, b.cy - r * 0.36, r * 0.20, fill)

            // 글자 (버블 안에 들어가도록 크기를 줄인다)
            let isEmoji = isEmojiText(b.text)
            var size = isEmoji ? r * 0.95 : r * 0.62
            textPaint.textSize = size
            var guardN = 0
            while textPaint.measureText(b.text) > r * 1.68 {
                let g = guardN; guardN += 1
                if g >= 20 { break }
                size *= 0.9
                textPaint.textSize = size
            }
            textPaint.color = chosen ? Color.WHITE : Color.parseColor("#4E342E")
            canvas.drawText(b.text, b.cx, b.cy + size * 0.35, textPaint)
        }
    }

    override func onTouchEvent(_ event: MotionEvent) -> Bool {
        if event.actionMasked != MotionEvent.ACTION_DOWN { return true }
        for b in bubbles {
            if hypotf(event.x - b.cx, event.y - b.cy) <= radius * 1.05 {
                selected = b.index
                b.pop = 1
                onPick?(b.index)
                invalidate()
                return true
            }
        }
        return true
    }

    /// 채점 후 정답·오답을 색으로 알려 준다
    func reveal(_ answerIndex: Int) {
        for b in bubbles {
            if b.index == answerIndex { b.color = Color.parseColor("#66BB6A") }
            else if b.index == selected { b.color = Color.parseColor("#EF5350") }
            else { b.color = Color.parseColor("#E0E0E0") }
        }
        invalidate()
    }
}
