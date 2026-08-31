import SwiftUI

struct ProPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var restoreMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    headerCard
                    benefitsCard
                    pricingCard
                    actionsCard
                    if let restoreMessage {
                        Text(restoreMessage)
                            .font(GSFont.semibold(GSFont.sm))
                            .foregroundStyle(GSColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    footerNote
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, GSSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(PageBackground())
            .navigationTitle("Goalstar Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Goalstar Pro")
                    .font(GSFont.semibold(GSFont.hero))
                    .foregroundStyle(GSColor.textPrimary)
                CategoryTag(
                    text: store.isPro ? "已开通" : "免费版",
                    color: store.isPro ? GSColor.brand : GSColor.textSecondary,
                    background: store.isPro ? GSColor.brandLight : GSColor.bgTertiary
                )
            }
            Text(headerSubtitle)
                .font(GSFont.semibold(GSFont.md))
                .foregroundStyle(GSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var headerSubtitle: String {
        if store.isPro {
            return "你已解锁 Pro 权益骨架。后续功能上线后将自动可用。"
        }
        #if DEBUG
        return "升级后解锁更多目标管理与数据能力。当前为体验开通（本地 Mock）。"
        #else
        return "升级后解锁更多目标管理与数据能力。App Store 订阅即将上线。"
        #endif
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Pro 权益")
            ForEach(ProFeature.allCases) { feature in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(GSColor.brandLight)
                            .frame(width: 32, height: 32)
                        GSIcon(name: .star, size: 14, color: GSColor.brand)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title)
                            .font(GSFont.semibold(GSFont.lg))
                            .foregroundStyle(GSColor.textPrimary)
                        Text(feature.subtitle)
                            .font(GSFont.semibold(GSFont.sm))
                            .foregroundStyle(GSColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var pricingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "订阅说明")
            #if DEBUG
            Text("即将支持 App Store 订阅 · 现可体验开通")
                .font(GSFont.semibold(GSFont.lg))
                .foregroundStyle(GSColor.textPrimary)
            Text("体验开通仅保存在本机，不会产生真实扣费。正式上线后可在此恢复购买。")
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            #else
            Text("即将支持 App Store 订阅")
                .font(GSFont.semibold(GSFont.lg))
                .foregroundStyle(GSColor.textPrimary)
            Text("正式上线后可在此购买与恢复。当前版本暂不提供本地体验开通。")
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {
            if store.isPro {
                PrimaryButton(title: "已是 Pro 会员", filled: false) {
                    dismiss()
                }
                OutlineActionButton(title: "恢复购买") {
                    let ok = store.restorePurchasesMock()
                    restoreMessage = ok
                        ? "已恢复本地 Pro 状态"
                        : "未找到可恢复的购买"
                }
            } else {
                #if DEBUG
                PrimaryButton(title: "体验开通 Pro") {
                    store.setProMock(true)
                    dismiss()
                }
                #else
                PrimaryButton(title: "即将开放订阅", filled: false) {
                    restoreMessage = "App Store 订阅即将上线，敬请期待"
                }
                #endif
                OutlineActionButton(title: "恢复购买") {
                    let ok = store.restorePurchasesMock()
                    restoreMessage = ok
                        ? "已恢复本地 Pro 状态"
                        : "未找到可恢复的购买"
                }
            }
        }
        .frame(maxWidth: .infinity)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var footerNote: some View {
        Text("付款条款与隐私政策将在接入 App Store 订阅后更新。")
            .font(GSFont.semibold(GSFont.sm))
            .foregroundStyle(GSColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
