import UIKit

/// 정답 축하 오버레이 — 색종이 + 콤보 배지.
/// 전체 화면 위에 떠 있지만 터치는 전부 아래로 통과한다.
/// 색종이는 위로 쏘아 올리고 중력으로 떨어뜨리며 회전.
final class CelebrateOverlayView: View {

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

    private var comboText = ""
    private var comboT: Float = 0
    private var comboAnim: ValueAnimator?

    // 참잘했어요 도장 — 콤보 이정표에서 팡 하고 찍힌다
    private var sticker: Drawable?
    private var stickerT: Float = 0
    private var stickerAnim: ValueAnimator?

    private let paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private lazy var comboPaint: Paint = {
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.textAlign = .CENTER
        p.isFakeBoldText = true
        p.color = Color.parseColor("#FF7043")
        return p
    }()
    private lazy var comboOutline: Paint = {
        let p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.textAlign = .CENTER
        p.isFakeBoldText = true
        p.style = .STROKE
        p.strokeWidth = dp(3)
        p.color = Color.WHITE
        return p
    }()

    private let colors = ["#FFD54F", "#FF8A80", "#80CBC4", "#81D4FA", "#B39DDB", "#66BB6A"].map { Color.parseColor($0) }

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
        // 아이폰: 손가락이 아래 화면으로 그대로 가도록
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 정답 축하. combo 가 2 이상이면 "🔥 N연속!" 배지도 띄운다. 5연속부터는 색종이가 많아진다.
    func correct(_ combo: Int) {
        burst(combo >= 5 ? 32 : 18)
        if [3, 5, 7, 10, 15, 20, 30].contains(combo) { showSticker() }
        if combo >= 2 { showCombo("🔥 \(combo)연속!") }
    }

    /// 레슨 완료 축하 — 콤보 배지 없이 색종이만 시차를 두고 두 번 크게
    func finale() {
        burst(40)
        postDelayed({ [weak self] in self?.burst(28) }, 450)
    }

    private func burst(_ count: Int) {
        let rnd = KRandom.default
        let cx = Float(width) / 2
        let cy = Float(height) * 0.42
        for _ in 0..<count {
            confetti.append(Confetti(
                x: cx + (rnd.nextFloat() - 0.5) * Float(width) * 0.4,
                y: cy,
                vx: (rnd.nextFloat() - 0.5) * dp(5),
                vy: -rnd.nextFloat() * dp(6) - dp(2),
                color: colors[rnd.nextInt(until: colors.count)],
                size: dp(4) + rnd.nextFloat() * dp(4),
                rot: rnd.nextFloat() * 360,
                spin: (rnd.nextFloat() - 0.5) * 22
            ))
        }
        if confettiAnim?.isRunning != true {
            let a = ValueAnimator.ofFloat(0, 1)
            a.duration = 1300
            a.addUpdateListener { [weak self] _ in
                guard let self else { return }
                for c in self.confetti {
                    c.x += c.vx
                    c.y += c.vy
                    c.vy += self.dp(0.28)
                    c.rot += c.spin
                }
                self.invalidate()
            }
            a.addListener(AnimatorListenerAdapter(onEnd: { [weak self] _ in
                self?.confetti.removeAll(); self?.invalidate()
            }))
            confettiAnim = a
            a.start()
        }
    }

    private func showCombo(_ text: String) {
        comboText = text
        comboAnim?.cancel()
        let a = ValueAnimator.ofFloat(0, 1)
        a.duration = 1100
        a.interpolator = OvershootInterpolator(2.2)
        a.addUpdateListener { [weak self] in self?.comboT = $0.animatedFloat; self?.invalidate() }
        a.addListener(AnimatorListenerAdapter(onEnd: { [weak self] _ in
            self?.comboText = ""; self?.invalidate()
        }))
        comboAnim = a
        a.start()
    }

    private func showSticker() {
        let id = context.resources.getIdentifier(
            "stk_" + "%02d".format(KRandom.default.nextInt(from: 1, until: 13)), "drawable", context.packageName
        )
        if id == 0 { return }
        sticker = context.getDrawable(id)
        stickerAnim?.cancel()
        let a = ValueAnimator.ofFloat(0, 1)
        a.duration = 1400
        a.interpolator = OvershootInterpolator(2.4)
        a.addUpdateListener { [weak self] in self?.stickerT = $0.animatedFloat; self?.invalidate() }
        a.addListener(AnimatorListenerAdapter(onEnd: { [weak self] _ in
            self?.sticker = nil; self?.invalidate()
        }))
        stickerAnim = a
        a.start()
    }

    override func onDraw(_ canvas: Canvas) {
        super.onDraw(canvas)
        if let d = sticker {
            // 도장 찍히듯: 크게 나타나 살짝 기울었다가 사라진다
            let s = (dp(60) + dp(70) * stickerT.coerceAtMost(1)).toInt()
            let alpha = stickerT > 0.8 ? ((1 - stickerT) / 0.2 * 255).toInt() : 255
            let cx = width / 2
            let cy = (Float(height) * 0.44).toInt()
            canvas.save()
            canvas.rotate(-8 + 8 * stickerT, Float(cx), Float(cy))
            d.setBounds(cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2)
            d.alpha = alpha.coerceIn(0, 255)
            d.draw(canvas)
            canvas.restore()
        }
        for c in confetti {
            paint.color = c.color
            canvas.save()
            canvas.rotate(c.rot, c.x, c.y)
            canvas.drawRoundRect(
                c.x - c.size, c.y - c.size * 0.6, c.x + c.size, c.y + c.size * 0.6,
                c.size * 0.3, c.size * 0.3, paint
            )
            canvas.restore()
        }

        if !comboText.isEmpty {
            // 앞 70%: 팝인, 뒤 30%: 페이드아웃
            let scale = 0.5 + 0.5 * comboT.coerceAtMost(1)
            let alpha = comboT > 0.75 ? ((1 - comboT) / 0.25 * 255).toInt() : 255
            comboPaint.textSize = dp(30) * scale
            comboOutline.textSize = comboPaint.textSize
            comboPaint.alpha = alpha.coerceIn(0, 255)
            comboOutline.alpha = alpha.coerceIn(0, 255)
            let x = Float(width) / 2
            let y = Float(height) * 0.30
            canvas.drawText(comboText, x, y, comboOutline)
            canvas.drawText(comboText, x, y, comboPaint)
        }
    }

    override func onDetachedFromWindow() {
        super.onDetachedFromWindow()
        confettiAnim?.cancel()
        comboAnim?.cancel()
        stickerAnim?.cancel()
    }

    private func dp(_ v: Float) -> Float { v * context.resources.displayMetrics.density }
}
