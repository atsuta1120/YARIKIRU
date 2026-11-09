import SwiftUI
import Observation

/// タイムラインで表示する目標の種類
enum TimelineMode: String, CaseIterable, Identifiable {
    case daily = "今日の目標"
    case objectives = "中期・長期"

    var id: String { rawValue }
}

@Observable
class TimelineViewModel {
    var response: TimelineResponse?
    var objectives: [Objective]?
    var isLoading = false
    var selectedTag = "学習"
    var mode: TimelineMode = .daily
    var tags: [TagChoice] = []

    func loadTags() async {
        tags = (try? await APIService.shared.fetchTags()) ?? []
    }

    /// いま表示している種類だけ読み込む（閲覧数は開いた画面の目標にだけ付く）
    func load() async {
        isLoading = true
        switch mode {
        case .daily:
            response = try? await APIService.shared.fetchTimeline(tag: selectedTag)
        case .objectives:
            objectives = (try? await APIService.shared.fetchTimelineObjectives(tag: selectedTag))?.objectives
        }
        isLoading = false
    }

    func react(goal: Goal, reactionType: String) async {
        guard let result = try? await APIService.shared.reactGoal(id: goal.id, reactionType: reactionType) else { return }
        if let gi = response?.goals.firstIndex(where: { $0.id == goal.id }) {
            response?.goals[gi].reactionCounts[reactionType]?.count = result.count
            response?.goals[gi].reactionCounts[reactionType]?.reacted = result.reacted
        }
    }

    func react(objective: Objective, reactionType: String) async {
        guard let result = try? await APIService.shared.reactObjective(id: objective.id, reactionType: reactionType) else { return }
        if let oi = objectives?.firstIndex(where: { $0.id == objective.id }) {
            objectives?[oi].reactionCounts[reactionType]?.count = result.count
            objectives?[oi].reactionCounts[reactionType]?.reacted = result.reacted
        }
    }
}

struct TimelineView: View {
    @State private var vm = TimelineViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tagPicker
                Picker("表示する目標", selection: $vm.mode) {
                    ForEach(TimelineMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 10)
                Divider()

                if vm.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            switch vm.mode {
                            case .daily:
                                if let goals = vm.response?.goals, !goals.isEmpty {
                                    ForEach(goals) { goal in
                                        timelineCard(goal: goal)
                                    }
                                } else {
                                    emptyText("今日このタグの目標はまだありません")
                                }
                            case .objectives:
                                if let objectives = vm.objectives, !objectives.isEmpty {
                                    ForEach(objectives) { objective in
                                        objectiveCard(objective: objective)
                                    }
                                } else {
                                    emptyText("このタグの中期・長期の目標はまだありません")
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable { await vm.load() }
                }
            }
            .navigationTitle("タイムライン")
            .task {
                await vm.loadTags()
                await vm.load()
            }
            .onChange(of: vm.selectedTag) {
                Task { await vm.load() }
            }
            .onChange(of: vm.mode) {
                Task { await vm.load() }
            }
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .padding(.top, 60)
    }

    private var tagPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.tags) { tag in
                    Button(tag.label) {
                        vm.selectedTag = tag.value
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(vm.selectedTag == tag.value ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(vm.selectedTag == tag.value ? .white : .primary)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func timelineCard(goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .strikethrough(goal.isDone)
                        .foregroundStyle(goal.isDone ? .secondary : .primary)
                    HStack {
                        Text(goal.tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        if goal.isDone {
                            Text("✓ 達成")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
                Spacer()
                if goal.isMine == true {
                    Text("自分")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                reactionButtons(goal.reactionCounts) { rtype in
                    await vm.react(goal: goal, reactionType: rtype)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.caption)
                    Text("\(goal.viewCount)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    @ViewBuilder
    private func reactionButtons(_ counts: [String: ReactionInfo], react: @escaping (String) async -> Void) -> some View {
        ForEach(["fire", "clap", "muscle"], id: \.self) { rtype in
            if let info = counts[rtype] {
                Button {
                    Task { await react(rtype) }
                } label: {
                    HStack(spacing: 4) {
                        Text(info.emoji)
                        Text("\(info.count)")
                            .font(.caption)
                            .foregroundStyle(info.reacted ? .blue : .secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(info.reacted ? Color.blue.opacity(0.15) : Color(.systemGray6))
                .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private func objectiveCard(objective: Objective) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(objective.title)
                        .font(.headline)
                        .strikethrough(objective.isDone)
                        .foregroundStyle(objective.isDone ? .secondary : .primary)
                    HStack(spacing: 6) {
                        ObjectiveLevelBadge(level: objective.level)
                        Text("期限 \(APIDate.display(objective.deadline))・\(objective.deadlineLabel)")
                            .font(.caption)
                            .foregroundStyle(objective.isDone ? .green : .secondary)
                    }
                    if objective.dailyTotal > 0 {
                        Text("日々の目標 \(objective.dailyDone) / \(objective.dailyTotal) 達成")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if objective.isMine {
                    Text("自分")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 16) {
                reactionButtons(objective.reactionCounts) { rtype in
                    await vm.react(objective: objective, reactionType: rtype)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.caption)
                    Text("\(objective.viewCount)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.25)))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}
