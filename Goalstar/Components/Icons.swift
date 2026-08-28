import SwiftUI

struct GSIcon: View {
    let name: GSIconName
    var size: CGFloat = 20
    var color: Color = GSColor.textPrimary
    var lineWidth: CGFloat = 1.75

    var body: some View {
        IconShape(name: name)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct IconShape: Shape {
    let name: GSIconName

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let o = CGPoint(x: rect.midX - s / 2, y: rect.midY - s / 2)

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: o.x + x / 24 * s, y: o.y + y / 24 * s)
        }

        var path = Path()
        switch name {
        case .house:
            path.move(to: p(3, 10))
            path.addLine(to: p(12, 3))
            path.addLine(to: p(21, 10))
            path.addLine(to: p(21, 20))
            path.addQuadCurve(to: p(19, 22), control: p(21, 22))
            path.addLine(to: p(5, 22))
            path.addQuadCurve(to: p(3, 20), control: p(3, 22))
            path.closeSubpath()
            path.move(to: p(9, 22))
            path.addLine(to: p(9, 14))
            path.addLine(to: p(15, 14))
            path.addLine(to: p(15, 22))

        case .target:
            path.addEllipse(in: CGRect(origin: p(4, 4), size: CGSize(width: s * 16 / 24, height: s * 16 / 24)))
            path.addEllipse(in: CGRect(origin: p(8, 8), size: CGSize(width: s * 8 / 24, height: s * 8 / 24)))
            path.move(to: p(12, 2))
            path.addLine(to: p(12, 6))
            path.move(to: p(12, 18))
            path.addLine(to: p(12, 22))
            path.move(to: p(2, 12))
            path.addLine(to: p(6, 12))
            path.move(to: p(18, 12))
            path.addLine(to: p(22, 12))

        case .timer:
            path.addEllipse(in: CGRect(origin: p(4, 5), size: CGSize(width: s * 16 / 24, height: s * 16 / 24)))
            path.move(to: p(12, 9))
            path.addLine(to: p(12, 13))
            path.addLine(to: p(15, 15))
            path.move(to: p(9, 2))
            path.addLine(to: p(15, 2))

        case .barChart:
            path.move(to: p(6, 20))
            path.addLine(to: p(6, 12))
            path.move(to: p(12, 20))
            path.addLine(to: p(12, 6))
            path.move(to: p(18, 20))
            path.addLine(to: p(18, 14))

        case .user:
            path.addEllipse(in: CGRect(origin: p(8, 3), size: CGSize(width: s * 8 / 24, height: s * 8 / 24)))
            path.move(to: p(4, 21))
            path.addQuadCurve(to: p(12, 15), control: p(4, 15))
            path.addQuadCurve(to: p(20, 21), control: p(20, 15))

        case .clock:
            path.addEllipse(in: CGRect(origin: p(3, 3), size: CGSize(width: s * 18 / 24, height: s * 18 / 24)))
            path.move(to: p(12, 7))
            path.addLine(to: p(12, 12))
            path.addLine(to: p(15.5, 14))

        case .checkCircle:
            path.addEllipse(in: CGRect(origin: p(3, 3), size: CGSize(width: s * 18 / 24, height: s * 18 / 24)))
            path.move(to: p(8, 12))
            path.addLine(to: p(11, 15))
            path.addLine(to: p(16.5, 9.5))

        case .flame:
            path.move(to: p(12, 3))
            path.addCurve(to: p(8, 12), control1: p(10, 6), control2: p(7, 8))
            path.addCurve(to: p(12, 21), control1: p(9, 16), control2: p(10, 19))
            path.addCurve(to: p(16, 12), control1: p(14, 19), control2: p(17, 16))
            path.addCurve(to: p(12, 3), control1: p(15, 8), control2: p(14, 6))
            path.move(to: p(12, 12))
            path.addCurve(to: p(10.5, 17), control1: p(11, 14), control2: p(10.5, 15.5))

        case .play:
            path.move(to: p(9, 7))
            path.addLine(to: p(17, 12))
            path.addLine(to: p(9, 17))
            path.closeSubpath()

        case .plus:
            path.move(to: p(12, 5))
            path.addLine(to: p(12, 19))
            path.move(to: p(5, 12))
            path.addLine(to: p(19, 12))

        case .lock:
            path.addRoundedRect(
                in: CGRect(origin: p(5, 11), size: CGSize(width: s * 14 / 24, height: s * 10 / 24)),
                cornerSize: CGSize(width: s * 2 / 24, height: s * 2 / 24)
            )
            path.move(to: p(8, 11))
            path.addLine(to: p(8, 8))
            path.addQuadCurve(to: p(16, 8), control: p(12, 3))
            path.addLine(to: p(16, 11))

        case .sun:
            path.addEllipse(in: CGRect(origin: p(8, 8), size: CGSize(width: s * 8 / 24, height: s * 8 / 24)))
            for angle in stride(from: 0.0, to: 360.0, by: 45.0) {
                let rad = angle * .pi / 180
                let inner = CGPoint(x: 12 + cos(rad) * 6, y: 12 + sin(rad) * 6)
                let outer = CGPoint(x: 12 + cos(rad) * 9.5, y: 12 + sin(rad) * 9.5)
                path.move(to: p(inner.x, inner.y))
                path.addLine(to: p(outer.x, outer.y))
            }

        case .bookOpen:
            path.move(to: p(3, 6))
            path.addLine(to: p(12, 4))
            path.addLine(to: p(12, 19))
            path.addLine(to: p(3, 21))
            path.closeSubpath()
            path.move(to: p(21, 6))
            path.addLine(to: p(12, 4))
            path.addLine(to: p(12, 19))
            path.addLine(to: p(21, 21))
            path.closeSubpath()

        case .circleX:
            path.addEllipse(in: CGRect(origin: p(3, 3), size: CGSize(width: s * 18 / 24, height: s * 18 / 24)))
            path.move(to: p(9, 9))
            path.addLine(to: p(15, 15))
            path.move(to: p(15, 9))
            path.addLine(to: p(9, 15))

        case .chartPie:
            path.addEllipse(in: CGRect(origin: p(3, 3), size: CGSize(width: s * 18 / 24, height: s * 18 / 24)))
            path.move(to: p(12, 12))
            path.addLine(to: p(12, 3))
            path.move(to: p(12, 12))
            path.addLine(to: p(19, 16))

        case .chevronRight:
            path.move(to: p(9, 6))
            path.addLine(to: p(15, 12))
            path.addLine(to: p(9, 18))

        case .star:
            let pts: [(CGFloat, CGFloat)] = [
                (12, 2), (14.5, 9), (22, 9), (16, 13.5),
                (18.5, 21), (12, 16.5), (5.5, 21), (8, 13.5),
                (2, 9), (9.5, 9)
            ]
            path.move(to: p(pts[0].0, pts[0].1))
            for i in 1..<pts.count {
                path.addLine(to: p(pts[i].0, pts[i].1))
            }
            path.closeSubpath()

        case .check:
            path.move(to: p(5, 12))
            path.addLine(to: p(10, 17))
            path.addLine(to: p(19, 7))

        case .bell:
            path.move(to: p(6, 10))
            path.addQuadCurve(to: p(12, 3), control: p(6, 4))
            path.addQuadCurve(to: p(18, 10), control: p(18, 4))
            path.addLine(to: p(18, 15))
            path.addLine(to: p(20, 18))
            path.addLine(to: p(4, 18))
            path.addLine(to: p(6, 15))
            path.closeSubpath()
            path.move(to: p(10, 18))
            path.addQuadCurve(to: p(14, 18), control: p(12, 21))

        case .cloud:
            path.move(to: p(6, 16))
            path.addQuadCurve(to: p(4, 12), control: p(3, 16))
            path.addQuadCurve(to: p(9, 9), control: p(4, 8))
            path.addQuadCurve(to: p(16, 8), control: p(11, 4))
            path.addQuadCurve(to: p(20, 13), control: p(20, 8))
            path.addQuadCurve(to: p(17, 16), control: p(21, 16))
            path.addLine(to: p(6, 16))

        case .info:
            path.addEllipse(in: CGRect(origin: p(3, 3), size: CGSize(width: s * 18 / 24, height: s * 18 / 24)))
            path.move(to: p(12, 11))
            path.addLine(to: p(12, 17))
            path.move(to: p(12, 7.5))
            path.addLine(to: p(12, 8.5))

        case .percent:
            path.addEllipse(in: CGRect(origin: p(5, 5), size: CGSize(width: s * 4 / 24, height: s * 4 / 24)))
            path.addEllipse(in: CGRect(origin: p(15, 15), size: CGSize(width: s * 4 / 24, height: s * 4 / 24)))
            path.move(to: p(17, 7))
            path.addLine(to: p(7, 17))
        }
        return path
    }
}
