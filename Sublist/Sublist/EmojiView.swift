import SwiftUI

// Custom UIView that draws the emoji glyph centred in its own bounds.
// Using draw(_:) gives us direct access to the Core Graphics context and
// avoids the layout/clipping issues seen with UILabel in the iOS 26 beta.
private final class EmojiCanvas: UIView {
    var emoji: String = "" { didSet { if oldValue != emoji { setNeedsDisplay() } } }
    var fontSize: CGFloat = 28 { didSet { if oldValue != fontSize { setNeedsDisplay() } } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard !emoji.isEmpty else { return }
        let font = UIFont.systemFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let str = emoji as NSString
        let textSize = str.size(withAttributes: attrs)
        let origin = CGPoint(
            x: (rect.width  - textSize.width)  / 2,
            y: (rect.height - textSize.height) / 2
        )
        str.draw(at: origin, withAttributes: attrs)
    }
}

struct EmojiView: UIViewRepresentable {
    let emoji: String
    let size: CGFloat

    func makeUIView(context: Context) -> UIView {
        EmojiCanvas()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let canvas = uiView as? EmojiCanvas else { return }
        canvas.emoji = emoji
        canvas.fontSize = size
    }
}
