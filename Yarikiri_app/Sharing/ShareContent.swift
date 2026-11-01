import Foundation

struct ShareGoalItem: Identifiable {
    let id: Int
    let title: String
    let isDone: Bool
}

struct ShareCardData: Identifiable {
    enum Pattern: Equatable {
        case declaration
        case achievement
    }

    private static let maxDisplayedGoals = 5

    let id = UUID()
    let pattern: Pattern
    let dateStr: String
    let displayedGoals: [ShareGoalItem]
    let remainingCount: Int
    let progressPercent: Int
    let doneCount: Int
    let totalCount: Int
    let streakDays: Int

    static func declaration(from response: GoalsResponse) -> ShareCardData? {
        make(from: response, pattern: .declaration, streakDays: 0)
    }

    static func achievement(from response: GoalsResponse, streakDays: Int) -> ShareCardData? {
        make(from: response, pattern: .achievement, streakDays: streakDays)
    }

    private static func make(from response: GoalsResponse, pattern: Pattern, streakDays: Int) -> ShareCardData? {
        guard !response.goals.isEmpty else { return nil }
        let items = response.goals.map { ShareGoalItem(id: $0.id, title: $0.title, isDone: $0.isDone) }
        let displayed = Array(items.prefix(maxDisplayedGoals))
        return ShareCardData(
            pattern: pattern,
            dateStr: response.todayStr,
            displayedGoals: displayed,
            remainingCount: max(0, items.count - displayed.count),
            progressPercent: response.progressPercent,
            doneCount: response.goals.filter(\.isDone).count,
            totalCount: response.goals.count,
            streakDays: streakDays
        )
    }

    var shareText: String {
        switch pattern {
        case .declaration:
            return "今日はこれをやりきる\n\n\(ShareConfig.hashtag)\n\(ShareConfig.appStoreURL.absoluteString)"
        case .achievement:
            return "今日の達成率：\(progressPercent)%\n\n\(ShareConfig.hashtag)\n\(ShareConfig.appStoreURL.absoluteString)"
        }
    }
}
