import SwiftUI

struct EditGoalView: View {
    var goal: Goal
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var difficulty: String
    @State private var tag: String
    @State private var tags: [TagChoice] = []
    @State private var objectiveId: Int?
    @State private var isLoading = false
    @State private var error: String?

    private let difficulties = [
        ("small", "小（軽め）"),
        ("medium", "中（普通）"),
        ("large", "大（ガッツリ）"),
    ]

    init(goal: Goal, onSaved: @escaping () -> Void) {
        self.goal = goal
        self.onSaved = onSaved
        _title = State(initialValue: goal.title)
        _difficulty = State(initialValue: goal.difficulty)
        _tag = State(initialValue: goal.tag)
        _objectiveId = State(initialValue: goal.objectiveId)
    }

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
            .navigationTitle("目標を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .task {
                tags = (try? await APIService.shared.fetchTags()) ?? []
            }
        }
    }

    private func save() async {
        isLoading = true
        error = nil
        do {
            _ = try await APIService.shared.updateGoal(
                id: goal.id,
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
