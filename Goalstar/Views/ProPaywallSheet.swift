import SwiftUI

struct ProPaywallSheet: View {
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
            .navigationTitle("Goalstar Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
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
            return "你已永久解锁 Pro。后续能力上线后将自动可用。"
        }
        return "一次买断，永久解锁无限进行中目标与后续 Pro 能力。"
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
            SectionHeader(title: "买断说明")
            Text("一次购买，终身解锁")
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
            return "价格 \(price)，由 Apple 处理付款，不会自动续费。换机后可恢复购买。"
        }
        if store.isProProductLoading {
            return "正在从 App Store 获取价格…"
        }
        return "价格由 App Store 显示。无法获取商品时请检查网络后重试。"
    }

    private var purchaseTitle: String {
        if store.isPro {
            return "已是 Pro 会员"
        }
        if store.isProPurchaseInFlight {
            return "购买中…"
        }
        if store.isProProductLoading {
            return "正在获取价格…"
        }
        if let price = store.proProductPrice {
            return "购买终身 Pro · \(price)"
        }
        return "暂时无法购买"
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

            OutlineActionButton(title: store.isProPurchaseInFlight ? "处理中…" : "恢复购买") {
                Task { await restore() }
            }
            .disabled(store.isProPurchaseInFlight)
        }
        .frame(maxWidth: .infinity)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private var footerNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("一次买断，不会自动续费。购买由 Apple 处理，本 App 不收集支付信息。")
                .font(GSFont.semibold(GSFont.sm))
                .foregroundStyle(GSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("查看隐私政策") {
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
            statusMessage = "购买待确认，请完成批准后点「恢复购买」。"
        case .notFound:
            statusMessage = "未找到可恢复的购买"
        case .failed(let message):
            statusMessage = message
        }
    }

    private func restore() async {
        statusMessage = nil
        let outcome = await store.restorePurchases()
        switch outcome {
        case .success:
            statusMessage = "已恢复 Pro"
        case .cancelled:
            break
        case .pending:
            statusMessage = "购买待确认，请稍后再试。"
        case .notFound:
            statusMessage = "未找到可恢复的购买"
        case .failed(let message):
            statusMessage = message
        }
    }
}
