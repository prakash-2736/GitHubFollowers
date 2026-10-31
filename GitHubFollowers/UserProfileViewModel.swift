
import Foundation
import Combine
import GitHubNetworking

@MainActor
final class UserProfileViewModel: ObservableObject {

    @Published private(set) var user: GitHubUser?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = GitHubAPIClient()

    init(user: GitHubUser? = nil) {
        self.user = user
    }

    func loadUser(username: String) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            user = try await apiClient.fetchUser(
                username: username
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
