
import Foundation
import Combine
import GitHubNetworking

@MainActor
final class RepositoryViewModel: ObservableObject {
    @Published private(set) var repositories: [GitHubRepository] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = GitHubAPIClient()

    func loadRepositories(username: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            repositories = try await apiClient.fetchRepositories(
                username: username,
                page: 1,
                perPage: 50
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
