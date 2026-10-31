
import Foundation

public enum GitHubAPIError: Error, LocalizedError {

    case invalidUsername
    case userNotFound
    case rateLimitExceeded
    case invalidResponse
    case requestFailed(statusCode: Int)
    case networkError

    public var errorDescription: String? {
        switch self {
        case .invalidUsername:
            return "Please enter a valid GitHub username."
        case .userNotFound:
            return "We couldn't find that GitHub user."
        case .rateLimitExceeded:
            return "GitHub's API rate limit has been reached."
        case .invalidResponse:
            return "The server returned invalid data."
        case .requestFailed(let statusCode):
            return "Request failed with status code \(statusCode)."
        case .networkError:
            return "Check your internet connection and try again."
        }
    }
}

public struct GitHubAPIClient {

    public init() {}

    // MARK: - Fetch User

    public func fetchUser(username: String) async throws -> GitHubUser {
        let username = try validateUsername(username)

        let data = try await getData(
            path: "users/\(username)"
        )

        return try await Self.decode(
            GitHubUser.self,
            from: data
        )
    }

    // MARK: - Fetch Followers

    public func fetchFollowers(
        username: String,
        page: Int = 1,
        perPage: Int = 30
    ) async throws -> [GitHubUser] {

        guard page > 0, (1...100).contains(perPage) else {
            throw GitHubAPIError.invalidResponse
        }

        let username = try validateUsername(username)

        let data = try await getData(
            path: "users/\(username)/followers",
            queryItems: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "per_page", value: "\(perPage)")
            ]
        )

        return try await Self.decode(
            [GitHubUser].self,
            from: data
        )
    }

    // MARK: - Fetch Repositories

    public func fetchRepositories(
        username: String,
        page: Int = 1,
        perPage: Int = 30
    ) async throws -> [GitHubRepository] {

        guard page > 0, (1...100).contains(perPage) else {
            throw GitHubAPIError.invalidResponse
        }

        let username = try validateUsername(username)

        let data = try await getData(
            path: "users/\(username)/repos",
            queryItems: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "per_page", value: "\(perPage)"),
                URLQueryItem(name: "sort", value: "updated")
            ]
        )

        return try await Self.decode(
            [GitHubRepository].self,
            from: data
        )
    }

    // MARK: - Concurrent JSON Decoding

    @concurrent
    private static func decode<T: Decodable & Sendable>(
        _ type: T.Type,
        from data: Data
    ) async throws -> T {

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw GitHubAPIError.invalidResponse
        }
    }

    // MARK: - Validate Username

    private func validateUsername(_ username: String) throws -> String {
        let username = username.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let allowedCharacters = CharacterSet(
            charactersIn:
                "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-"
        )

        guard
            !username.isEmpty,
            username.count <= 39,
            username.rangeOfCharacter(
                from: allowedCharacters.inverted
            ) == nil,
            !username.hasPrefix("-"),
            !username.hasSuffix("-"),
            !username.contains("--")
        else {
            throw GitHubAPIError.invalidUsername
        }

        return username
    }

    // MARK: - Send API Request

    private func getData(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Data {

        var components = URLComponents(
            string: "https://api.github.com/\(path)"
        )

        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw GitHubAPIError.invalidResponse
        }

        var request = URLRequest(url: url)

        request.setValue(
            "application/vnd.github+json",
            forHTTPHeaderField: "Accept"
        )

        request.setValue(
            "2022-11-28",
            forHTTPHeaderField: "X-GitHub-Api-Version"
        )

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(
                for: request
            )
        } catch let error as URLError {
            if error.code == .cancelled {
                throw error
            }

            throw GitHubAPIError.networkError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        switch httpResponse.statusCode {

        case 200..<300:
            return data

        case 404:
            throw GitHubAPIError.userNotFound

        case 403, 429:
            if httpResponse.statusCode == 429 ||
                httpResponse.value(
                    forHTTPHeaderField: "X-RateLimit-Remaining"
                ) == "0" {

                throw GitHubAPIError.rateLimitExceeded
            }

            throw GitHubAPIError.requestFailed(
                statusCode: httpResponse.statusCode
            )

        default:
            throw GitHubAPIError.requestFailed(
                statusCode: httpResponse.statusCode
            )
        }
    }
}
