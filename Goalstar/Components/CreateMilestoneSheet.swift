import SwiftUI
import SwiftData

struct CreateMilestoneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var store: AppStore

    let goal: Goal
    var milestone: GoalMilestone? = nil

    @State private var title = ""
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var endDate = Calendar.current.date(
        byAdding: .day,
        value: 7,
        to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()
    @State private var titleError: String?

    private var isEditing: Bool { milestone != nil }
    private var navigationTitle: String { isEditing ? "编辑阶段" : "新建阶段" }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: GSSpacing.lg) {
                    formCard

                    if let titleError {
                        Text(titleError)
                            .font(GSFont.semibold(GSFont.lg))
                            .foregroundStyle(Color.red.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(title: "保存") {
                        save()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, GSSpacing.page)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(PageBackground())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                if let milestone {
                    title = milestone.title
                    let today = Calendar.current.startOfDay(for: Date())
                    startDate = milestone.startDate.map { Calendar.current.startOfDay(for: $0) } ?? today
                    endDate = milestone.endDate.map { Calendar.current.startOfDay(for: $0) }
                        ?? Calendar.current.date(byAdding: .day, value: 7, to: startDate)
                        ?? startDate
                    if endDate < startDate { endDate = startDate }
                }
            }
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                DetailFieldLabel(text: "阶段名称")
                TextField("例如：完成基础语法", text: $title)
                    .textFieldStyle(GSTextFieldStyle())
                    .onChange(of: title) { _, _ in titleError = nil }
            }

            DatePickerFormRow(title: "开始日期", selection: $startDate)
                .onChange(of: startDate) { _, newValue in
                    if endDate < newValue { endDate = newValue }
                }

            DatePickerFormRow(
                title: "结束日期",
                selection: $endDate,
                range: startDate...Date.distantFuture
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .gsCard(radius: GSRadius.panel, padding: 16)
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            titleError = "请输入阶段名称"
            return
        }
        titleError = nil
        if let milestone {
            store.updateMilestone(
                milestone,
                title: trimmed,
                startDate: startDate,
                endDate: endDate,
                context: context
            )
        } else {
            store.addMilestone(
                title: trimmed,
                startDate: startDate,
                endDate: endDate,
                goal: goal,
                context: context
            )
        }
        dismiss()
    }
}
