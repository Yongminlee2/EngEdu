import UIKit

/// 포즈 그림에 두 번째 프레임(`이름_b`)이 있으면 둘을 번갈아 보여주는 드로어블을 만든다.
/// 프레임이 없는 그림은 그냥 정지 그림으로 들어간다.
enum PoseAnim {

    /// 프레임 교대 간격 (원본 ms, _b ms)
    private static func timing(_ name: String) -> (Int, Int) {
        switch name {
        case "ck_idle": return (2600, 200)      // 가끔 눈 깜빡
        case "ck_cheer": return (330, 330)      // 신나는 날갯짓
        case "ck_listen": return (950, 950)     // 고개 까딱까딱
        case "ck_write": return (650, 650)      // 사각사각
        case "ck_speak": return (380, 380)      // 재잘재잘
        case "ck_sleep": return (1300, 1300)    // 새근새근
        default: return (800, 800)
        }
    }

    /// 두 프레임 애니메이션 드로어블 (_b 가 없으면 nil)
    static func of(_ ctx: Context, _ resId: Int) -> Drawable? {
        if resId == 0 { return nil }
        // 안드로이드는 없는 번호면 예외 → nil
        let name = ctx.resources.getResourceEntryName(resId)
        if name.isEmpty { return nil }
        let bId = ctx.resources.getIdentifier(name + "_b", "drawable", ctx.packageName)
        if bId == 0 { return nil }
        guard let f1 = ctx.getDrawable(resId) else { return nil }
        guard let f2 = ctx.getDrawable(bId) else { return nil }
        let (d1, d2) = timing(name)
        let a = AnimationDrawable()
        a.isOneShot = false
        a.addFrame(f1, d1)
        a.addFrame(f2, d2)
        return a
    }

    /// 이미지뷰에 넣는다 — 두 번째 프레임이 있으면 움직이고, 없으면 정지 그림
    static func applyTo(_ img: ImageView, _ resId: Int) {
        if resId == 0 { return }
        if let anim = of(img.context, resId) {
            img.setImageDrawable(anim)
            img.post { [weak img] in (img?.getDrawable() as? AnimationDrawable)?.start() }
        } else {
            img.setImageResource(resId)
        }
    }
}
