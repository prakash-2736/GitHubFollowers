
import SwiftUI
import GitHubNetworking

struct UserProfileView: View {

    @StateObject private var viewModel = UserProfileViewModel()
    @State private var isFavourite = false

    let username: String
    let onGetFollowers: (String) -> Void

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading profile...")
            } else if let user = viewModel.user {
                profileContent(user)
            } else {
                ContentUnavailableView(
                    "Profile Unavailable",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(
                        viewModel.errorMessage ?? "Unable to load profile."
                    )
                )
            }
        }
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadUser(username: username)

            if let user = viewModel.user {
                isFavourite = FavouritesManager.shared
                    .isFavourite(id: user.id)
            }
        }
        .alert(
            "Unable to Load Profile",
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

    private func profileContent(_ user: GitHubUser) -> some View {
        ScrollView {
            VStack(spacing: 20) {

                AsyncImage(url: user.avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()

                    case .failure:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)

                    case .empty:
                        ProgressView()

                    @unknown default:
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, height: 120)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())

                Text(user.name ?? user.login)
                    .font(.title2)
                    .fontWeight(.bold)

                Text("@\(user.login)")
                    .foregroundStyle(.secondary)

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

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

                Button {
                    if isFavourite {
                        FavouritesManager.shared.removeFavourite(id: user.id)
                    } else {
                        FavouritesManager.shared.addFavourite(user)
                    }

                    isFavourite.toggle()
                } label: {
                    Label(
                        isFavourite ? "Remove Favourite" : "Add to Favourites",
                        systemImage: isFavourite ? "heart.fill" : "heart"
                    )
                }
                .buttonStyle(.bordered)
                .tint(isFavourite ? .red : .accentColor)

                Button("Get Followers") {
                    onGetFollowers(user.login)
                }
                .buttonStyle(.borderedProminent)

                NavigationLink {
                    RepositoryView(username: user.login)
                } label: {
                    Label(
                        "Get Repositories",
                        systemImage: "book.closed"
                    )
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private func countView(title: String, count: Int) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        UserProfileView(
            username: "octocat",
            onGetFollowers: { _ in }
        )
    }
}
