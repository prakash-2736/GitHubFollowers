
import XCTest
import Foundation
@testable import GitHubNetworking

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol {

    nonisolated(unsafe) static var requestHandler:
        ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

        do {
            let (response, data) = try handler(request)

            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )

            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)

        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // No ongoing network request to stop.
    }
}

// MARK: - GitHub Networking Tests

final class GitHubNetworkingTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: - Test Successful User Fetch

    func testFetchGitHubUser() async throws {

        let responseData = Data(
            """
            {
                "login": "octocat",
                "id": 1,
                "avatar_url": "https://avatars.githubusercontent.com/u/1",
                "name": "The Octocat",
                "bio": null,
                "followers": 100,
                "following": 10
            }
            """.utf8
        )

        let client = makeClient(
            statusCode: 200,
            responseData: responseData
        )

        let user = try await client.fetchUser(
            username: "octocat"
        )

        XCTAssertEqual(user.login, "octocat")
        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.name, "The Octocat")
    }

    // MARK: - Test User Not Found

    func testFetchGitHubUserNotFound() async throws {

        let responseData = Data("{}".utf8)

        let client = makeClient(
            statusCode: 404,
            responseData: responseData
        )

        do {
            _ = try await client.fetchUser(username: "unknown-user")
            XCTFail("Expected userNotFound error")

        } catch let error as GitHubAPIError {
            guard case .userNotFound = error else {
                XCTFail("Expected userNotFound, received \(error)")
                return
            }
        }
    }

    // MARK: - Test Client Creation

    private func makeClient(
        statusCode: Int,
        responseData: Data
    ) -> GitHubAPIClient {

        MockURLProtocol.requestHandler = { request in

            let url = try XCTUnwrap(request.url)

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil
                )
            )

            return (response, responseData)
        }

        let configuration = URLSessionConfiguration.ephemeral

        configuration.protocolClasses = [
            MockURLProtocol.self
        ]

        let session = URLSession(
            configuration: configuration
        )

        return GitHubAPIClient(session: session)
    }
}
