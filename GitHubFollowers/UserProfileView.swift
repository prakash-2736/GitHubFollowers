
import SwiftUI
import UIKit
import GitHubNetworking

struct UserProfileView: View {

    @StateObject private var viewModel = UserProfileViewModel()

    @State private var isFavourite = false
    @State private var avatarImage: UIImage?

    let username: String
    let onGetFollowers: (String) -> Void
    var onGetRepositories: (String) -> Void = { _ in }

    var body: some View {
        Group {
            if let user = viewModel.user {
                profileContent(user)
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView("Loading profile...")
                                .tint(AppTheme.swiftUIAccent)
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
            } else if viewModel.isLoading {
                ProgressView("Loading profile...")
                    .tint(AppTheme.swiftUIAccent)
            } else {
                ContentUnavailableView {
                    Label(
                        "Profile Unavailable",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                } description: {
                    Text(
                        viewModel.errorMessage ?? "Unable to load profile."
                    )
                } actions: {
                    Button("Try Again") {
                        Task {
                            await viewModel.loadUser(username: username)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.swiftUIAccent)
                }
            }
        }
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Avoid fetching the same profile again.
            if viewModel.user == nil {
                await viewModel.loadUser(username: username)
            }

            if let user = viewModel.user {
                isFavourite = FavouritesManager.shared
                    .isFavourite(id: user.id)
            }
        }
    }

    // MARK: - Profile Content

    private func profileContent(_ user: GitHubUser) -> some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: - Avatar

                Group {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(
                                AppTheme.swiftUISecondaryText
                            )
                    }
                }
                .frame(width: 120, height: 120)
                .background(AppTheme.swiftUISecondaryBackground)
                .clipShape(Circle())
                .task(id: user.avatarURL) {
                    do {
                        let image = try await ImageLoader.shared.loadImage(
                            from: user.avatarURL
                        )

                        guard !Task.isCancelled else {
                            return
                        }

                        avatarImage = image

                    } catch is CancellationError {
                        // Expected when the task is cancelled.
                    } catch {
                        // Keep the placeholder image.
                    }
                }

                Text(user.name ?? user.login)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.swiftUIPrimaryText)

                Text("@\(user.login)")
                    .foregroundStyle(AppTheme.swiftUISecondaryText)

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.swiftUIPrimaryText)
                        .padding(.horizontal)
                }

                // MARK: - Followers and Following

                HStack(spacing: 40) {
                    countView(
                        title: "Followers",
                        count: user.followers ?? 0
                    )

                    countView(
                        title: "Following",
                        count: user.following ?? 0
                    )
                }

                // MARK: - Favourites

                Button {
                    if isFavourite {
                        FavouritesManager.shared.removeFavourite(
                            id: user.id
                        )
                    } else {
                        FavouritesManager.shared.addFavourite(user)
                    }

                    isFavourite.toggle()
                } label: {
                    Label(
                        isFavourite
                            ? "Remove Favourite"
                            : "Add to Favourites",
                        systemImage: isFavourite
                            ? "heart.fill"
                            : "heart"
                    )
                }
                .buttonStyle(.bordered)
                .tint(isFavourite ? .red : AppTheme.swiftUIAccent)

                // MARK: - Followers

                Button("Get Followers") {
                    onGetFollowers(user.login)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.swiftUIAccent)

                // MARK: - Repositories

                Button {
                    onGetRepositories(user.login)
                } label: {
                    Label(
                        "Get Repositories",
                        systemImage: "book.closed"
                    )
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.swiftUIAccent)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .background(AppTheme.swiftUIBackground)
    }

    // MARK: - Follower and Following Counts

    private func countView(
        title: String,
        count: Int
    ) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.swiftUIPrimaryText)

            Text(title)
                .foregroundStyle(AppTheme.swiftUISecondaryText)
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(
            username: "octocat",
            onGetFollowers: { _ in },
            onGetRepositories: { _ in }
        )
    }
}
