
import SwiftUI
import GitHubNetworking

struct RepositoryView: View {

    @StateObject private var viewModel = RepositoryViewModel()

    let username: String

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.repositories.isEmpty {
                ProgressView("Loading repositories...")
                    .tint(AppTheme.swiftUIAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if viewModel.repositories.isEmpty {
                ContentUnavailableView(
                    "No Repositories",
                    systemImage: "book.closed",
                    description: Text(
                        viewModel.errorMessage
                            ?? "This user has no public repositories."
                    )
                )
                .foregroundStyle(AppTheme.swiftUIPrimaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.repositories) { repository in
                            repositoryCard(repository)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(AppTheme.swiftUIBackground)
            }
        }
        .background(AppTheme.swiftUIBackground)
        .navigationTitle("\(username)'s Repos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRepositories(username: username)
        }
        .alert(
            "Unable to Load Repositories",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: {
                    if !$0 {
                        viewModel.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Repository Card

    private func repositoryCard(
        _ repository: GitHubRepository
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.swiftUIAccent)

                Text(repository.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.swiftUIPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            if let description = repository.description,
               !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.swiftUISecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(spacing: 12) {
                if let language = repository.language {
                    Label(
                        language,
                        systemImage: "chevron.left.forwardslash.chevron.right"
                    )
                    .font(.caption)
                    .foregroundStyle(AppTheme.swiftUISecondaryText)
                    .lineLimit(1)
                }

                Spacer(minLength: 4)

                Label(
                    "\(repository.stars)",
                    systemImage: "star.fill"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.swiftUIAccent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.swiftUISecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    AppTheme.swiftUISecondaryText.opacity(0.15),
                    lineWidth: 1
                )
        }
    }
}

#Preview {
    NavigationStack {
        RepositoryView(username: "octocat")
    }
}
