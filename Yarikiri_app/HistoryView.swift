import SwiftUI

struct HistoryView: View {
    @State private var history: [HistoryDay] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && history.isEmpty {
                    ProgressView()
                } else if history.isEmpty {
                    Text("過去の記録がありません")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(history) { day in
                            Section {
                                ForEach(day.goals) { goal in
                                    HStack {
                                        Image(systemName: goal.isDone ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(goal.isDone ? .blue : .secondary)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(goal.title)
                                                .strikethrough(goal.isDone)
                                                .foregroundStyle(goal.isDone ? .secondary : .primary)
                                            Text(goal.tag)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(day.dateStr)
                                    Spacer()
                                    Text("\(day.progress)%")
                                        .foregroundStyle(.blue)
                                        .bold()
                                }
                            }
                        }
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("過去の記録")
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        history = (try? await APIService.shared.fetchHistory())?.history ?? []
        isLoading = false
    }
}
