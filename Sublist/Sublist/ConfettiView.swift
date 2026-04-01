import SwiftUI

struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let startX: CGFloat   // relative (0–1) across card width
        let xDrift: CGFloat   // horizontal offset at end
        let color: Color
        let width: CGFloat
        let height: CGFloat
        let startAngle: Double
        let endAngle: Double
        let delay: Double
    }

    @State private var pieces: [Piece] = []
    @State private var animate = false

    private static let palette: [Color] = [
        Color(red: 0.98, green: 0.38, blue: 0.42),
        Color(red: 0.36, green: 0.76, blue: 0.98),
        Color(red: 0.98, green: 0.84, blue: 0.28),
        Color(red: 0.42, green: 0.92, blue: 0.52),
        Color(red: 0.85, green: 0.46, blue: 0.98),
        Color(red: 0.98, green: 0.62, blue: 0.28),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.width, height: p.height)
                        .rotationEffect(.degrees(animate ? p.endAngle : p.startAngle))
                        .offset(
                            x: geo.size.width * p.startX - geo.size.width / 2 + (animate ? p.xDrift : 0),
                            y: animate ? geo.size.height * 0.9 : geo.size.height * 0.05
                        )
                        .opacity(animate ? 0 : 0.92)
                        .animation(
                            .easeOut(duration: 1.1).delay(p.delay),
                            value: animate
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .onAppear {
            pieces = (0..<28).map { _ in
                Piece(
                    startX: CGFloat.random(in: 0.1...0.9),
                    xDrift: CGFloat.random(in: -55...55),
                    color: Self.palette.randomElement()!,
                    width: CGFloat.random(in: 5...9),
                    height: CGFloat.random(in: 8...13),
                    startAngle: Double.random(in: -25...25),
                    endAngle: Double.random(in: -200...200),
                    delay: Double.random(in: 0...0.2)
                )
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animate = true
            }
        }
    }
}

#Preview {
    ZStack {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.green.opacity(0.1))
            .frame(width: 340, height: 70)
        ConfettiView()
            .frame(width: 340, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
