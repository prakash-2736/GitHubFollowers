
import XCTest
@testable import GitHubNetworking

final class GitHubNetworkingTests: XCTestCase {

    func testFetchGitHubUser() async throws {
        let client = GitHubAPIClient()
        let user = try await client.fetchUser(username: "octocat")

        XCTAssertEqual(user.login, "octocat")
        XCTAssertGreaterThan(user.id, 0)
    }
}
