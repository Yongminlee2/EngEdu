import UIKit

/// 바구니에 담기.
/// 위에 흩어진 사물을 손가락으로 끌어 바구니에 넣는다. 목표 개수만큼 담고 "다 담았어요"를 누른다.
/// 잘못 담았으면 다시 꺼낼 수도 있다(바구니에서 위로 끌기).
final class BasketGameView: GameView {

    private final class Item {
        var x: Float, y: Float
        var homeX: Float, homeY: Float
        var inBasket: Bool
        var scale: Float
        init(_ x: Float, _ y: Float, _ homeX: Float, _ homeY: Float, inBasket: Bool = false, scale: Float = 1) {
            self.x = x; self.y = y; self.homeX = homeX; self.homeY = homeY
            self.inBasket = inBasket; self.scale = scale
        }
    }

    private let rnd: KRandom = XorWowRandom(seed: System.currentTimeMillis())
    private var items: [Item] = []
    private var dragging: Item?
    private var dragDx: Float = 0
    private var dragDy: Float = 0

    private var emoji = "🍎"
    private var target = 5
    private var pool = 12

    private let emojiPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { $0.textAlign = .CENTER }
    private let basketPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private let linePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        $0.style = .STROKE
        $0.color = Color.parseColor("#A1887F")
    }
    private let textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        $0.textAlign = .CENTER
        $0.color = Color.parseColor("#4E342E")
        $0.isFakeBoldText = true
    }

    private var itemSize: Float = 0
    private var basket = RectF()

    /// 지금 바구니에 담긴 개수
    var countInBasket: Int { items.filter { $0.inBasket }.count }

    /// 목표 개수
    var targetCount: Int { target }

    override init(_ context: Context, _ attrs: AttributeSet? = nil) {
        super.init(context, attrs)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setRound(_ r: GameRound) {
        emoji = r.emoji ?? "🍎"
        target = r.answer.toIntOrNull() ?? 5
        pool = (target + 4).coerceAtMost(16)
        layoutItems()
        if let s = r.speak { onSpeak?(s) }
        invalidate()
    }

    override func onSizeChanged(_ w: Int, _ h: Int, _ oldw: Int, _ oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        itemSize = Float(min(w, h)) * 0.115
        emojiPaint.textSize = itemSize
        textPaint.textSize = itemSize * 0.62
        linePaint.strokeWidth = dp(3)
        let bw = Float(w) * 0.62
        let bh = Float(h) * 0.26
        basket = RectF((Float(w) - bw) / 2, Float(h) - bh - dp(12), (Float(w) + bw) / 2, Float(h) - dp(12))
        layoutItems()
    }

    private func layoutItems() {
        if width == 0 || height == 0 { return }
        items.removeAll()
        let perRow = 5
        let topArea = basket.top - dp(20)
        let cellW = Float(width) / Float(perRow)
        let rows = (pool + perRow - 1) / perRow
        let cellH = (topArea * 0.75) / Float(rows)
        for i in 0..<pool {
            let r = i / perRow
            let c = i % perRow
            let x = cellW * (Float(c) + 0.5) + (rnd.nextFloat() - 0.5) * cellW * 0.2
            let y = dp(20) + cellH * (Float(r) + 0.6)
            items.append(Item(x, y, x, y))
        }
    }

    override func update(_ dt: Float) {
        // 담긴 항목이 살짝 작아지는 연출
        for it in items {
            let want: Float = it.inBasket ? 0.78 : 1
            it.scale += (want - it.scale) * (dt * 8).coerceAtMost(1)
        }
    }

    override func render(_ canvas: Canvas) {
        // 바구니
        basketPaint.color = Color.parseColor("#D7A86E")
        canvas.drawRoundRect(basket, dp(18), dp(18), basketPaint)
        basketPaint.color = Color.parseColor("#C08B4E")
        canvas.drawRoundRect(
            RectF(basket.left, basket.top, basket.right, basket.top + dp(14)),
            dp(8), dp(8), basketPaint
        )
        // 바구니 무늬
        var gx = basket.left + dp(14)
        while gx < basket.right - dp(6) {
            canvas.drawLine(gx, basket.top + dp(16), gx, basket.bottom - dp(8), linePaint)
            gx += dp(22)
        }

        // 담긴 개수 / 목표
        textPaint.color = Color.parseColor("#4E342E")
        canvas.drawText(
            "\(countInBasket) / \(target)",
            basket.centerX(), basket.bottom - dp(14), textPaint
        )

        // 사물
        for it in items {
            emojiPaint.textSize = itemSize * it.scale
            canvas.drawText(emoji, it.x, it.y + emojiPaint.textSize * 0.35, emojiPaint)
        }
        // 끌고 있는 것은 맨 위에 다시 그린다
        if let it = dragging {
            emojiPaint.textSize = itemSize * 1.15
            canvas.drawText(emoji, it.x, it.y + emojiPaint.textSize * 0.35, emojiPaint)
        }
    }

    override func onTouchEvent(_ event: MotionEvent) -> Bool {
        switch event.actionMasked {
        case MotionEvent.ACTION_DOWN:
            dragging = items.lastOrNull { hypot(event.x - $0.x, event.y - $0.y) < itemSize * 0.75 }
            if let it = dragging {
                dragDx = it.x - event.x
                dragDy = it.y - event.y
            }
            parent?.requestDisallowInterceptTouchEvent(true)
            invalidate()
            return true
        case MotionEvent.ACTION_MOVE:
            if let it = dragging {
                it.x = event.x + dragDx
                it.y = event.y + dragDy
                invalidate()
            }
            return true
        case MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL:
            guard let d = dragging else { return true }
            dragging = nil
            let inside = basket.contains(d.x, d.y)
            if inside {
                if !d.inBasket {
                    d.inBasket = true
                    // 바구니 안에서 겹치지 않게 자리 잡기
                    let n = items.filter { $0.inBasket }.count - 1
                    let perRow = 5
                    let cw = basket.width() / Float(perRow)
                    let ch = (basket.height() - dp(30)) / 3
                    d.x = basket.left + cw * (Float(n % perRow) + 0.5)
                    d.y = basket.top + dp(22) + ch * (Float(n / perRow) + 0.4)
                }
            } else {
                // 바구니 밖으로 꺼내면 원래 자리로
                d.inBasket = false
                d.x = d.homeX
                d.y = d.homeY
            }
            invalidate()
            return true
        default:
            break
        }
        return true
    }

    /// "다 담았어요"를 눌렀을 때 채점
    @discardableResult func check() -> Bool {
        let ok = countInBasket == target
        if ok { onHit?() } else { onMiss?() }
        return ok
    }
}
