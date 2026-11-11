import SwiftUI

enum ProPaywallContext: String, Identifiable {
    case goals
    case regen
    var id: String { rawValue }
}

struct ProPaywallSheet: View {
    var context: ProPaywallContext = .goals

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    @State private var statusMessage: String?
    @State private var showPrivacy = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    headerCard
                    benefitsCard
                    pricingCard
                    actionsCard
                    if let statusMessage {
                        Text(statusMessage)
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
            .navigationTitle(L10n.s("Goalstar Pro"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.s("关闭")) { dismiss() }
                }
            }
            .task {
                await store.refreshProProduct()
            }
            .sheet(isPresented: $showPrivacy) {
                ProfilePrivacySheet()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(L10n.s("Goalstar Pro"))
                    .font(GSFont.semibold(GSFont.hero))
                    .foregroundStyle(GSColor.textPrimary)
                CategoryTag(
                    text: store.isPro ? L10n.s("已开通") : L10n.s("免费版"),
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
        switch context {
        case .goals:
            if store.isPro {
                return L10n.s("你已永久解锁无限进行中目标。")
            }
            return L10n.s("一次买断，永久解锁无限进行中目标。")
        case .regen:
            if store.isPro {
                return L10n.s("你已永久解锁无限再生成草稿。")
            }
            return L10n.s("今日再生成次数已用完。升级 Pro 后可无限再生成草稿。")
        }
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: L10n.s("本次购买包含"))
            ForEach(paywallBenefits) { benefit in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(GSColor.brandLight)
                            .frame(width: 32, height: 32)
                        GSIcon(name: .star, size: 14, color: GSColor.brand)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(benefit.title)
                            .font(GSFont.semibold(GSFont.lg))
                            .foregroundStyle(GSColor.textPrimary)
                        Text(benefit.subtitle)
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

    private var paywallBenefits: [PaywallBenefit] {
        let lead: PaywallBenefit
        switch context {
        case .goals:
            let feature = ProFeature.unlimitedGoals
            lead = PaywallBenefit(id: feature.id, title: feature.title, subtitle: feature.subtitle)
        case .regen:
            lead = PaywallBenefit(
                id: "regen",
                title: L10n.s("无限再生成草稿"),
                subtitle: L10n.s("免费版每天可再生成 3 次。升级后不再按次数限制。")
            )
        }
        return [
            lead,
            PaywallBenefit(id: "lifetime", title: L10n.s("一次买断"), subtitle: L10n.s("永久有效，不会自动续费。")),
            PaywallBenefit(id: "restore", title: L10n.s("换机可恢复"), subtitle: L10n.s("同一 Apple ID 在新设备上点「恢复购买」即可。"))
        ]
    }

    private var pricingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: L10n.s("买断说明"))
            Text(L10n.s("一次购买，终身解锁"))
                .font(GSFont.semibold(GSFont.lg))
                .foregroundStyle(GSColor.textPrimary)
            Text(pricingSubtitle)
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var pricingSubtitle: String {
        if let price = store.proProductPrice {
            return L10n.f("价格 %@，由 Apple 处理付款，不会自动续费。换机后可恢复购买。", price)
        }
        if store.isProProductLoading {
            return L10n.s("正在从 App Store 获取价格…")
        }
        return L10n.s("价格由 App Store 显示。无法获取商品时请检查网络后重试。")
    }

    private var purchaseTitle: String {
        if store.isPro {
            return L10n.s("已是 Pro 会员")
        }
        if store.isProPurchaseInFlight {
            return L10n.s("购买中…")
        }
        if store.isProProductLoading {
            return L10n.s("正在获取价格…")
        }
        if let price = store.proProductPrice {
            return L10n.f("购买终身 Pro · %@", price)
        }
        return L10n.s("暂时无法购买")
    }

    private var canPurchase: Bool {
        !store.isPro && !store.isProPurchaseInFlight && store.proProductPrice != nil
    }

    private var actionsCard: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: purchaseTitle, filled: store.isPro ? false : canPurchase) {
                if store.isPro {
                    dismiss()
                    return
                }
                if store.proProductPrice == nil {
                    Task { await store.refreshProProduct() }
                    return
                }
                Task { await purchase() }
            }
            .disabled(store.isProPurchaseInFlight)
            .opacity(store.isPro || canPurchase || store.isProPurchaseInFlight || store.proProductPrice == nil ? 1 : 0.55)

            OutlineActionButton(title: store.isProPurchaseInFlight ? L10n.s("处理中…") : L10n.s("恢复购买")) {
                Task { await restore() }
            }
            .disabled(store.isProPurchaseInFlight)
        }
        .frame(maxWidth: .infinity)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.s("一次买断，不会自动续费。购买由 Apple 处理，本 App 不收集支付信息。"))
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(L10n.s("查看隐私政策")) {
                showPrivacy = true
            }
            .font(GSFont.semibold(GSFont.sm))
            .foregroundStyle(GSColor.brand)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func purchase() async {
        statusMessage = nil
        let outcome = await store.purchasePro()
        switch outcome {
        case .success:
            dismiss()
        case .cancelled:
            break
        case .pending:
            statusMessage = L10n.s("购买待确认，请完成批准后点「恢复购买」。")
        case .notFound:
            statusMessage = L10n.s("未找到可恢复的购买")
        case .failed(let message):
            statusMessage = message
        }
    }

    private func restore() async {
        statusMessage = nil
        let outcome = await store.restorePurchases()
        switch outcome {
        case .success:
            statusMessage = L10n.s("已恢复 Pro")
        case .cancelled:
            break
        case .pending:
            statusMessage = L10n.s("购买待确认，请稍后再试。")
        case .notFound:
            statusMessage = L10n.s("未找到可恢复的购买")
        case .failed(let message):
            statusMessage = message
        }
    }
}

private struct PaywallBenefit: Identifiable {
    let id: String
    let title: String
    let subtitle: String
}
