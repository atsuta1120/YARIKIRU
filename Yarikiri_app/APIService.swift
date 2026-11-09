import Foundation

final class APIService {
    static let shared = APIService()

    private let baseURL: String = {
        #if DEBUG
        // シミュレータでローカルのサーバーを試すときだけ使う（例: https://127.0.0.1:8443）
        if let override = ProcessInfo.processInfo.environment["YARIKIRI_API_BASE"], !override.isEmpty {
            return override
        }
        #endif
        return "https://yarikiri-app.onrender.com"
    }()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        config.httpCookieStorage = HTTPCookieStorage.shared
        session = URLSession(configuration: config)
    }

    // MARK: - Goals

    func fetchGoals() async throws -> GoalsResponse {
        let url = URL(string: "\(baseURL)/api/goals/")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(GoalsResponse.self, from: data)
    }

    func addGoal(title: String, difficulty: String, tag: String, objectiveId: Int?) async throws -> Goal {
        let url = URL(string: "\(baseURL)/api/goals/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = GoalBody(title: title, difficulty: difficulty, tag: tag, objectiveId: objectiveId)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(Goal.self, from: data)
    }

    func updateGoal(id: Int, title: String, difficulty: String, tag: String, objectiveId: Int?) async throws -> Goal {
        let url = URL(string: "\(baseURL)/api/goals/\(id)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = GoalBody(title: title, difficulty: difficulty, tag: tag, objectiveId: objectiveId)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(Goal.self, from: data)
    }

    func deleteGoal(id: Int) async throws {
        let url = URL(string: "\(baseURL)/api/goals/\(id)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await session.data(for: request)
    }

    func toggleGoal(id: Int) async throws -> ToggleResponse {
        let url = URL(string: "\(baseURL)/api/goals/\(id)/toggle/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(ToggleResponse.self, from: data)
    }

    // MARK: - Timeline

    func fetchTimeline(tag: String) async throws -> TimelineResponse {
        let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
        let url = URL(string: "\(baseURL)/api/timeline/\(encoded)/")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(TimelineResponse.self, from: data)
    }

    func fetchTimelineObjectives(tag: String) async throws -> TimelineObjectivesResponse {
        let encoded = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? tag
        let url = URL(string: "\(baseURL)/api/timeline/\(encoded)/objectives/")!
        let (data, response) = try await session.data(from: url)
        return try decode(TimelineObjectivesResponse.self, data: data, response: response)
    }

    // MARK: - Reactions

    func reactGoal(id: Int, reactionType: String) async throws -> ReactResponse {
        let url = URL(string: "\(baseURL)/api/react/\(id)/\(reactionType)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(ReactResponse.self, from: data)
    }

    // MARK: - History

    func fetchHistory() async throws -> HistoryResponse {
        let url = URL(string: "\(baseURL)/api/history/")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(HistoryResponse.self, from: data)
    }

    // MARK: - Tags

    func fetchTags() async throws -> [TagChoice] {
        let url = URL(string: "\(baseURL)/api/tags/")!
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TagsResponse.self, from: data)
        return response.tags
    }

    // MARK: - Settings

    func fetchSettings() async throws -> UserSettings {
        let url = URL(string: "\(baseURL)/api/settings/")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(UserSettings.self, from: data)
    }

    func updateSettings(_ settings: UserSettings) async throws -> UserSettings {
        let url = URL(string: "\(baseURL)/api/settings/")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(settings)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(UserSettings.self, from: data)
    }

    // MARK: - Objectives（中期・長期の目標）

    func fetchObjectives() async throws -> ObjectivesResponse {
        let url = URL(string: "\(baseURL)/api/objectives/")!
        let (data, response) = try await session.data(from: url)
        return try decode(ObjectivesResponse.self, data: data, response: response)
    }

    func addObjective(_ body: ObjectiveBody) async throws -> Objective {
        try await sendObjective(body, url: URL(string: "\(baseURL)/api/objectives/")!, method: "POST")
    }

    func updateObjective(id: Int, _ body: ObjectiveBody) async throws -> Objective {
        try await sendObjective(body, url: URL(string: "\(baseURL)/api/objectives/\(id)/")!, method: "PUT")
    }

    func deleteObjective(id: Int) async throws {
        let url = URL(string: "\(baseURL)/api/objectives/\(id)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await session.data(for: request)
    }

    func toggleObjective(id: Int) async throws -> ToggleResponse {
        let url = URL(string: "\(baseURL)/api/objectives/\(id)/toggle/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        return try decode(ToggleResponse.self, data: data, response: response)
    }

    func reactObjective(id: Int, reactionType: String) async throws -> ReactResponse {
        let url = URL(string: "\(baseURL)/api/objectives/\(id)/react/\(reactionType)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        return try decode(ReactResponse.self, data: data, response: response)
    }

    private func sendObjective(_ body: ObjectiveBody, url: URL, method: String) async throws -> Objective {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        return try decode(Objective.self, data: data, response: response)
    }

    /// 4xx/5xx のときはサーバーの {"error": "..."} を APIError として投げる
    private func decode<T: Decodable>(_ type: T.Type, data: Data, response: URLResponse) throws -> T {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw APIError(message: message ?? "通信に失敗しました")
        }
        return try JSONDecoder().decode(type, from: data)
    }
}

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// 日々の目標の追加・編集。objective_id は紐づけなしのとき null を明示して送る
struct GoalBody: Encodable {
    let title: String
    let difficulty: String
    let tag: String
    let objectiveId: Int?

    enum CodingKeys: String, CodingKey {
        case title, difficulty, tag
        case objectiveId = "objective_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(title, forKey: .title)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(tag, forKey: .tag)
        try c.encode(objectiveId, forKey: .objectiveId)
    }
}

struct ObjectiveBody: Encodable {
    let title: String
    let level: String
    let deadline: String
    let tag: String
    let parentId: Int?

    enum CodingKeys: String, CodingKey {
        case title, level, deadline, tag
        case parentId = "parent_id"
    }
}
