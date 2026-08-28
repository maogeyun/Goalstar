import SwiftUI

// MARK: - Shimmer bone

struct SkeletonBone: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 8

    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(GSColor.bgTertiary)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : width)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.55),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: max(geo.size.width * 0.45, 48))
                    .offset(x: shimmerOffset * (geo.size.width + geo.size.width * 0.45))
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .onAppear {
                shimmerOffset = -1
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Page skeletons

struct GreetingSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonBone(width: 180, height: 22, cornerRadius: 6)
            SkeletonBone(width: 120, height: 14, cornerRadius: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TodayPageSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GSSpacing.lg) {
            GreetingSkeleton()

            HStack(alignment: .center, spacing: 20) {
                SkeletonBone(width: 72, height: 72, cornerRadius: 36)
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonBone(height: 16, cornerRadius: 6)
                    SkeletonBone(width: 160, height: 16, cornerRadius: 6)
                    HStack(spacing: 8) {
                        SkeletonBone(width: 88, height: 28, cornerRadius: GSRadius.chip)
                        SkeletonBone(width: 88, height: 28, cornerRadius: GSRadius.chip)
                    }
                }
            }
            .gsCard(radius: GSRadius.panel, padding: 16)

            VStack(alignment: .leading, spacing: 12) {
                SkeletonBone(width: 88, height: 16, cornerRadius: 6)
                ForEach(0..<3, id: \.self) { _ in
                    taskRowSkeleton
                }
            }
        }
        .accessibilityLabel("正在刷新今日数据")
    }

    private var taskRowSkeleton: some View {
        HStack(spacing: 12) {
            SkeletonBone(width: 22, height: 22, cornerRadius: 11)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBone(height: 14, cornerRadius: 6)
                SkeletonBone(width: 140, height: 12, cornerRadius: 6)
            }
            Spacer(minLength: 0)
            SkeletonBone(width: 36, height: 36, cornerRadius: GSRadius.play)
        }
        .gsCard(radius: GSRadius.card, padding: 14)
    }
}

struct GoalsPageSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GSSpacing.lg) {
            GreetingSkeleton()

            VStack(alignment: .leading, spacing: 16) {
                SkeletonBone(width: 96, height: 16, cornerRadius: 6)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBone(width: 36, height: 22, cornerRadius: 6)
                            SkeletonBone(width: 48, height: 12, cornerRadius: 6)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(GSColor.bgTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .gsCard(radius: GSRadius.panel, padding: 16)

            VStack(alignment: .leading, spacing: 12) {
                SkeletonBone(width: 112, height: 16, cornerRadius: 6)
                ForEach(0..<2, id: \.self) { _ in
                    goalCardSkeleton
                }
            }
        }
        .accessibilityLabel("正在刷新目标列表")
    }

    private var goalCardSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SkeletonBone(width: 120, height: 16, cornerRadius: 6)
                Spacer()
                SkeletonBone(width: 56, height: 24, cornerRadius: GSRadius.tag)
            }
            SkeletonBone(height: 8, cornerRadius: 4)
            HStack {
                SkeletonBone(width: 72, height: 12, cornerRadius: 6)
                Spacer()
                SkeletonBone(width: 48, height: 12, cornerRadius: 6)
            }
        }
        .gsCard(radius: GSRadius.card, padding: 16)
    }
}

struct DataPageSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GSSpacing.lg) {
            GreetingSkeleton()

            SkeletonBone(height: 38, cornerRadius: 12)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    metricSkeleton
                    metricSkeleton
                }
                HStack(spacing: 10) {
                    metricSkeleton
                    metricSkeleton
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SkeletonBone(width: 88, height: 16, cornerRadius: 6)
                SkeletonBone(height: 14, cornerRadius: 6)
                SkeletonBone(width: 220, height: 14, cornerRadius: 6)
            }
            .gsCard(radius: GSRadius.panel, padding: 16)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SkeletonBone(width: 120, height: 16, cornerRadius: 6)
                    Spacer()
                    SkeletonBone(width: 64, height: 12, cornerRadius: 6)
                }
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<7, id: \.self) { idx in
                        VStack(spacing: 6) {
                            SkeletonBone(width: 20, height: CGFloat(28 + idx * 6), cornerRadius: 4)
                            SkeletonBone(width: 12, height: 10, cornerRadius: 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)
            }
            .gsCard(radius: GSRadius.panel, padding: 16)

            VStack(alignment: .leading, spacing: 12) {
                SkeletonBone(width: 128, height: 16, cornerRadius: 6)
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            SkeletonBone(width: 100, height: 14, cornerRadius: 6)
                            Spacer()
                            SkeletonBone(width: 36, height: 14, cornerRadius: 6)
                        }
                        SkeletonBone(height: 6, cornerRadius: 3)
                    }
                    .gsCard(radius: GSRadius.card, padding: 14)
                }
            }
        }
        .accessibilityLabel("正在刷新数据洞察")
    }

    private var metricSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonBone(width: 28, height: 28, cornerRadius: 14)
            SkeletonBone(width: 56, height: 22, cornerRadius: 6)
            SkeletonBone(width: 72, height: 12, cornerRadius: 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.card, padding: 12)
    }
}

// MARK: - Pull to refresh helper

extension View {
    func skeletonRefreshable(
        isRefreshing: Binding<Bool>,
        action: @escaping () async -> Void
    ) -> some View {
        refreshable {
            isRefreshing.wrappedValue = true
            await action()
            isRefreshing.wrappedValue = false
        }
    }
}
