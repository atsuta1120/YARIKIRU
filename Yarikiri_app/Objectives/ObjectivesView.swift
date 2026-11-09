import SwiftUI
import Observation

@Observable
class ObjectivesViewModel {
    var objectives: [Objective] = []
    var isLoading = true
    var error: String?

    /// 長期目標（期限が近い順、達成済みは後ろ）
    var longObjectives: [Objective] { objectives.filter { $0.level == "long" } }

    /// 長期目標に紐づいていない中期目標
    var unlinkedMidObjectives: [Objective] {
        let longIds = Set(longObjectives.map(\.id))
        return objectives.filter { $0.level == "mid" && !($0.parentId.map(longIds.contains) ?? false) }
    }

    func children(of objective: Objective) -> [Objective] {
        objectives.filter { $0.level == "mid" && $0.parentId == objective.id }
    }

    func load() async {
        isLoading = true
        error = nil
        do {
            objectives = try await APIService.shared.fetchObjectives().objectives
        } catch {
            self.error = "読み込みに失敗しました"
        }
        isLoading = false
    }

    func toggle(_ objective: Objective) async {
        guard let result = try? await APIService.shared.toggleObjective(id: objective.id),
              let idx = objectives.firstIndex(where: { $0.id == objective.id }) else { return }
        objectives[idx].isDone = result.isDone
    }

    func delete(_ objective: Objective) async {
        do {
            try await APIService.shared.deleteObjective(id: objective.id)
            await load()
        } catch {}
    }
}

struct ObjectivesView: View {
    @State private var vm = ObjectivesViewModel()
    @State private var showAdd = false
    @State private var editing: Objective?
    @State private var deleting: Objective?

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.objectives.isEmpty {
                    ProgressView()
                } else if let error = vm.error, vm.objectives.isEmpty {
                    VStack(spacing: 12) {
                        Text(error).foregroundStyle(.secondary)
                        Button("再試行") { Task { await vm.load() } }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if vm.objectives.isEmpty {
                                emptyState
                            }
                            ForEach(vm.longObjectives) { long in
                                VStack(alignment: .leading, spacing: 8) {
                                    ObjectiveCard(objective: long, actions: actions)
                                    ForEach(vm.children(of: long)) { mid in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "arrow.turn.down.right")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .padding(.top, 18)
                                            ObjectiveCard(objective: mid, actions: actions)
                                        }
                                        .padding(.leading, 12)
                                    }
                                }
                            }
                            if !vm.unlinkedMidObjectives.isEmpty {
                                Text("長期目標に紐づいていない中期目標")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                ForEach(vm.unlinkedMidObjectives) { mid in
                                    ObjectiveCard(objective: mid, actions: actions)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("中期・長期の目標")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .sheet(isPresented: $showAdd) {
                ObjectiveFormView(objective: nil, allObjectives: vm.objectives) { Task { await vm.load() } }
            }
            .sheet(item: $editing) { objective in
                ObjectiveFormView(objective: objective, allObjectives: vm.objectives) { Task { await vm.load() } }
            }
            .confirmationDialog(
                "「\(deleting?.title ?? "")」を削除しますか？",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    if let deleting { Task { await vm.delete(deleting) } }
                }
            } message: {
                Text("紐づいている中期目標や日々の目標は消えず、紐づけだけが外れます。")
            }
        }
    }

    private var actions: ObjectiveCard.Actions {
        ObjectiveCard.Actions(
            toggle: { objective in Task { await vm.toggle(objective) } },
            edit: { editing = $0 },
            delete: { deleting = $0 }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("中期・長期の目標はまだありません")
                .foregroundStyle(.secondary)
            Text("期限つきの大きな目標を立てて、日々の目標をそこに紐づけましょう。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("目標を追加") { showAdd = true }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

struct ObjectiveCard: View {
    struct Actions {
        var toggle: (Objective) -> Void
        var edit: (Objective) -> Void
        var delete: (Objective) -> Void
    }

    var objective: Objective
    var actions: Actions

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { actions.toggle(objective) } label: {
                Image(systemName: objective.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(objective.isDone ? .blue : .secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(objective.title)
                    .font(.headline)
                    .strikethrough(objective.isDone)
                    .foregroundStyle(objective.isDone ? .secondary : .primary)
                HStack(spacing: 6) {
                    ObjectiveLevelBadge(level: objective.level)
                    Text(objective.tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
                HStack(spacing: 4) {
                    Text("期限 \(APIDate.display(objective.deadline))")
                    Text("・")
                    Text(objective.deadlineLabel)
                        .bold()
                        .foregroundStyle(deadlineColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if objective.dailyTotal > 0 {
                    Label("日々の目標 \(objective.dailyDone) / \(objective.dailyTotal) 達成", systemImage: "checklist")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ObjectiveStatsSummary(objective: objective)
            }

            Spacer(minLength: 0)

            Menu {
                Button("編集") { actions.edit(objective) }
                Button("削除", role: .destructive) { actions.delete(objective) }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private var deadlineColor: Color {
        if objective.isDone { return .green }
        if objective.daysLeft < 0 { return .red }
        if objective.daysLeft <= 7 { return .orange }
        return .secondary
    }
}

struct ObjectiveLevelBadge: View {
    var level: String

    var body: some View {
        Text(level == "long" ? "長期" : "中期")
            .font(.caption)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background((level == "long" ? Color.purple : Color.teal).opacity(0.15))
            .foregroundStyle(level == "long" ? Color.purple : Color.teal)
            .clipShape(Capsule())
    }
}

/// 自分の目標に付いたリアクション数と閲覧数（0件は非表示。ホームの日々の目標と同じ）
private struct ObjectiveStatsSummary: View {
    var objective: Objective

    var body: some View {
        let items = ["fire", "clap", "muscle"].compactMap { objective.reactionCounts[$0] }.filter { $0.count > 0 }
        if !items.isEmpty || objective.viewCount > 0 {
            HStack(spacing: 12) {
                ForEach(items, id: \.emoji) { info in
                    HStack(spacing: 3) {
                        Text(info.emoji)
                        Text("\(info.count)").foregroundStyle(.secondary)
                    }
                }
                if objective.viewCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "eye")
                        Text("\(objective.viewCount)")
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
    }
}
