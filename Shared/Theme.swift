import SwiftUI
import UIKit

enum GSSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let base: CGFloat = 16
    static let lg: CGFloat = 18
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let page: CGFloat = 16
    static let tabContentBottom: CGFloat = 100
    static let tabContentBottomWithFAB: CGFloat = 120
}

enum GSRadius {
    static let tag: CGFloat = 6
    static let card: CGFloat = 16
    static let panel: CGFloat = 20
    static let chip: CGFloat = 100
    static let play: CGFloat = 14
    static let fab: CGFloat = 27
    static let control: CGFloat = 12
}

enum GSColor {
    static let brand = Color(hex: 0x4F46E5)
    static let brandDeep = Color(hex: 0x4338CA)
    static let brandLight = Color(hex: 0xEEF2FF)
    static let brand200 = Color(hex: 0xC7D2FE)

    static let textPrimary = Color(hex: 0x0F172A)
    static let textSecondary = Color(hex: 0x64748B)
    static let textOnPrimary = Color.white
    static let textBrand = brand
    static let textAccent = Color(hex: 0xA855F7)

    static let success = Color(hex: 0x10B981)
    static let successDark = Color(hex: 0x047857)
    static let successLight = Color(hex: 0xECFDF5)
    static let warning = Color(hex: 0xF59E0B)
    static let warningLight = Color(hex: 0xFFF7ED)
    static let danger = Color(hex: 0xDC2626)
    static let dangerLight = Color(hex: 0xFEF2F2)
    static let accent = Color(hex: 0xA855F7)
    static let accentLight = Color(hex: 0xFAF5FF)

    static let bgTertiary = Color(hex: 0xF1F5F9)
    static let bgPageTop = Color(hex: 0xEEF2FF)
    static let bgPageBottom = Color(hex: 0xF8FAFC)
    static let surfaceCard = Color.white
    static let border = Color(hex: 0xE2E8F0)

    static let habitDone = Color(hex: 0x10B981)
    static let habitPending = Color(hex: 0xA855F7)
    static let habitIdle = Color(hex: 0x94A3B8)

    static let cardShadow = Color(hex: 0x0F172A).opacity(0.03)
}

enum GSFont {
    static func regular(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }

    static func medium(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }

    static func semibold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func semibold(_ size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        let uiStyle = Self.uiTextStyle(from: textStyle)
        let base = UIFont.systemFont(ofSize: size, weight: .semibold)
        let scaled = UIFontMetrics(forTextStyle: uiStyle).scaledFont(for: base)
        return Font(scaled)
    }

    static func bold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }

    private static func uiTextStyle(from textStyle: Font.TextStyle) -> UIFont.TextStyle {
        switch textStyle {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }

    static let xs: CGFloat = 10
    static let sm: CGFloat = 11
    static let md: CGFloat = 12
    static let base: CGFloat = 13
    static let lg: CGFloat = 14
    static let xl: CGFloat = 15
    static let xxl: CGFloat = 16
    static let title: CGFloat = 18
    static let hero: CGFloat = 22
    static let timer: CGFloat = 36
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

struct PageBackground: View {
    var body: some View {
        LinearGradient(
            colors: [GSColor.bgPageTop, GSColor.bgPageBottom],
            startPoint: UnitPoint(x: 0.15, y: 0),
            endPoint: UnitPoint(x: 0.85, y: 1)
        )
        .ignoresSafeArea()
    }
}

struct CardStyle: ViewModifier {
    var radius: CGFloat = GSRadius.card
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(GSColor.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: GSColor.cardShadow, radius: 6, x: 0, y: 4)
    }
}

extension View {
    func gsCard(radius: CGFloat = GSRadius.card, padding: CGFloat = 14) -> some View {
        modifier(CardStyle(radius: radius, padding: padding))
    }
}
