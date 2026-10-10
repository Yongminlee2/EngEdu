import UIKit

/// 알파벳 따라쓰기 판.
/// 획(중심선)을 "길"처럼 그려 주고, 손가락·펜이 그 길의 체크포인트를 순서대로 지나가면 획이 완성된다.
/// 순서·방향을 익히도록 병아리가 길을 따라 걸어가는 시범 애니메이션을 제공한다.
final class TraceView: View {

    // ---- 입력 데이터 ----
    private var strokes: [[Pt]] = []
    private var glyph: String = ""

    /// 획 완성 콜백 (0부터)
    var onStrokeDone: ((Int) -> Void)?

    /// 글자 전체 완성 콜백
    var onAllDone: (() -> Void)?

    /// 길에서 벗어나 실패했을 때 (다시 그리기)
    var onStrokeFail: (() -> Void)?

    // ---- 진행 상태 ----
    private var strokeIdx = 0
    private var checkIdx = 0
    private var checkpoints: [[PointF]] = []
    private var userPaths: [Path] = []
    private var currentPath: Path?
    private var drawing = false

    var isFinished: Bool { strokes.isNotEmpty() && strokeIdx >= strokes.count }

    /// 지금까지 완성한 획 수
    var doneStrokes: Int { strokeIdx }

    /// 이 글자의 전체 획 수
    var totalStrokes: Int { strokes.count }

    // ---- 시범 애니메이션 ----
    private var demoAnim: ValueAnimator?
    private var demoPos: PointF?
    private var demoTrail: [PointF] = []

    // ---- 축하 애니메이션 ----
    private final class Confetti {
        var x: Float, y: Float, vx: Float, vy: Float
        let color: Int, size: Float
        var rot: Float
        let spin: Float
        init(x: Float, y: Float, vx: Float, vy: Float, color: Int, size: Float, rot: Float, spin: Float) {
            self.x = x; self.y = y; self.vx = vx; self.vy = vy
            self.color = color; self.size = size; self.rot = rot; self.spin = spin
        }
    }

    private var confetti: [Confetti] = []
    private var confettiAnim: ValueAnimator?

