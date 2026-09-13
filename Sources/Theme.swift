import SwiftUI

// Ngjyrat e stilit iBo RTX 4K (identike me Android / Web-App)
extension Color {
    static let bg    = Color(hex: 0x050510)
    static let card  = Color(hex: 0x131C33)
    static let card2 = Color(hex: 0x1B2647)
    static let brand = Color(hex: 0x00C2FF)
    static let lav   = Color(hex: 0xA9C4F0)
    static let txt2  = Color(hex: 0x93A4C8)
    static let line  = Color(hex: 0x2A3957)

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0)
    }
}

struct HexLogo: View {
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            HexagonShape()
                .stroke(Color.brand, lineWidth: size * 0.055)
            Text("M")
                .font(.system(size: size * 0.5, weight: .black))
                .foregroundColor(.lav)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.brand.opacity(0.6), radius: size * 0.18)
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        for i in 0...5 {
            let a = CGFloat(i) * 60 * .pi / 180 - .pi / 2
            let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
