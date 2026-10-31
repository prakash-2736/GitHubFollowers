
import Foundation
import GitHubNetworking

final class FavouritesManager {

    static let shared = FavouritesManager()

    private let storageKey = "github_favourites"

    private init() {}

    func getFavourites() -> [GitHubUser] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let favourites = try? JSONDecoder().decode(
                [GitHubUser].self,
                from: data
              ) else {
            return []
        }

        return favourites
    }

    func addFavourite(_ user: GitHubUser) {
        var favourites = getFavourites()

        guard !favourites.contains(where: { $0.id == user.id }) else {
            return
        }

        favourites.append(user)
        save(favourites)
    }

    func removeFavourite(id: Int) {
        var favourites = getFavourites()
        favourites.removeAll { $0.id == id }
        save(favourites)
    }

    func isFavourite(id: Int) -> Bool {
        getFavourites().contains { $0.id == id }
    }

    private func save(_ favourites: [GitHubUser]) {
        guard let data = try? JSONEncoder().encode(favourites) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
