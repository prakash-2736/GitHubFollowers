
import Foundation

public struct GitHubRepository: Codable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let description: String?
    public let stars: Int
    public let language: String?
    public let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case stars = "stargazers_count"
        case language
        case htmlURL = "html_url"
    }

    public init(
        id: Int,
        name: String,
        description: String? = nil,
        stars: Int,
        language: String? = nil,
        htmlURL: URL
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.stars = stars
        self.language = language
        self.htmlURL = htmlURL
    }
}
