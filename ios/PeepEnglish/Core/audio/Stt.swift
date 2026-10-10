import AVFoundation
import Speech

/// 안드로이드 SpeechRecognizer 의 오류 번호 (LessonActivity 가 그대로 비교한다)
enum SpeechRecognizer {
    static let ERROR_NETWORK_TIMEOUT = 1, ERROR_NETWORK = 2, ERROR_AUDIO = 3, ERROR_SERVER = 4
    static let ERROR_CLIENT = 5, ERROR_SPEECH_TIMEOUT = 6, ERROR_NO_MATCH = 7, ERROR_RECOGNIZER_BUSY = 8
    static let ERROR_INSUFFICIENT_PERMISSIONS = 9
}

/// 영어 음성인식 래퍼 (말하기 채점용) — 아이폰은 Speech 프레임워크.
///
/// 안드로이드 인식기는 말이 끝나면 저절로 멈춘다. 아이폰은 그런 끝맺음이 없어서
/// 말이 들리기 시작한 뒤 1.2초 조용하면 끝낸다(말을 안 하면 6초 뒤 ERROR_SPEECH_TIMEOUT).
/// 기기에서 인식할 수 있으면 기기 안에서만 처리한다(소리를 밖으로 보내지 않게).
final class Stt {
    private let recognizer = SFSpeechRecognizer(locale: Foundation.Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?
    private var lastText = ""
    private var finished = false
    private var onResult: ((String) -> Void)?
    private var onError: ((Int) -> Void)?
    private(set) var listening = false

    init(_ ctx: Context) {}

    func available() -> Bool { recognizer?.isAvailable ?? false }

    func start(onResult: @escaping (String) -> Void, onError: @escaping (Int) -> Void, onLevel: @escaping (Float) -> Void = { _ in }) {
        stop()
        guard let rec = recognizer, rec.isAvailable else { onError(-1); return }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { onError(SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS); return }
        self.onResult = onResult
        self.onError = onError
        finished = false
        lastText = ""

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { finish(error: SpeechRecognizer.ERROR_AUDIO); return }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if rec.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        request = req

        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0 else { finish(error: SpeechRecognizer.ERROR_AUDIO); return }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            self?.request?.append(buf)
            // 소리 크기(dB 비슷한 값) — 안드로이드 onRmsChanged 자리
            if let ch = buf.floatChannelData?[0] {
                let n = Int(buf.frameLength)
                var sum: Float = 0
                for i in 0..<n { sum += ch[i] * ch[i] }
                let rms = sqrt(sum / Float(max(1, n)))
                let db = 20 * log10(max(rms, 1e-6)) + 60
                DispatchQueue.main.async { onLevel(db / 6) }
            }
        }
        engine.prepare()
        do { try engine.start() } catch { finish(error: SpeechRecognizer.ERROR_AUDIO); return }
        listening = true

        task = rec.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self, !self.finished else { return }
                if let r = result {
                    self.lastText = r.bestTranscription.formattedString
                    if r.isFinal { self.finish(text: self.lastText); return }
                    self.armSilence(1.2)
                } else if error != nil {
                    if self.lastText.isEmpty { self.finish(error: SpeechRecognizer.ERROR_NO_MATCH) } else { self.finish(text: self.lastText) }
                }
            }
        }
        // 아무 말도 없으면
        armSilence(6, timeoutIfEmpty: true)
    }

    private func armSilence(_ seconds: Double, timeoutIfEmpty: Bool = false) {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            guard let self, !self.finished else { return }
            if self.lastText.isEmpty { self.finish(error: timeoutIfEmpty ? SpeechRecognizer.ERROR_SPEECH_TIMEOUT : SpeechRecognizer.ERROR_NO_MATCH) }
            else { self.finish(text: self.lastText) }
        }
    }

    private func finish(text: String? = nil, error: Int? = nil) {
        guard !finished else { return }
        finished = true
        let r = onResult, e = onError
        teardown()
        if let t = text { r?(t) } else if let c = error { e?(c) }
    }

    private func teardown() {
        listening = false
        silenceTimer?.invalidate(); silenceTimer = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil; request = nil
        // 효과음·읽어주기가 다시 평소대로 나오게
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func stop() {
        finished = true
        onResult = nil; onError = nil
        if listening || task != nil { teardown() }
    }
}
