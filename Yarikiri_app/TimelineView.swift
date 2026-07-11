import SwiftUI
import Observation

@Observable
class TimelineViewModel {
    var response: TimelineResponse?
    var isLoading = false
    var selectedTag = "学習"
    var tags: [TagChoice] = []

    func loadTags() async {
        tags = (try? await APIService.shared.fetchTags()) ?? []
    }

    func load() async {
        isLoading = true
        response = try? await APIService.shared.fetchTimeline(tag: selectedTag)
        isLoading = false
    }

    func react(goal: Goal, reactionType: String) async {
        guard let result = try? await APIService.shared.reactGoal(id: goal.id, reactionType: reactionType) else { return }
        if let gi = response?.goals.firstIndex(where: { $0.id == goal.id }) {
            response?.goals[gi].reactionCounts[reactionType]?.count = result.count
            response?.goals[gi].reactionCounts[reactionType]?.reacted = result.reacted
        }
    }
}

struct TimelineView: View {
    @State private var vm = TimelineViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tagPicker
                Divider()

                if vm.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if let goals = vm.response?.goals, !goals.isEmpty {
                                ForEach(goals) { goal in
                                    timelineCard(goal: goal)
                                }
                            } else {
                                Text("今日このタグの目標はまだありません")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 60)
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
        }
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
                ForEach(["fire", "clap", "muscle"], id: \.self) { rtype in
                    if let info = goal.reactionCounts[rtype] {
                        Button {
                            Task { await vm.react(goal: goal, reactionType: rtype) }
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
}
