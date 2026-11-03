
import Foundation
import GitHubNetworking

@MainActor
final class FavouritesManager {

    static let shared = FavouritesManager()

    private let storageKey = "github_favourites"

    private var favourites: [GitHubUser]
    private var favouriteIDs: Set<Int>

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let savedFavourites = try? JSONDecoder().decode(
                [GitHubUser].self,
                from: data
           ) {
            favourites = savedFavourites
            favouriteIDs = Set(savedFavourites.map(\.id))
        } else {
            favourites = []
            favouriteIDs = []
        }
    }

    // MARK: - Get Favourites

    func getFavourites() -> [GitHubUser] {
        favourites
    }

    // MARK: - Add Favourite

    func addFavourite(_ user: GitHubUser) {
        guard !favouriteIDs.contains(user.id) else {
            return
        }

        favourites.append(user)
        favouriteIDs.insert(user.id)

        save()
    }

    // MARK: - Remove Favourite

    func removeFavourite(id: Int) {
        guard favouriteIDs.contains(id) else {
            return
        }

        favourites.removeAll { $0.id == id }
        favouriteIDs.remove(id)

        save()
    }

    // MARK: - Check Favourite

    func isFavourite(id: Int) -> Bool {
        favouriteIDs.contains(id)
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(favourites) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
