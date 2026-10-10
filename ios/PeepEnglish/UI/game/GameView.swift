import UIKit

/// 미니게임 공통 뼈대 (코틀린 abstract class).
/// onDraw 안에서 시간 간격(dt)을 계산해 update → render 를 돌리고,
/// 게임이 진행 중이면 다음 프레임을 스스로 예약한다.
class GameView: View {

    /// 정답을 맞혔을 때 (점수 증가)
    var onHit: (() -> Void)?

    /// 틀렸거나 놓쳤을 때
    var onMiss: (() -> Void)?

    /// 한 라운드가 끝나 다음 문제가 필요할 때
    var onNextRound: (() -> Void)?

    /// 게임 전체가 끝났을 때
    var onFinish: (() -> Void)?

    /// 읽어 줄 말이 생겼을 때
    var onSpeak: ((String) -> Void)?

    private(set) var running = false

    private var lastFrameNs = 0

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
    }
    required init?(coder: NSCoder) { fatalError() }

    func startLoop() {
        if running { return }
        running = true
        lastFrameNs = 0
        postInvalidateOnAnimation()
    }

    func stopLoop() {
        running = false
    }

    override func onDraw(_ canvas: Canvas) {
        super.onDraw(canvas)
        let now = System.nanoTime()
        let dt: Float = lastFrameNs == 0 ? 0 : (Float(now - lastFrameNs) / 1_000_000_000).coerceAtMost(0.05)
        lastFrameNs = now

        if running { update(dt) }
        render(canvas)
        if running { postInvalidateOnAnimation() }
    }

    override func onDetachedFromWindow() {
        super.onDetachedFromWindow()
        stopLoop()
    }

    /// dt(초)만큼 상태를 진행시킨다 (하위 클래스가 덮어쓴다)
    func update(_ dt: Float) {}

    /// 현재 상태를 그린다 (하위 클래스가 덮어쓴다)
    func render(_ canvas: Canvas) {}

    func dp(_ v: Float) -> Float { v * context.resources.displayMetrics.density }
}

/// 이 글자가 그림문자(이모지)인가.
/// 한글·한자·가나는 이모지가 아니다 — 첫 코드포인트로 판정한다.
func isEmojiText(_ s: String) -> Bool {
    guard let first = s.unicodeScalars.first else { return false }
    let cp = Int(first.value)
    return cp >= 0x1F000 ||               // 🍎 🐥 … 그림문자 평면
        (0x2190...0x21FF).contains(cp) || // 화살표
        (0x2600...0x27BF).contains(cp) || // ⭐ ✏️ ✔ 기타 기호
        (0x2B00...0x2BFF).contains(cp)    // ⬅ ⭕ 등
}