    // ---- 페인트 ----
    // 다음에 쓸 획들 — 아주 연하게
    private let roadPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        $0.style = .STROKE
        $0.strokeCap = .ROUND
        $0.strokeJoin = .ROUND
        $0.color = Color.parseColor("#F0E6D2")
    }
    // 지금 쓸 획 — 초록 길
    private let roadActivePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        $0.style = .STROKE
        $0.strokeCap = .ROUND
        $0.strokeJoin = .ROUND
        $0.color = Color.parseColor("#A5D6A7")
    }
    /// 지금 쓸 획의 테두리 — 어디까지 쓰는지 끝이 분명해진다
    private let roadActiveEdge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        $0.style = .STROKE
        $0.strokeCap = .ROUND
        $0.strokeJoin = .ROUND
        $0.color = Color.parseColor("#66BB6A")
    }
    private let dashPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        $0.style = .STROKE
        $0.strokeCap = .ROUND
        $0.color = Color.parseColor("#66FFB300")
    }
    private let donePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        $0.style = .STROKE
        $0.strokeCap = .ROUND
        $0.strokeJoin = .ROUND
        $0.color = Color.parseColor("#FFB300")
    }
    private let inkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        $0.style = .STROKE
        $0.strokeCap = .ROUND
        $0.strokeJoin = .ROUND
        $0.color = Color.parseColor("#FF7043")
    }
    private let startPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { $0.color = Color.parseColor("#66BB6A") }
    /// 획의 끝 — 어디까지 쓰면 되는지
    private let endPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { $0.color = Color.parseColor("#EF6C00") }
    private let startTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        $0.color = Color.WHITE
        $0.textAlign = .CENTER
        $0.typeface = Typeface.DEFAULT_BOLD
    }
    private let emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { $0.textAlign = .CENTER }
    private let confettiPaint = Paint(Paint.ANTI_ALIAS_FLAG)

    /// 한 번에 몇 칸까지 앞질러 인정할지 (좁으면 빠른 획을 놓치고, 넓으면 대충 가로질러도 통과)
    private static let LOOK_AHEAD = 10

    // ---- 좌표 변환 ----
    private var box: Float = 0
    private var offX: Float = 0
    private var offY: Float = 0

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func toPx(_ pt: Pt) -> PointF { PointF(offX + pt.x * box, offY + pt.y * box) }

    func setLetter(_ newStrokes: [[Pt]], _ glyphText: String) {
        strokes = newStrokes
        glyph = glyphText
        reset()
    }

    func reset() {
        cancelDemo()
        strokeIdx = 0
        checkIdx = 0
        userPaths.removeAll()
        currentPath = nil
        drawing = false
        confetti.removeAll()
        confettiAnim?.cancel()
        rebuild()
        invalidate()
    }

    /// 지금 획만 다시
    private func resetCurrentStroke() {
        checkIdx = 0
        currentPath = nil
        invalidate()
    }

    override func onSizeChanged(_ w: Int, _ h: Int, _ oldw: Int, _ oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        rebuild()
    }

    private func rebuild() {
        if width == 0 || height == 0 { return }
        let pad: Float = 0.10
        box = Float(min(width, height)) * (1 - pad * 2)
        offX = (Float(width) - box) / 2
        offY = (Float(height) - box) / 2

        roadPaint.strokeWidth = box * 0.17
        roadActivePaint.strokeWidth = box * 0.17
        donePaint.strokeWidth = box * 0.11
        inkPaint.strokeWidth = box * 0.10
        dashPaint.strokeWidth = box * 0.012
        dashPaint.pathEffect = DashPathEffect([box * 0.035, box * 0.045], 0)
        startTextPaint.textSize = box * 0.075
        emojiPaint.textSize = box * 0.16

        // 체크포인트: 획을 일정 간격으로 리샘플링
        let spacing = box * 0.035
        checkpoints = strokes.map { resample($0.map { pt in toPx(pt) }, spacing) }

        // 이미 쓴 획은 새 좌표로 다시 만든다 (크기가 바뀌면 옛 자리에 그려지지 않게)
        userPaths.removeAll()
        for i in 0..<min(strokeIdx, checkpoints.count) {
            userPaths.append(pathOf(checkpoints[i]))
        }
    }

    private func resample(_ pts: [PointF], _ spacing: Float) -> [PointF] {
        if pts.count < 2 { return pts }
        var out: [PointF] = []
        out.append(pts[0])
        var carry: Float = 0
        for i in 0..<(pts.count - 1) {
            let a = pts[i]
            let bb = pts[i + 1]
            let seg = hypot(bb.x - a.x, bb.y - a.y)
            if seg <= 0.0001 { continue }
            var d = spacing - carry
            while d <= seg {
                let t = d / seg
                out.append(PointF(a.x + (bb.x - a.x) * t, a.y + (bb.y - a.y) * t))
                d += spacing
            }
            carry = seg - (d - spacing)
        }
        // 코틀린 PointF 는 값으로 비교한다
        let l = out[out.count - 1], e = pts[pts.count - 1]
        if l.x != e.x || l.y != e.y { out.append(e) }
        return out
    }

    private func pathOf(_ pts: [PointF]) -> Path {
        let path = Path()
        if pts.isEmpty { return path }
        path.moveTo(pts[0].x, pts[0].y)
        for i in 1..<pts.count { path.lineTo(pts[i].x, pts[i].y) }
        return path
    }

    /// 시범 병아리 일러스트 (이모지 대신)
    private var demoChick: Drawable?

    // ---- 시범 애니메이션 (병아리가 길을 걸어감) ----
    func playDemo() {
        if isFinished || checkpoints.isEmpty { return }
        cancelDemo()
        guard let pts = checkpoints.getOrNull(strokeIdx) else { return }
        demoTrail = []
        demoAnim = ValueAnimator.ofFloat(0, 1).apply { a in
            a.duration = (900 + pts.count * 18).coerceAtMost(2600)
            a.addUpdateListener { [weak self] va in
                guard let self else { return }
                let t = va.animatedValue as! Float
                let idx = (Float(pts.count - 1) * t).toInt().coerceIn(0, pts.count - 1)
                self.demoPos = pts[idx]
                self.demoTrail = Array(pts[0...idx])
                self.invalidate()
            }
            a.addListener(AnimatorListenerAdapter(onEnd: { [weak self] _ in
                guard let self else { return }
                self.demoPos = nil
                self.demoTrail.removeAll()
                self.invalidate()
            }))
            a.start()
        }
    }

    private func cancelDemo() {
        demoAnim?.cancel()
        demoAnim = nil
        demoPos = nil
        demoTrail.removeAll()
    }

    // ---- 축하 ----
    private func celebrate() {
        let colors = ["#FFD54F", "#FF8A80", "#80CBC4", "#81D4FA", "#B39DDB", "#66BB6A"]
        let rnd = KRandom.default
        confetti.removeAll()
        for _ in 0..<28 {
            confetti.append(
                Confetti(
                    x: Float(width) / 2 + rnd.nextFloat() * box * 0.4 - box * 0.2,
                    y: Float(height) / 2,
                    vx: (rnd.nextFloat() - 0.5) * box * 0.06,
                    vy: -rnd.nextFloat() * box * 0.05 - box * 0.01,
                    color: Color.parseColor(colors[rnd.nextInt(until: colors.count)]),
                    size: box * (0.018 + rnd.nextFloat() * 0.022),
                    rot: rnd.nextFloat() * 360,
                    spin: (rnd.nextFloat() - 0.5) * 24
                )
            )
        }
        confettiAnim?.cancel()
        confettiAnim = ValueAnimator.ofFloat(0, 1).apply { a in
            a.duration = 1400
            a.addUpdateListener { [weak self] _ in
                guard let self else { return }
                for c in self.confetti {
                    c.x += c.vx
                    c.y += c.vy
                    c.vy += self.box * 0.0022
                    c.rot += c.spin
                }
                self.invalidate()
            }
            a.addListener(AnimatorListenerAdapter(onEnd: { [weak self] _ in
                guard let self else { return }
                self.confetti.removeAll(); self.invalidate()
            }))
            a.start()
        }
    }

    // ---- 터치 ----
    /// 직전 손가락 위치 (선을 부드럽게 잇고, 빠른 획도 놓치지 않으려고 쓴다)
    private var lastX: Float = 0
    private var lastY: Float = 0

    /// 이 획의 판정 반경 — 아주 작은 획(i·j 의 점)은 스치기만 해도 완성되지 않게 획 크기에 맞춰 좁힌다.
    private func toleranceFor(_ pts: [PointF]) -> Float {
        if pts.isEmpty { return box * 0.13 }
        var minX = pts[0].x, maxX = pts[0].x
        var minY = pts[0].y, maxY = pts[0].y
        for p in pts {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        let extent = max(maxX - minX, maxY - minY)
        return (extent * 0.55).coerceIn(box * 0.05, box * 0.15)
    }

    override func onTouchEvent(_ event: MotionEvent) -> Bool {
        if isFinished || checkpoints.isEmpty { return false }
        // 시범 중에 손을 대면 시범을 멈추고 바로 쓰기 시작
        if demoAnim?.isRunning == true { cancelDemo() }

        guard let pts = checkpoints.getOrNull(strokeIdx) else { return false }
        if pts.isEmpty { return false }
        let tol = toleranceFor(pts)

        switch event.actionMasked {
        case MotionEvent.ACTION_DOWN:
            drawing = true
            lastX = event.x; lastY = event.y
            currentPath = Path().apply { $0.moveTo(event.x, event.y) }
            advance(pts, event.x, event.y, tol)
            parent?.requestDisallowInterceptTouchEvent(true)
            invalidate()
            return true
        case MotionEvent.ACTION_MOVE:
            if !drawing { return false }
            // 아이폰 MotionEvent 에는 중간 지점(history)이 없다 — extendTo 가 사이를 잘게 쪼개 확인한다
            for h in 0..<event.historySize {
                extendTo(pts, event.getHistoricalX(h), event.getHistoricalY(h), tol)
            }
            extendTo(pts, event.x, event.y, tol)
            if checkIdx >= pts.count { finishStroke() }
            invalidate()
            return true
        case MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL:
            drawing = false
            currentPath?.lineTo(lastX, lastY)
            if Float(checkIdx) >= Float(pts.count) * 0.90 {
                finishStroke()
            } else if Float(checkIdx) >= Float(pts.count) * 0.25 {
                // 거의 다 왔으면 지나온 자리를 살려 둔다 (처음부터 다시 시키면 금방 포기한다)
                onStrokeFail?()
                currentPath = nil
            } else {
                if checkIdx > 0 { onStrokeFail?() }
                resetCurrentStroke()
            }
            invalidate()
            return true
        default:
            break
        }
        return false
    }

    /// 손가락이 (lastX, lastY) 에서 (x, y) 로 움직인 만큼 선을 잇고 길 진행도 확인한다.
    /// 사이를 잘게 쪼개 확인해 빠르게 그어도 체크포인트를 건너뛰지 않는다.
    private func extendTo(_ pts: [PointF], _ x: Float, _ y: Float, _ tol: Float) {
        let dx = x - lastX
        let dy = y - lastY
        let dist = hypot(dx, dy)
        let steps = (dist / (box * 0.02)).toInt().coerceIn(1, 24)
        for s in 1...steps {
            let t = Float(s) / Float(steps)
            advance(pts, lastX + dx * t, lastY + dy * t, tol)
        }
        // 두 점의 중간을 지나는 곡선 — 꺾인 자국 없이 부드럽게
        currentPath?.quadTo(lastX, lastY, (lastX + x) / 2, (lastY + y) / 2)
        lastX = x
        lastY = y
    }

    private func advance(_ pts: [PointF], _ x: Float, _ y: Float, _ tol: Float) {
        if checkIdx >= pts.count { return }
        // 앞쪽을 훑어 가장 멀리 닿은 지점으로 전진 (되돌아가진 않는다 = 획 방향을 지킨다)
        var best = -1
        let look = min(pts.count - 1, checkIdx + TraceView.LOOK_AHEAD)
        if checkIdx <= look {
            for i in checkIdx...look {
                if hypot(pts[i].x - x, pts[i].y - y) < tol { best = i }
            }
        }
        if best >= 0 { checkIdx = best + 1 }
    }

    private func finishStroke() {
        guard let pts = checkpoints.getOrNull(strokeIdx) else { return }
        // 다 쓴 획은 삐뚤한 선 대신 반듯한 획으로 바꿔 준다
        userPaths.append(pathOf(pts))
        currentPath = nil
        let done = strokeIdx
        strokeIdx += 1
        checkIdx = 0
        drawing = false
        onStrokeDone?(done)
        // 마지막 획이면 축하 (strokes·checkpoints 둘 다 보고 판단)
        if strokeIdx >= strokes.count || strokeIdx >= checkpoints.count {
            strokeIdx = max(strokes.count, checkpoints.count)
            celebrate()
            onAllDone?()
        }
    }

    // ---- 그리기 ----
    override func onDraw(_ canvas: Canvas) {
        super.onDraw(canvas)
        if checkpoints.isEmpty { return }

        // 배경 글자(폰트)는 그리지 않는다 — 글자 모양은 "길" 하나로만 보여 준다.

        // 아직 안 쓴 획들 = 길. 다음 획들을 먼저, 지금 쓸 획을 맨 위에
        for i in checkpoints.indices {
            if i <= strokeIdx { continue }
            canvas.drawPath(pathOf(checkpoints[i]), roadPaint)
        }
        if strokeIdx < checkpoints.count {
            let path = pathOf(checkpoints[strokeIdx])
            roadActiveEdge.strokeWidth = roadActivePaint.strokeWidth * 1.22
            canvas.drawPath(path, roadActiveEdge)
            canvas.drawPath(path, roadActivePaint)
            canvas.drawPath(path, dashPaint)
            // 끝 지점에 깃발처럼 동그라미 — 여기까지 쓰면 된다
            if let e = checkpoints[strokeIdx].last {
                canvas.drawCircle(e.x, e.y, roadActivePaint.strokeWidth * 0.34, endPaint)
            }
        }

        // 완성한 획
        for path in userPaths { canvas.drawPath(path, donePaint) }

        // 시범 궤적 + 병아리
        if demoTrail.count > 1 {
            canvas.drawPath(pathOf(demoTrail), inkPaint)
        }
        if let it = demoPos {
            var d = demoChick
            if d == nil {
                let id = context.resources.getIdentifier("ck_idle", "drawable", context.packageName)
                d = id == 0 ? nil : context.getDrawable(id)
                demoChick = d
            }
            if let d {
                let half = (emojiPaint.textSize * 0.62).toInt()
                d.setBounds(
                    (it.x - Float(half)).toInt(), (it.y - Float(half)).toInt(),
                    (it.x + Float(half)).toInt(), (it.y + Float(half)).toInt()
                )
                d.draw(canvas)
            } else {
                canvas.drawText("🐥", it.x, it.y + emojiPaint.textSize * 0.35, emojiPaint)
            }
        }

        // 지금 쓰고 있는 선
        if let p = currentPath { canvas.drawPath(p, inkPaint) }

        // 시작점 표시 (번호)
        let startPts = isFinished ? nil : checkpoints.getOrNull(strokeIdx)
        if let pts = startPts, pts.isNotEmpty() {
            let s = pts[0]
            canvas.drawCircle(s.x, s.y, box * 0.055, startPaint)
            canvas.drawText(
                "\(strokeIdx + 1)", s.x,
                s.y + startTextPaint.textSize * 0.36, startTextPaint
            )
        }

        // 축하 조각
        for c in confetti {
            confettiPaint.color = c.color
            canvas.save()
            canvas.rotate(c.rot, c.x, c.y)
            canvas.drawRoundRect(
                c.x - c.size, c.y - c.size * 0.6, c.x + c.size, c.y + c.size * 0.6,
                c.size * 0.3, c.size * 0.3, confettiPaint
            )
            canvas.restore()
        }
    }

    override func onDetachedFromWindow() {
        super.onDetachedFromWindow()
        cancelDemo()
        confettiAnim?.cancel()
    }
}
