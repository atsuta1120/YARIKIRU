import SwiftUI
import Observation

@Observable
class HomeViewModel {
    var response: GoalsResponse?
    var isLoading = true
    var error: String?
    /// 昨日までの連続100%達成日数。履歴の取得に失敗した場合はnil
    private var pastStreakDays: Int?

    /// 今日を含めた連続100%達成日数。今日が未達でも、昨日までの連続は途切れていない扱い
    var streakDays: Int? {
        guard let pastStreakDays, let response else { return nil }
        let isTodayAchieved = !response.goals.isEmpty && response.progressPercent >= 100
        return pastStreakDays + (isTodayAchieved ? 1 : 0)
    }

    func load() async {
        isLoading = true
        error = nil
        async let history = try? APIService.shared.fetchHistory()
        do {
            response = try await APIService.shared.fetchGoals()
        } catch {
            self.error = "読み込みに失敗しました"
            print("HomeViewModel error:", error)
        }
        if let response, let history = await history {
            pastStreakDays = Self.countPastStreak(today: response.today, history: history.history)
        } else {
            pastStreakDays = nil
        }
        isLoading = false
    }

    /// 昨日から遡って、達成率100%の日が何日続いているかを数える。目標を立てなかった日で途切れる
    private static func countPastStreak(today: String, history: [HistoryDay]) -> Int {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        guard var date = formatter.date(from: today) else { return 0 }
        let progressByDate = Dictionary(history.map { ($0.date, $0.progress) }, uniquingKeysWith: { first, _ in first })
        var streak = 0
        while let previous = calendar.date(byAdding: .day, value: -1, to: date),
              let progress = progressByDate[formatter.string(from: previous)],
              progress >= 100 {
            streak += 1
            date = previous
        }
        return streak
    }

    func toggle(goal: Goal) async {
        do {
            let result = try await APIService.shared.toggleGoal(id: goal.id)
            if let idx = response?.goals.firstIndex(where: { $0.id == goal.id }) {
                response?.goals[idx].isDone = result.isDone
                recalculateProgress()
            }
        } catch {}
    }

    private func recalculateProgress() {
        guard let goals = response?.goals else { return }
        let total = goals.reduce(0) { $0 + $1.weight }
        let done = goals.filter(\.isDone).reduce(0) { $0 + $1.weight }
        response?.totalWeight = total
        response?.doneWeight = done
        response?.progressPercent = total == 0 ? 0 : Int(Double(done) / Double(total) * 100)
    }

    func delete(goal: Goal) async {
        do {
            try await APIService.shared.deleteGoal(id: goal.id)
            response?.goals.removeAll { $0.id == goal.id }
        } catch {}
    }
}

struct HomeView: View {
    @State private var vm = HomeViewModel()
    @State private var showAddGoal = false
    @State private var editingGoal: Goal?
    @State private var shareCardData: ShareCardData?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.response == nil {
                    ProgressView()
                } else if let res = vm.response {
                    ScrollView {
                        VStack(spacing: 16) {
                            progressCard(res: res)
                            if !res.goals.isEmpty {
                                HStack {
                                    Spacer()
                                    Button {
                                        shareCardData = ShareCardData.declaration(from: res)
                                    } label: {
                                        Label("宣言をシェア", systemImage: "square.and.arrow.up")
                                            .font(.subheadline)
                                    }
                                }
                            }
                            ForEach(res.goals) { goal in
                                goalCard(goal: goal)
                            }
                            if res.goals.isEmpty {
                                Text("今日の目標をまだ立てていません")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 40)
                            }
                        }
                        .padding()
                    }
                } else if let error = vm.error {
                    VStack(spacing: 12) {
                        Text(error).foregroundStyle(.secondary)
                        Button("再試行") { Task { await vm.load() } }
                    }
                }
            }
            .navigationTitle("やりきること")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddGoal = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await vm.load() }
            .refreshable { await vm.load() }
            .sheet(isPresented: $showAddGoal) {
                AddGoalView { Task { await vm.load() } }
            }
            .sheet(item: $editingGoal) { goal in
                EditGoalView(goal: goal) { Task { await vm.load() } }
            }
            .sheet(item: $shareCardData) { data in
                SharePreviewView(data: data)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView { Task { await vm.load() } }
            }
        }
    }

    @ViewBuilder
    private func progressCard(res: GoalsResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(res.todayStr)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(res.progressPercent), total: 100)
                .tint(.blue)
            HStack {
                Text("\(res.progressPercent)% 達成")
                    .font(.headline)
                    .bold()
                Spacer()
                Text("難易度が高い程進捗への貢献が大きくなります")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let streakDays = vm.streakDays, streakDays > 0 {
                Label("\(streakDays)日連続で100%達成中", systemImage: "flame.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.orange)
            }
            if !res.goals.isEmpty {
                Button {
                    shareCardData = ShareCardData.achievement(from: res, streakDays: vm.streakDays ?? 0)
                } label: {
                    Label("達成結果をシェア", systemImage: "square.and.arrow.up")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    @ViewBuilder
    private func goalCard(goal: Goal) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    Task { await vm.toggle(goal: goal) }
                } label: {
                    Image(systemName: goal.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(goal.isDone ? .blue : .secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
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
                        Text(difficultyLabel(goal.difficulty))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Menu {
                    Button("編集") { editingGoal = goal }
                    Button("削除", role: .destructive) {
                        Task { await vm.delete(goal: goal) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                ForEach(["fire", "clap", "muscle"], id: \.self) { rtype in
                    if let info = goal.reactionCounts[rtype], info.count > 0 {
                        HStack(spacing: 3) {
                            Text(info.emoji)
                                .font(.caption)
                            Text("\(info.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                if goal.viewCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "eye")
                            .font(.caption)
                        Text("\(goal.viewCount)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    private func difficultyLabel(_ d: String) -> String {
        switch d {
        case "small": return "難易度：小"
        case "medium": return "難易度：中"
        case "large": return "難易度：大"
        default: return ""
        }
    }
}
