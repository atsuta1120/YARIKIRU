import SwiftUI

/// 中期・長期の目標の追加・編集フォーム。objective が nil なら追加
struct ObjectiveFormView: View {
    var objective: Objective?
    /// 親（長期目標）の候補を出すための一覧
    var allObjectives: [Objective]
    var onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var level: String
    @State private var deadline: Date
    @State private var tag: String
    @State private var parentId: Int?
    @State private var tags: [TagChoice] = []
    @State private var isLoading = false
    @State private var error: String?

    init(objective: Objective?, allObjectives: [Objective], onSaved: @escaping () -> Void) {
        self.objective = objective
        self.allObjectives = allObjectives
        self.onSaved = onSaved
        let defaultDeadline = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
        _title = State(initialValue: objective?.title ?? "")
        _level = State(initialValue: objective?.level ?? "long")
        _deadline = State(initialValue: objective.flatMap { APIDate.date(from: $0.deadline) } ?? defaultDeadline)
        _tag = State(initialValue: objective?.tag ?? "未分類")
        _parentId = State(initialValue: objective?.parentId)
    }

    private var isNew: Bool { objective == nil }

    /// 中期目標の親にできる長期目標（自分自身は除く）
    private var parentCandidates: [Objective] {
        allObjectives.filter { $0.level == "long" && $0.id != objective?.id && (!$0.isDone || $0.id == parentId) }
    }

    /// 中期目標がぶら下がっている長期目標は、中期に変更できない
    private var hasChildren: Bool {
        guard let objective else { return false }
        return allObjectives.contains { $0.parentId == objective.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("目標名") {
                    TextField("例：TOEIC 800点 / 10kg減量", text: $title)
                }

                Section {
                    Picker("種類", selection: $level) {
                        Text("長期").tag("long")
                        Text("中期").tag("mid")
                    }
                    .pickerStyle(.segmented)
                    .disabled(hasChildren)
                } header: {
                    Text("種類")
                } footer: {
                    Text(hasChildren
                         ? "中期目標が紐づいているため、長期のままにしてください。"
                         : "長期目標の下に中期目標、中期目標の下に日々の目標を紐づけられます。")
                }

                Section("期限") {
                    if isNew {
                        DatePicker("期限日", selection: $deadline, in: Date.now..., displayedComponents: .date)
                    } else {
                        DatePicker("期限日", selection: $deadline, displayedComponents: .date)
                    }
                }

                if level == "mid" {
                    Section {
                        Picker("長期目標", selection: $parentId) {
                            Text("なし").tag(Int?.none)
                            ForEach(parentCandidates) { long in
                                Text(long.title).tag(Int?.some(long.id))
                            }
                        }
                    } header: {
                        Text("つながる長期目標")
                    } footer: {
                        if parentCandidates.isEmpty {
                            Text("先に長期目標を作ると、ここで選べるようになります。")
                        }
                    }
                }

                Section("タグ（カテゴリ）") {
                    Picker("タグ", selection: $tag) {
                        ForEach(tags) { t in
                            Text(t.label).tag(t.value)
                        }
                    }
                }

                Section {
                    Text("この目標はタイムラインで同じタグの人に公開されます（期限日まで）。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isNew ? "中期・長期の目標を追加" : "目標を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "登録" : "保存") { Task { await save() } }
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
        let body = ObjectiveBody(
            title: title.trimmingCharacters(in: .whitespaces),
            level: level,
            deadline: APIDate.string(from: deadline),
            tag: tag,
            parentId: level == "mid" ? parentId : nil
        )
        do {
            if let objective {
                _ = try await APIService.shared.updateObjective(id: objective.id, body)
            } else {
                _ = try await APIService.shared.addObjective(body)
            }
            onSaved()
            dismiss()
        } catch {
            self.error = (error as? APIError)?.message ?? "保存に失敗しました"
        }
        isLoading = false
    }
}

/// 日々の目標の追加・編集で使う「つながる中期・長期の目標」の選択欄
struct ObjectiveLinkSection: View {
    @Binding var objectiveId: Int?
    @State private var objectives: [Objective] = []

    /// 未達成のもの＋いま選んでいるもの。中期を先に出す
    private var candidates: [Objective] {
        objectives
            .filter { !$0.isDone || $0.id == objectiveId }
            .sorted { ($0.level == "mid" ? 0 : 1) < ($1.level == "mid" ? 0 : 1) }
    }

    var body: some View {
        Section {
            Picker("紐づける目標", selection: $objectiveId) {
                Text("なし").tag(Int?.none)
                ForEach(candidates) { objective in
                    Text("【\(objective.levelLabel)】\(objective.title)").tag(Int?.some(objective.id))
                }
            }
        } header: {
            Text("つながる中期・長期の目標")
        } footer: {
            if objectives.isEmpty {
                Text("「目標」タブで中期・長期の目標を作ると、ここで選べます。")
            }
        }
        .task {
            objectives = (try? await APIService.shared.fetchObjectives().objectives) ?? []
        }
    }
}
