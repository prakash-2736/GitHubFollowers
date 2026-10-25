
import Foundation

public struct GitHubUser: Codable, Identifiable, Sendable {
    public let login: String
    public let id: Int
    public let avatarURL: URL
    public let name: String?
    public let bio: String?
    public let followers: Int?
    public let following: Int?

    enum CodingKeys: String, CodingKey {
        case login
        case id
        case avatarURL = "avatar_url"
        case name
        case bio
        case followers
        case following
    }

    public init(
        login: String,
        id: Int,
        avatarURL: URL,
        name: String? = nil,
        bio: String? = nil,
        followers: Int? = nil,
        following: Int? = nil
    ) {
        self.login = login
        self.id = id
        self.avatarURL = avatarURL
        self.name = name
        self.bio = bio
        self.followers = followers
        self.following = following
    }
}
