import Foundation

final class APIService {
    static let shared = APIService()

    private let baseURL = "https://yarikiri-app.onrender.com"
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

    func addGoal(title: String, difficulty: String, tag: String) async throws -> Goal {
        let url = URL(string: "\(baseURL)/api/goals/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["title": title, "difficulty": difficulty, "tag": tag]
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(Goal.self, from: data)
    }

    func updateGoal(id: Int, title: String, difficulty: String, tag: String) async throws -> Goal {
        let url = URL(string: "\(baseURL)/api/goals/\(id)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["title": title, "difficulty": difficulty, "tag": tag]
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
}
