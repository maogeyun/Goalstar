import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languages: AppLanguageStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        languages.set(language)
                    } label: {
                        HStack {
                            Text(language.nativeName)
                                .font(GSFont.semibold(GSFont.lg))
                                .foregroundStyle(GSColor.textPrimary)
                            Spacer()
                            if languages.language == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(GSColor.brand)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PageBackground())
            .navigationTitle(L10n.s("语言"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.s("关闭")) { dismiss() }
                }
            }
        }
    }
}
