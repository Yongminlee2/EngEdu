import UIKit

/// 문제 화면에 상주하는 병아리.
///
/// 정지 그림을 상태에 따라 바꿔 끼우고, 스케일·이동·하트는 이 뷰가 직접 그린다.
/// 상태: 대기(숨쉬기) / 환호(점프+하트) / 아쉬움(처짐) / 응원(말풍선) / 잠(쿨쿨, 톡 치면 기상)
final class ChickView: View {

    private enum Mood { case IDLE, CHEER, OOPS, ENCOURAGE, SLEEP }

    private var mood = Mood.IDLE
    private var moodT: Float = 0        // 현재 무드의 진행도 0~1
    private var breathe: Float = 0      // 숨쉬기 위상

    private final class Heart {
        var x: Float, y: Float, vy: Float, life: Float
        let size: Float
        init(x: Float, y: Float, vy: Float, life: Float, size: Float) {
            self.x = x; self.y = y; self.vy = vy; self.life = life; self.size = size
        }
    }
    private var hearts: [Heart] = []

    // 일러스트 스프라이트
    private var happy: Drawable?
    private var neutral: Drawable?
    private var sad: Drawable?
    private var cheerup: Drawable?
    private var sleepy: Drawable?

    // 두 번째 프레임 — 있으면 깜빡이고 날갯짓한다
    private var idleB: Drawable?
    private var happyB: Drawable?
    private var sleepyB: Drawable?

    /// 잠든 병아리를 톡 쳐서 깨웠을 때 알림 (레슨 화면이 삐약 소리를 낸다)
    var onWake: (() -> Void)?

    private lazy var bubblePaint: Paint = {
        let p = Paint(Paint.ANTI_ALIAS_FLAG); p.color = Color.WHITE; return p
    }()
    private lazy var bubbleStroke: Paint = {
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.style = .STROKE
        p.strokeWidth = dp(1.5)
        p.color = Color.parseColor("#FFB300")
        return p
    }()
    private lazy var textPaint: Paint = {
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.textAlign = .CENTER
        p.color = Color.parseColor("#4E342E")
        p.isFakeBoldText = true
        return p
    }()
    private lazy var heartPaint: Paint = {
        let p = Paint(Paint.ANTI_ALIAS_FLAG); p.textAlign = .CENTER; return p
    }()

    private var anim: ValueAnimator?
    private var encourageText = "힘내! 🐥"

    private func resIdOf(_ name: String) -> Int {
        context.resources.getIdentifier(name, "drawable", context.packageName)
    }

    private func frameOrNull(_ name: String) -> Drawable? {
        let id = resIdOf(name)
        return id == 0 ? nil : context.getDrawable(id)
    }

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
        happy = context.getDrawable(resIdOf("ck_cheer"))
        neutral = context.getDrawable(resIdOf("ck_idle"))
        sad = context.getDrawable(resIdOf("ck_sad"))
        cheerup = context.getDrawable(resIdOf("ck_cheerup"))
        sleepy = context.getDrawable(resIdOf("ck_sleep"))
        idleB = frameOrNull("ck_idle_b")
        happyB = frameOrNull("ck_cheer_b")
        sleepyB = frameOrNull("ck_sleep_b")

