import AVFoundation
import UIKit

// 안드로이드 SoundPool·TextToSpeech 의 아이폰판.
// 효과음은 안드로이드 res/raw 의 OGG 를 tools/convert-sfx.sh 가 m4a 로 바꿔 둔 사본을 튼다.

final class AudioAttributes {
    static let USAGE_GAME = 14, USAGE_MEDIA = 1, USAGE_ASSISTANCE_SONIFICATION = 13
    static let CONTENT_TYPE_SONIFICATION = 4, CONTENT_TYPE_SPEECH = 1
    final class Builder {
        @discardableResult func setUsage(_ u: Int) -> Builder { self }
        @discardableResult func setContentType(_ c: Int) -> Builder { self }
        func build() -> AudioAttributes { AudioAttributes() }
    }
}

enum AudioSessionSetup {
    private static var done = false
    /// 다른 앱 소리와 섞어 틀고, 무음 스위치를 따른다
    static func ambient() {
        guard !done else { return }
        done = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

final class SoundPool {
    final class Builder {
        private var max = 4
        @discardableResult func setMaxStreams(_ n: Int) -> Builder { max = n; return self }
        @discardableResult func setAudioAttributes(_ a: AudioAttributes) -> Builder { self }
        func build() -> SoundPool { SoundPool(maxStreams: max) }
    }

    private var sounds: [Int: URL] = [:]
    private var players: [Int: [AVAudioPlayer]] = [:]
    private var nextId = 1
    private let maxStreams: Int
    private var onLoad: ((SoundPool, Int, Int) -> Void)?

    init(maxStreams: Int) { self.maxStreams = maxStreams; AudioSessionSetup.ambient() }

    func setOnLoadCompleteListener(_ f: ((SoundPool, Int, Int) -> Void)?) { onLoad = f }

    /// load(context, R.raw.x, priority) → 소리 번호 (0 = 실패)
    func load(_ ctx: Context?, _ resId: Int, _ priority: Int) -> Int {
        guard let url = Res.shared.rawURL(resId) else { return 0 }
        let id = nextId; nextId += 1
        sounds[id] = url
        // 미리 하나 만들어 둔다 (첫 재생이 늦지 않게)
        if let p = try? AVAudioPlayer(contentsOf: url) { p.prepareToPlay(); players[id] = [p] }
        let cb = onLoad
        DispatchQueue.main.async { cb?(self, id, 0) }
        return id
    }

    @discardableResult
    func play(_ soundId: Int, _ leftVolume: Float, _ rightVolume: Float, _ priority: Int, _ loop: Int, _ rate: Float) -> Int {
        guard let url = sounds[soundId] else { return 0 }
        var list = players[soundId] ?? []
        var p = list.first { !$0.isPlaying }
        if p == nil, list.count < maxStreams, let n = try? AVAudioPlayer(contentsOf: url) {
            n.enableRate = true
            list.append(n); players[soundId] = list; p = n
        }
        guard let player = p ?? list.first else { return 0 }
        player.enableRate = true
        player.currentTime = 0
        player.volume = max(leftVolume, rightVolume)
        player.rate = rate
        player.numberOfLoops = loop
        player.play()
        return soundId
    }
    func stop(_ streamId: Int) { players[streamId]?.forEach { $0.stop() } }
    func autoPause() { players.values.forEach { $0.forEach { $0.pause() } } }
    func release() { players.values.forEach { $0.forEach { $0.stop() } }; players = [:]; sounds = [:] }
}

// MARK: - TextToSpeech

class UtteranceProgressListener {
    func onStart(_ utteranceId: String?) {}
    func onDone(_ utteranceId: String?) {}
    func onError(_ utteranceId: String?) {}
}

final class TextToSpeech: NSObject, AVSpeechSynthesizerDelegate {
    static let SUCCESS = 0, ERROR = -1
    static let QUEUE_FLUSH = 0, QUEUE_ADD = 1
    static let LANG_AVAILABLE = 0, LANG_COUNTRY_AVAILABLE = 1, LANG_MISSING_DATA = -1, LANG_NOT_SUPPORTED = -2

    private let synth = AVSpeechSynthesizer()
    private var language = "en-US"
    private var rate: Float = 1
    private var pitch: Float = 1
    private var listener: UtteranceProgressListener?
    private var ids: [ObjectIdentifier: String] = [:]

    init(_ ctx: Context?, _ onInit: ((Int) -> Void)?) {
        super.init()
        synth.delegate = self
        AudioSessionSetup.ambient()
        DispatchQueue.main.async { onInit?(TextToSpeech.SUCCESS) }
    }

    @discardableResult func setLanguage(_ loc: JLocale) -> Int {
        let tag = loc.country.isEmpty ? loc.language : "\(loc.language)-\(loc.country)"
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if voices.contains(where: { $0.language == tag }) { language = tag; return TextToSpeech.LANG_COUNTRY_AVAILABLE }
        if let v = voices.first(where: { $0.language.hasPrefix(loc.language + "-") || $0.language == loc.language }) {
            language = v.language; return TextToSpeech.LANG_AVAILABLE
        }
        return TextToSpeech.LANG_NOT_SUPPORTED
    }
    func isLanguageAvailable(_ loc: JLocale) -> Int {
        AVSpeechSynthesisVoice.speechVoices().contains { $0.language.hasPrefix(loc.language) } ? TextToSpeech.LANG_AVAILABLE : TextToSpeech.LANG_NOT_SUPPORTED
    }
    @discardableResult func setSpeechRate(_ r: Float) -> Int { rate = r; return TextToSpeech.SUCCESS }
    @discardableResult func setPitch(_ p: Float) -> Int { pitch = p; return TextToSpeech.SUCCESS }
    func setOnUtteranceProgressListener(_ l: UtteranceProgressListener?) { listener = l }
    var isSpeaking: Bool { synth.isSpeaking }

    /// 가장 좋은 목소리(고급·프리미엄이 깔려 있으면 그것)
    private func voice() -> AVSpeechSynthesisVoice? {
        let cands = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        return cands.max { $0.quality.rawValue < $1.quality.rawValue } ?? AVSpeechSynthesisVoice(language: language)
    }

    @discardableResult func speak(_ text: String, _ queueMode: Int, _ params: Any?, _ utteranceId: String?) -> Int {
        if queueMode == TextToSpeech.QUEUE_FLUSH && synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let u = AVSpeechUtterance(string: text)
        u.voice = voice()
        // 안드로이드 1.0 = 보통 빠르기
        u.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(AVSpeechUtteranceMaximumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * rate))
        u.pitchMultiplier = max(0.5, min(2, pitch))
        if let id = utteranceId { ids[ObjectIdentifier(u)] = id }
        synth.speak(u)
        return TextToSpeech.SUCCESS
    }
    @discardableResult func stop() -> Int { synth.stopSpeaking(at: .immediate); return TextToSpeech.SUCCESS }
    func shutdown() { synth.stopSpeaking(at: .immediate); listener = nil }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) { listener?.onStart(ids[ObjectIdentifier(u)]) }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        listener?.onDone(ids.removeValue(forKey: ObjectIdentifier(u)))
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel u: AVSpeechUtterance) {
        listener?.onDone(ids.removeValue(forKey: ObjectIdentifier(u)))
    }
}
