import SwiftUI

struct AddGoalView: View {
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var difficulty = "medium"
    @State private var tag = "未分類"
    @State private var tags: [TagChoice] = []
    @State private var objectiveId: Int?
    @State private var isLoading = false
    @State private var error: String?

    private let difficulties = [
        ("small", "小（軽め）"),
        ("medium", "中（普通）"),
        ("large", "大（ガッツリ）"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("目標名") {
                    TextField("例：筋トレ / 英語 / 読書", text: $title)
                }

                Section("難易度") {
                    Picker("難易度", selection: $difficulty) {
                        ForEach(difficulties, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("タグ（カテゴリ）") {
                    Picker("タグ", selection: $tag) {
                        ForEach(tags) { t in
                            Text(t.label).tag(t.value)
                        }
                    }
                }

                ObjectiveLinkSection(objectiveId: $objectiveId)

                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("目標を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("登録") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .task {
                tags = (try? await APIService.shared.fetchTags()) ?? []
                if tag == "未分類", let first = tags.first {
                    tag = first.value
                }
            }
        }
    }

    private func save() async {
        isLoading = true
        error = nil
        do {
            _ = try await APIService.shared.addGoal(
                title: title.trimmingCharacters(in: .whitespaces),
                difficulty: difficulty,
                tag: tag,
                objectiveId: objectiveId
            )
            onSaved()
            dismiss()
        } catch {
            self.error = "保存に失敗しました"
        }
        isLoading = false
    }
}
