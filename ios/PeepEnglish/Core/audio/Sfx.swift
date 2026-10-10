import Foundation

/// 효과음 + 진동.
/// 효과음이 TTS(듣기·말하기) 음성을 덮지 않도록 기본 볼륨을 낮게 잡는다. 설정에서 0~100% 로 조절한다.
final class Sfx {

    /// 기본 30% — 이보다 크면 발음이 잘 안 들린다
    static let DEFAULT_VOLUME_PERCENT = 30

    /// 톡톡 누르는 소리(삐약)의 배율. 자주 울리므로 정답·오답 소리보다 훨씬 작다.
    static let TAP_VOLUME_SCALE: Float = 0.25

    private let pool: SoundPool

    private let vib: Vibrator?

    /// 0.0 ~ 1.0
    var volume: Float

    private let sCorrect: Int
    private let sWrong: Int
    private let sDone: Int
    private let sPiyak: Int

    init(_ ctx: Context) {
        let pool = SoundPool.Builder()
            .setMaxStreams(2)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
            ).build()
        self.pool = pool
        vib = ctx.getVibrator()
        volume = (Float(Db.get(ctx).metaInt("sfx_volume", Sfx.DEFAULT_VOLUME_PERCENT)) / 100).coerceIn(0, 1)

        func load(_ name: String) -> Int {
            let resId = ctx.resources.getIdentifier(name, "raw", ctx.packageName)
            return resId != 0 ? pool.load(ctx, resId, 1) : 0
        }
        sCorrect = load("sfx_correct")
        sWrong = load("sfx_wrong")
        sDone = load("sfx_done")
        sPiyak = load("sfx_piyak")
    }

    private func play(_ id: Int, _ scale: Float = 1) {
        if id == 0 || volume <= 0 { return }
        let v = (volume * scale).coerceIn(0, 1)
        pool.play(id, v, v, 1, 0, 1)
    }

    func correct() { play(sCorrect) }
    func wrong() {
        play(sWrong, 0.9)
        // 소리를 줄여도 틀린 건 알 수 있도록 진동은 남긴다
        vib?.vibrate(VibrationEffect.createOneShot(110, VibrationEffect.DEFAULT_AMPLITUDE))
    }
    func done() { play(sDone) }

    /// 톡톡 누를 때 나는 소리
    func piyak() { play(sPiyak, Sfx.TAP_VOLUME_SCALE) }

    func release() { pool.release() }
}
