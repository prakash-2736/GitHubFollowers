
import UIKit
import SwiftUI
import GitHubNetworking

final class FavouritesViewController: UIViewController {

    private var favourites: [GitHubUser] = []
    private var dataSource: UITableViewDiffableDataSource<Int, Int>?

    private let tableView = UITableView(
        frame: .zero,
        style: .insetGrouped
    )

    // In-memory image cache
    private static let imageCache = NSCache<NSString, UIImage>()

    // Disk image cache
    private static let diskCacheDirectory: URL = {
        let cachesDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]

        return cachesDirectory.appendingPathComponent(
            "GitHubAvatarCache",
            isDirectory: true
        )
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Favourites"
        view.backgroundColor = AppTheme.background

        configureTableView()
        configureDataSource()
        loadFavourites()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFavourites()
    }

    // MARK: - Table View

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = AppTheme.background
        tableView.separatorStyle = .none
        tableView.rowHeight = 85
        tableView.delegate = self

        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: "FavouriteCell"
        )

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            tableView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            tableView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            tableView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])
    }

    // MARK: - Data Source

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Int, Int>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, userID in

            let cell = tableView.dequeueReusableCell(
                withIdentifier: "FavouriteCell",
                for: indexPath
            )

            guard let self,
                  let user = self.favourites.first(where: {
                      $0.id == userID
                  }) else {
                return cell
            }

            // IMPORTANT: Load the cached image BEFORE configuring the cell.
            let cachedImage = self.cachedAvatar(for: user.avatarURL)

            var content = cell.defaultContentConfiguration()
            content.text = user.login
            content.secondaryText = user.name ?? "GitHub user"

            content.image = cachedImage ?? UIImage(
                systemName: "person.crop.circle.fill"
            )

            content.imageProperties.tintColor = AppTheme.secondaryText
            content.imageProperties.maximumSize = CGSize(
                width: 44,
                height: 44
            )
            content.imageProperties.cornerRadius = 22

            cell.backgroundColor = AppTheme.secondaryBackground
            cell.contentView.backgroundColor = AppTheme.secondaryBackground
            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator

            // Download only if neither cache contains the image.
            if cachedImage == nil {
                self.downloadAvatar(for: user)
            }

            return cell
        }

        dataSource?.defaultRowAnimation = .automatic
    }

    // MARK: - Cache Helpers

    private func cacheFileURL(for avatarURL: URL) -> URL {
        let filename = Data(avatarURL.absoluteString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")

        return Self.diskCacheDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("img")
    }

    private func cachedAvatar(for avatarURL: URL) -> UIImage? {
        let key = avatarURL.absoluteString as NSString

        // 1. Fast in-memory lookup.
        if let image = Self.imageCache.object(forKey: key) {
            return image
        }

        // 2. Persistent disk-cache lookup.
        let fileURL = cacheFileURL(for: avatarURL)

        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        // Restore the image to memory for future reuse.
        Self.imageCache.setObject(image, forKey: key)

        return image
    }

    private func saveAvatarToDisk(
        _ data: Data,
        for avatarURL: URL
    ) {
        do {
            try FileManager.default.createDirectory(
                at: Self.diskCacheDirectory,
                withIntermediateDirectories: true
            )

            try data.write(
                to: cacheFileURL(for: avatarURL),
                options: .atomic
            )
        } catch {
            // The in-memory cache can still be used.
        }
    }

    // MARK: - Download Avatar

    private func downloadAvatar(for user: GitHubUser) {
        let avatarURL = user.avatarURL
        let cacheKey = avatarURL.absoluteString as NSString

        // Avoid downloading an image already cached in memory.
        guard Self.imageCache.object(forKey: cacheKey) == nil else {
            return
        }

        Task { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(
                    from: avatarURL
                )

                if let response = response as? HTTPURLResponse,
                   !(200...299).contains(response.statusCode) {
                    return
                }

                guard let image = UIImage(data: data) else {
                    return
                }

                Self.imageCache.setObject(image, forKey: cacheKey)

                self?.saveAvatarToDisk(data, for: avatarURL)

                await MainActor.run {
                    self?.updateVisibleAvatar(
                        image,
                        for: user.id
                    )
                }
            } catch {
                // Keep the placeholder if the download fails.
            }
        }
    }

    // MARK: - Update Visible Cell

    @MainActor
    private func updateVisibleAvatar(
        _ image: UIImage,
        for userID: Int
    ) {
        // Find the currently visible cell by user ID, not an old index path.
        for cell in tableView.visibleCells {
            guard
                let indexPath = tableView.indexPath(for: cell),
                dataSource?.itemIdentifier(for: indexPath) == userID,
                let user = favourites.first(where: { $0.id == userID })
            else {
                continue
            }

            var content = cell.defaultContentConfiguration()
            content.text = user.login
            content.secondaryText = user.name ?? "GitHub user"
            content.image = image

            content.imageProperties.maximumSize = CGSize(
                width: 44,
                height: 44
            )
            content.imageProperties.cornerRadius = 22

            cell.backgroundColor = AppTheme.secondaryBackground
            cell.contentView.backgroundColor = AppTheme.secondaryBackground
            cell.contentConfiguration = content
        }
    }

    // MARK: - Favourites

    private func loadFavourites() {
        favourites = FavouritesManager.shared.getFavourites()

        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(favourites.map(\.id))

        dataSource?.apply(
            snapshot,
            animatingDifferences: true
        )

        tableView.backgroundView = favourites.isEmpty
            ? emptyStateView()
            : nil
    }

    private func emptyStateView() -> UIView {
        let container = UIView()
        let label = UILabel()

        label.text = "No favourites yet"
        label.textColor = AppTheme.secondaryText
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 17)
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(
                equalTo: container.centerXAnchor
            ),
            label.centerYAnchor.constraint(
                equalTo: container.centerYAnchor
            )
        ])

        return container
    }

    // MARK: - Profile Navigation

    private func openProfile(for user: GitHubUser) {
        let profileView = UserProfileView(
            username: user.login,
            onGetFollowers: { [weak self] login in
                self?.navigationController?.pushViewController(
                    FollowersViewController(username: login),
                    animated: true
                )
            }
        )

        let hostingController = UIHostingController(
            rootView: profileView
        )

        navigationController?.pushViewController(
            hostingController,
            animated: true
        )
    }
}

// MARK: - Table View Delegate

extension FavouritesViewController: UITableViewDelegate {

    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard
            let userID = dataSource?.itemIdentifier(for: indexPath),
            let user = favourites.first(where: { $0.id == userID })
        else {
            return
        }

        openProfile(for: user)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {

        guard let userID = dataSource?.itemIdentifier(for: indexPath) else {
            return nil
        }

        let deleteAction = UIContextualAction(
            style: .destructive,
            title: "Remove"
        ) { [weak self] _, _, completion in

            FavouritesManager.shared.removeFavourite(id: userID)
            self?.loadFavourites()

            completion(true)
        }

        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
