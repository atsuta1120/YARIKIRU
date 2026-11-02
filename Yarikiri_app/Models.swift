import Foundation

struct Goal: Codable, Identifiable {
    let id: Int
    var title: String
    var difficulty: String
    var weight: Int
    var isDone: Bool
    var tag: String
    let date: String
    let createdAt: String
    var viewCount: Int
    var reactionCounts: [String: ReactionInfo]
    var isMine: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, difficulty, weight, tag, date
        case isDone = "is_done"
        case createdAt = "created_at"
        case viewCount = "view_count"
        case reactionCounts = "reaction_counts"
        case isMine = "is_mine"
    }
}

struct ReactionInfo: Codable {
    let emoji: String
    var count: Int
    var reacted: Bool
}

struct GoalsResponse: Codable {
    let today: String
    let todayStr: String
    var progressPercent: Int
    var totalWeight: Int
    var doneWeight: Int
    var goals: [Goal]

    enum CodingKeys: String, CodingKey {
        case today, goals
        case todayStr = "today_str"
        case progressPercent = "progress_percent"
        case totalWeight = "total_weight"
        case doneWeight = "done_weight"
    }
}

struct TimelineResponse: Codable {
    let tag: String
    let todayStr: String
    var goals: [Goal]

    enum CodingKeys: String, CodingKey {
        case tag, goals
        case todayStr = "today_str"
    }
}

struct HistoryDay: Codable, Identifiable {
    var id: String { date }
    let date: String
    let dateStr: String
    let progress: Int
    let goals: [Goal]

    enum CodingKeys: String, CodingKey {
        case date, progress, goals
        case dateStr = "date_str"
    }
}

struct HistoryResponse: Codable {
    let history: [HistoryDay]
}

struct TagChoice: Codable, Identifiable {
    var id: String { value }
    let value: String
    let label: String
}

struct TagsResponse: Codable {
    let tags: [TagChoice]
}

struct ToggleResponse: Codable {
    let id: Int
    let isDone: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case isDone = "is_done"
    }
}

struct ReactResponse: Codable {
    let reacted: Bool
    let count: Int
}

struct UserSettings: Codable {
    var resetHour: Int

    enum CodingKeys: String, CodingKey {
        case resetHour = "reset_hour"
    }
}
