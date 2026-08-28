import SwiftUI

/// Branded splash matching Figma node `91:17` (`splash-screen-v2`).
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var iconRevealed = false
    @State private var titleRevealed = false
    @State private var subtitleRevealed = false
    @State private var iconShadowRadius: CGFloat = 0

    private static let iconSpring = Animation.spring(response: 0.58, dampingFraction: 0.68, blendDuration: 0)
    private static let titleSpring = Animation.spring(response: 0.52, dampingFraction: 0.82, blendDuration: 0)
    private static let subtitleEase = Animation.easeOut(duration: 0.4)

    var body: some View {
        ZStack {
            PageBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                brandingColumn
                Spacer(minLength: 0)
            }
        }
        .preferredColorScheme(.light)
        .onAppear { runEntrance() }
    }

    private var brandingColumn: some View {
        VStack(spacing: 24) {
            Image("SplashAppIcon")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: 120, height: 120)
                .scaleEffect(iconRevealed ? 1 : 0.55)
                .opacity(iconRevealed ? 1 : 0)
                .offset(y: iconRevealed ? 0 : 28)
                .shadow(
                    color: GSColor.brand.opacity(0.22),
                    radius: iconShadowRadius,
                    x: 0,
                    y: iconShadowRadius * 0.35
                )
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("GOALSTAR")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(GSColor.textPrimary)
                    .tracking(1.2)
                    .lineSpacing(0)
                    .frame(height: 35)
                    .opacity(titleRevealed ? 1 : 0)
                    .offset(y: titleRevealed ? 0 : 14)

                Text("目标星图")
                    .font(GSFont.medium(12))
                    .foregroundStyle(Color(hex: 0x9AA5B6))
                    .frame(height: 18)
                    .opacity(subtitleRevealed ? 1 : 0)
                    .offset(y: subtitleRevealed ? 0 : 10)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
    }

    private func runEntrance() {
        iconRevealed = false
        titleRevealed = false
        subtitleRevealed = false
        iconShadowRadius = 0

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) {
                iconRevealed = true
                titleRevealed = true
                subtitleRevealed = true
            }
            return
        }

        withAnimation(Self.iconSpring) {
            iconRevealed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.35)) {
                iconShadowRadius = 12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.25)) {
                    iconShadowRadius = 8
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(Self.titleSpring) {
                titleRevealed = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(Self.subtitleEase) {
                subtitleRevealed = true
            }
        }
    }
}

#Preview {
    SplashView()
}