        startIdle()
        // 평소에는 터치를 통과시키고, 잠들었을 때만 "톡 쳐서 깨우기"를 받는다
        setOnClickListener { [weak self] _ in
            guard let self else { return }
            if self.mood == .SLEEP {
                self.isClickable = false
                self.onWake?()
                self.cheer()
            }
        }
        isClickable = false
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 아이폰: 누를 수 없을 때는 손가락을 아래 뷰로 통과시킨다(안드로이드와 같게)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isClickable else { return nil }
        return super.hitTest(point, with: event)
    }

    // ---------- 상태 전환 ----------

    /// 정답! 점프하며 하트를 뿌린다
    func cheer() {
        hearts.removeAll()
        for _ in 0..<3 {
            hearts.append(Heart(
                x: Float(width) * (0.25 + KRandom.default.nextFloat() * 0.5),
                y: Float(height) * 0.35,
                vy: -dp(0.9 + KRandom.default.nextFloat() * 0.6),
                life: 1,
                size: dp(10 + KRandom.default.nextFloat() * 5)
            ))
        }
        play(.CHEER, 1300)
    }

    /// 오답 — 잠깐 처졌다가 금방 돌아온다
    func oops() { play(.OOPS, 1000) }

    /// 오래 고민 중 — 응원 말풍선
    func encourage() {
        encourageText = ["힘내! 🐥", "천천히 해도 돼!", "삐약! 할 수 있어!"].random(random: KRandom.default)
        play(.ENCOURAGE, 2600)
    }

    /// 한참 조용하면 잠든다 — 톡 치면 일어난다
    func sleep() {
        if mood == .SLEEP { return }
        anim?.cancel()
        mood = .SLEEP
        isClickable = true
        let a = ValueAnimator.ofFloat(0, 1)
        a.duration = 3600
        a.repeatCount = ValueAnimator.INFINITE
        a.addUpdateListener { [weak self] in self?.breathe = $0.animatedFloat; self?.invalidate() }
        anim = a
        a.start()
    }

    private func play(_ m: Mood, _ duration: Int) {
        anim?.cancel()
        mood = m
        isClickable = false
        moodT = 0
        let a = ValueAnimator.ofFloat(0, 1)
        a.duration = duration
        if m == .CHEER { a.interpolator = OvershootInterpolator(1.4) }
        a.addUpdateListener { [weak self] in self?.moodT = $0.animatedFloat; self?.invalidate() }
        a.addListener(AnimatorListenerAdapter(onEnd: { [weak self] _ in self?.startIdle() }))
        anim = a
        a.start()
    }

    private func startIdle() {
        anim?.cancel()
        mood = .IDLE
        let a = ValueAnimator.ofFloat(0, 1)
        a.duration = 2400
        a.repeatCount = ValueAnimator.INFINITE
        a.addUpdateListener { [weak self] in self?.breathe = $0.animatedFloat; self?.invalidate() }
        anim = a
        a.start()
    }

    // ---------- 그리기 ----------

    override func onDraw(_ canvas: Canvas) {
        super.onDraw(canvas)
        let picked: Drawable?
        switch mood {
        // 환호는 날개를 퍼덕이고, 대기는 가끔 눈을 깜빡이고, 잠은 새근새근
        case .CHEER: picked = (happyB != nil && (moodT * 5).toInt() % 2 == 1) ? happyB : happy
        case .OOPS: picked = sad
        case .ENCOURAGE: picked = cheerup
        case .SLEEP: picked = ((sleepyB != nil && breathe > 0.5) ? sleepyB : sleepy) ?? neutral
        default: picked = (idleB != nil && breathe > 0.93) ? idleB : neutral
        }
        guard let d = picked else { return }

        // 병아리는 오른쪽에 붙이고, 말풍선이 왼쪽으로 뻗을 자리를 남긴다
        let base = Float(height)
        var size = base * 0.78
        let cx = Float(width) - base * 0.5
        var cy = Float(height) * 0.60

        switch mood {
        case .IDLE:
            // 천천히 숨쉬기
            size *= 1 + 0.035 * Float(sin(Double(breathe) * Double.pi * 2))
        case .CHEER:
            // 점프 (사인 반 주기) + 살짝 커짐
            cy -= base * 0.16 * Float(sin(Double(moodT) * Double.pi))
            size *= 1.08
        case .OOPS:
            // 처짐: 내려갔다가 스르륵 복귀
            let droop = Float(sin(Double(moodT) * Double.pi))
            cy += base * 0.08 * droop
            size *= 1 - 0.06 * droop
        case .ENCOURAGE:
            size *= 1 + 0.03 * Float(sin(Double(moodT) * Double.pi * 4))
        case .SLEEP:
            // 아주 느린 숨
            size *= 1 + 0.025 * Float(sin(Double(breathe) * Double.pi * 2))
        }

        let half = (size / 2).toInt()
        d.setBounds((cx - Float(half)).toInt(), (cy - Float(half)).toInt(), (cx + Float(half)).toInt(), (cy + Float(half)).toInt())
        d.draw(canvas)

        // 하트 (환호) — 병아리 주변에서 떠오른다
        if mood == .CHEER {
            var i = 0
            while i < hearts.count {
                let h = hearts[i]
                h.y += h.vy
                h.life = 1 - moodT
                if h.life <= 0 { hearts.remove(at: i); continue }
                heartPaint.textSize = h.size
                heartPaint.alpha = (255 * h.life).toInt()
                canvas.drawText("💛", cx - base * 0.5 + h.x * 0.3, h.y, heartPaint)
                i += 1
            }
            heartPaint.alpha = 255
        }

        // 쿨쿨 — 머리 위에서 숨결에 맞춰 깜빡인다
        if mood == .SLEEP {
            textPaint.textSize = dp(13)
            textPaint.alpha = (120 + 135 * sin(Double(breathe) * Double.pi * 2)).toInt().coerceIn(60, 255)
            canvas.drawText("💤", cx - size * 0.55, cy - size * 0.30, textPaint)
            textPaint.alpha = 255
        }

        // 응원 말풍선 — 병아리 왼쪽으로 뻗는다
        if mood == .ENCOURAGE {
            let fade: Float
            if moodT < 0.15 { fade = moodT / 0.15 }
            else if moodT > 0.85 { fade = (1 - moodT) / 0.15 }
            else { fade = 1 }
            textPaint.textSize = dp(11)
            let tw = textPaint.measureText(encourageText) + dp(14)
            let right = cx - size / 2 - dp(4)
            let left = (right - tw).coerceAtLeast(0)
            let byTop = cy - dp(11)
            let byBottom = cy + dp(9)
            bubblePaint.alpha = (255 * fade).toInt()
            bubbleStroke.alpha = (255 * fade).toInt()
            textPaint.alpha = (255 * fade).toInt()
            canvas.drawRoundRect(left, byTop, right, byBottom, dp(10), dp(10), bubblePaint)
            canvas.drawRoundRect(left, byTop, right, byBottom, dp(10), dp(10), bubbleStroke)
            canvas.drawText(encourageText, (left + right) / 2, byBottom - dp(6), textPaint)
            bubblePaint.alpha = 255; bubbleStroke.alpha = 255; textPaint.alpha = 255
        }
    }

    override func onDetachedFromWindow() {
        super.onDetachedFromWindow()
        anim?.cancel()
    }

    private func dp(_ v: Float) -> Float { v * context.resources.displayMetrics.density }
}
