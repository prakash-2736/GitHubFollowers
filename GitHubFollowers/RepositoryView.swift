
import SwiftUI
import GitHubNetworking

struct RepositoryView: View {
    @StateObject private var viewModel = RepositoryViewModel()

    let username: String

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.repositories.isEmpty {
                ProgressView("Loading repositories...")
            } else if viewModel.repositories.isEmpty {
                ContentUnavailableView(
                    "No Repositories",
                    systemImage: "book.closed",
                    description: Text(
                        viewModel.errorMessage
                        ?? "This user has no public repositories."
                    )
                )
            } else {
                List(viewModel.repositories) { repository in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(repository.name)
                            .font(.headline)

                        if let description = repository.description,
                           !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            if let language = repository.language {
                                Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Label(
                                "\(repository.stars)",
                                systemImage: "star.fill"
                            )
                            .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("\(username)'s Repos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRepositories(username: username)
        }
        .alert(
            "Unable to Load Repositories",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        RepositoryView(username: "octocat")
    }
}
