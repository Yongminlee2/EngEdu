import Foundation

/// TTS 래퍼. 대화문은 화자별 피치를 바꿔 2인 연출. (Pair 는 (first:, second:) 튜플)
final class Tts {

    private var tts: TextToSpeech? = nil
    private(set) var ready = false
    var rate: Float = 1.0 // 사용자 설정 속도

    private let main = Handler(Looper.getMainLooper())
    private var seq = 0
    private var pending: [(first: Float, second: String)] = []
    private var pendingIdx = 0
    private var onQueueDone: (() -> Void)? = nil
    private let onReady: (Bool) -> Void

    /// 진행 알림을 닫힘으로 받는다
    private final class Listener: UtteranceProgressListener {
        let next: (String?) -> Void
        init(_ next: @escaping (String?) -> Void) { self.next = next }
        override func onStart(_ utteranceId: String?) {}
        override func onError(_ utteranceId: String?) { next(utteranceId) }
        override func onDone(_ utteranceId: String?) { next(utteranceId) }
    }

    /// 대화문에서 지금 읽는 줄의 id. 아이폰은 stop() 으로 끊긴 말에도 onDone 이 와서,
    /// 그 줄의 끝일 때만 다음 줄로 넘어가게 거른다 (안드로이드는 끊긴 말에 onDone 을 안 준다).
    private var lineId: String? = nil

    init(_ ctx: Context, _ onReady: @escaping (Bool) -> Void = { _ in }) {
        self.onReady = onReady
        tts = TextToSpeech(ctx.applicationContext) { [weak self] status in
            guard let self = self else { return }
            self.ready = status == TextToSpeech.SUCCESS
            if self.ready {
                let r = self.tts?.setLanguage(JLocale.US)
                if r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED { self.ready = false }
            }
            if self.ready {
                self.tts?.setOnUtteranceProgressListener(Listener { [weak self] id in
                    self?.main.post { self?.nextInQueue(id) }
                })
            }
            let ok = self.ready
            self.main.post { self.onReady(ok) }
        }
    }

    /// 한국어로 읽어 준다 (수학 문제 읽어주기).
    /// 언어는 재생 직전에 매번 지정한다 — 끝나고 되돌리는 방식은 타이밍이 어긋나기 쉽다.
    func speakKo(_ text: String) {
        guard let t = tts else { return }
        pending = []; onQueueDone = nil
        t.stop()
        t.setLanguage(JLocale.KOREAN)
        t.setPitch(1.05)
        t.setSpeechRate(rate * 0.95)
        t.speak(text, TextToSpeech.QUEUE_FLUSH, nil, "ko\(seq)")
        seq += 1
    }

    /// 단문 재생. slow=true 면 절반 속도(거북이 버튼).
    func speak(_ text: String, slow: Bool = false, pitch: Float = 1.0) {
        guard let t = tts else { return }
        pending = []; onQueueDone = nil
        t.stop()
        t.setLanguage(JLocale.US)
        t.setPitch(pitch)
        t.setSpeechRate(slow ? rate * 0.55 : rate)
        t.speak(text, TextToSpeech.QUEUE_FLUSH, nil, "u\(seq)")
        seq += 1
    }

    /// (피치, 문장) 목록을 순서대로 재생 — 대화문용
    func speakLines(_ lines: [(first: Float, second: String)], _ onDone: (() -> Void)? = nil) {
        guard let t = tts else { return }
        t.stop()
        pending = lines
        pendingIdx = 0
        onQueueDone = onDone
        playPending()
    }

    private func playPending() {
        guard let t = tts else { return }
        t.setLanguage(JLocale.US)
        if pendingIdx >= pending.count {
            pending = []
            onQueueDone?(); onQueueDone = nil
            return
        }
        let (pitch, text) = pending[pendingIdx]
        t.setPitch(pitch)
        t.setSpeechRate(rate)
        let id = "u\(seq)"
        seq += 1
        lineId = id
        t.speak(text, TextToSpeech.QUEUE_FLUSH, nil, id)
    }

    private func nextInQueue(_ id: String?) {
        if pending.isEmpty || id != lineId { return }
        pendingIdx += 1
        playPending()
    }

    func stop() {
        pending = []; onQueueDone = nil
        tts?.stop()
    }

    func shutdown() {
        stop()
        tts?.shutdown()
        tts = nil
    }
}
