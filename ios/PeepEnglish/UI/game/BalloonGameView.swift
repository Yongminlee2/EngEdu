import UIKit

/// 풍선 터뜨리기.
/// 풍선이 아래에서 위로 떠오르고, 정답 풍선을 터뜨리면 점수를 얻는다.
/// 정답 풍선이 화면 위로 도망가면 놓친 것.
final class BalloonGameView: GameView {

    private final class Balloon {
        var x: Float
        var y: Float
        var vy: Float
        var wobble: Float
        let text: String
        let color: Int
        let correct: Bool
        var popped: Bool
        init(x: Float, y: Float, vy: Float, wobble: Float, text: String, color: Int, correct: Bool, popped: Bool = false) {
            self.x = x; self.y = y; self.vy = vy; self.wobble = wobble
            self.text = text; self.color = color; self.correct = correct; self.popped = popped
        }
    }

    private final class Bit {
        var x: Float, y: Float, vx: Float, vy: Float
        let color: Int
        init(_ x: Float, _ y: Float, _ vx: Float, _ vy: Float, _ color: Int) {
            self.x = x; self.y = y; self.vx = vx; self.vy = vy; self.color = color
        }
    }

    private let rnd: KRandom = XorWowRandom(seed: System.currentTimeMillis())
    private var balloons: [Balloon] = []
    private var bits: [Bit] = []

    private let colors = [
        "#FF8A80", "#FFD54F", "#80CBC4", "#81D4FA", "#B39DDB", "#A5D6A7", "#FFAB91",
    ].map { Color.parseColor($0) }

    private let fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private let stringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        $0.style = .STROKE
        $0.color = Color.parseColor("#8D6E63")
    }
    private let textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        $0.textAlign = .CENTER
        $0.color = Color.WHITE
        $0.isFakeBoldText = true
    }

    /// 글자(이모지) → 일러스트. 있으면 풍선 안에 그림을 그린다
    var artResolver: ((String) -> Drawable?)?

    private var radius: Float = 0
    private var spawnTimer: Float = 0
    private var round: GameRound?
    private var queue: [(first: String, second: Bool)] = []  // (표시할 글자, 정답인가)

    /// 풍선이 떠오르는 속도 (난이도)
    var riseSpeed: Float = 1

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setRound(_ r: GameRound) {
        round = r
        balloons.removeAll()
        bits.removeAll()
        queue = r.options.map { (first: $0, second: $0 == r.answer) }.shuffled(random: rnd)
        // 정답이 목록에 없으면(생성 실수) 하나 넣어 준다
        if queue.none({ $0.second }) { queue.append((first: r.answer, second: true)) }
        spawnTimer = 0
        if let s = r.speak { onSpeak?(s) }
    }

    override func onSizeChanged(_ w: Int, _ h: Int, _ oldw: Int, _ oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        radius = Float(min(w, h)) * 0.085
        textPaint.textSize = radius * 0.78
        stringPaint.strokeWidth = dp(1.6)
    }

    override func update(_ dt: Float) {
        // 풍선 띄우기
        spawnTimer -= dt
        if spawnTimer <= 0 && queue.isNotEmpty() {
            spawnTimer = 0.55
            let next = queue.removeAt(0)
            balloons.append(
                Balloon(
                    x: radius * 1.3 + rnd.nextFloat() * (Float(width) - radius * 2.6),
                    y: Float(height) + radius,
                    vy: -(Float(height) * 0.085) * riseSpeed * (0.85 + rnd.nextFloat() * 0.3),
                    wobble: rnd.nextFloat() * 6.28,
                    text: next.first,
                    color: colors[rnd.nextInt(until: colors.count)],
                    correct: next.second
                )
            )
        }

        // 이동
        var missedCorrect = false
        var i = 0
        while i < balloons.count {
            let b = balloons[i]
            b.y += b.vy * dt
            b.wobble += dt * 2.2
            b.x += Float(sin(Double(b.wobble))) * dp(0.35)
            if b.y < -radius * 2.2 {
                if b.correct { missedCorrect = true }
                balloons.remove(at: i)
            } else {
                i += 1
            }
        }

        // 조각(터진 풍선)
        var j = 0
        while j < bits.count {
            let p = bits[j]
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.vy += dp(700) * dt
            if p.y > Float(height) + dp(20) { bits.remove(at: j) } else { j += 1 }
        }

        // 정답 풍선을 놓쳤으면 다음 문제로
        if missedCorrect {
            onMiss?()
            nextRound()
        } else if queue.isEmpty && balloons.none({ $0.correct }) {
            // 정답 풍선이 사라졌는데 놓침 처리도 안 됐으면 (터뜨림) 다음 문제
            if balloons.isEmpty { nextRound() }
        }
    }

    private func nextRound() {
        balloons.removeAll()
        onNextRound?()
    }

    override func render(_ canvas: Canvas) {
        for b in balloons {
            // 실
            let path = Path()
            path.moveTo(b.x, b.y + radius)
            path.quadTo(b.x + radius * 0.35, b.y + radius * 1.6, b.x, b.y + radius * 2.1)
            canvas.drawPath(path, stringPaint)
            // 몸통
            fill.color = b.color
            canvas.drawOval(
                b.x - radius * 0.86, b.y - radius,
                b.x + radius * 0.86, b.y + radius, fill
            )
            // 반짝임
            fill.color = Color.parseColor("#55FFFFFF")
            canvas.drawOval(
                b.x - radius * 0.45, b.y - radius * 0.62,
                b.x - radius * 0.1, b.y - radius * 0.15, fill
            )
            // 일러스트가 있으면 그림을, 없으면 글자를 (이모지면 크게)
            if let art = artResolver?(b.text) {
                let half = Float((radius * 0.62).toInt())
                art.setBounds(
                    (b.x - half).toInt(), (b.y - half).toInt(),
                    (b.x + half).toInt(), (b.y + half).toInt()
                )
                art.draw(canvas)
            } else {
                let isEmoji = isEmojiText(b.text)
                textPaint.textSize = isEmoji ? radius * 0.95 : radius * 0.78
                // 긴 글자가 풍선 밖으로 나가지 않게
                let maxW = radius * 1.62
                if !isEmoji && textPaint.measureText(b.text) > maxW {
                    textPaint.textSize *= maxW / textPaint.measureText(b.text)
                }
                textPaint.color = Color.WHITE
                canvas.drawText(b.text, b.x, b.y + textPaint.textSize * 0.35, textPaint)
            }
        }
        for p in bits {
            fill.color = p.color
            canvas.drawCircle(p.x, p.y, dp(4), fill)
        }
    }

    override func onTouchEvent(_ event: MotionEvent) -> Bool {
        if event.actionMasked != MotionEvent.ACTION_DOWN { return true }
        // 위에 그려진(뒤쪽) 풍선부터 검사
        for i in balloons.indices.reversed() {
            let b = balloons[i]
            if hypot(event.x - b.x, event.y - b.y) <= radius * 1.05 {
                pop(b)
                return true
            }
        }
        return true
    }

    private func pop(_ b: Balloon) {
        balloons.removeAll { $0 === b }
        for _ in 0..<14 {
            let a = rnd.nextFloat() * 6.28
            let sp = dp(120) + rnd.nextFloat() * dp(220)
            bits.append(
                Bit(
                    b.x, b.y,
                    Float(cos(Double(a))) * sp,
                    Float(sin(Double(a))) * sp,
                    b.color
                )
            )
        }
        if b.correct {
            onHit?()
            nextRound()
        } else {
            onMiss?()
        }
    }
}
