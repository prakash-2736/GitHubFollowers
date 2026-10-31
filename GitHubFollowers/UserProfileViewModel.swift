
import Foundation
import Combine
import GitHubNetworking

@MainActor
final class UserProfileViewModel: ObservableObject {

    @Published private(set) var user: GitHubUser?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let apiClient = GitHubAPIClient()

    func loadUser(username: String) async {
        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            user = try await apiClient.fetchUser(username: username)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
