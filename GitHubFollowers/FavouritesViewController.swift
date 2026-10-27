
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

    private static let imageCache = NSCache<NSString, UIImage>()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Favourites"
        view.backgroundColor = .systemBackground

        configureTableView()
        configureDataSource()
        loadFavourites()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFavourites()
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: "FavouriteCell"
        )
        tableView.delegate = self
        tableView.rowHeight = 85

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Int, Int>(
            tableView: tableView
        ) { [weak self] tableView, indexPath, userID in

            let cell = tableView.dequeueReusableCell(
                withIdentifier: "FavouriteCell",
                for: indexPath
            )

            guard let self,
                  let user = self.favourites.first(where: { $0.id == userID })
            else {
                return cell
            }

            var content = cell.defaultContentConfiguration()
            content.text = user.login
            content.secondaryText = user.name ?? "GitHub user"
            content.image = UIImage(
                systemName: "person.crop.circle.fill"
            )
            content.imageProperties.tintColor = .secondaryLabel
            content.imageProperties.maximumSize = CGSize(
                width: 44,
                height: 44
            )

            cell.contentConfiguration = content
            cell.accessoryType = .disclosureIndicator

            self.loadAvatar(for: user, at: indexPath)

            return cell
        }

        dataSource?.defaultRowAnimation = .automatic
    }

    private func loadAvatar(for user: GitHubUser, at indexPath: IndexPath) {
        let cacheKey = user.avatarURL.absoluteString as NSString

        if let cachedImage = Self.imageCache.object(forKey: cacheKey) {
            updateAvatar(cachedImage, for: user.id, at: indexPath)
            return
        }

        let avatarURL = user.avatarURL

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(
                    from: avatarURL
                )

                guard let image = UIImage(data: data) else {
                    return
                }

                Self.imageCache.setObject(image, forKey: cacheKey)

                await MainActor.run {
                    self.updateAvatar(image, for: user.id, at: indexPath)
                }
            } catch {
                // Keep the placeholder icon if loading fails.
            }
        }
    }

    private func updateAvatar(
        _ image: UIImage,
        for userID: Int,
        at indexPath: IndexPath
    ) {
        guard
            let currentID = dataSource?.itemIdentifier(for: indexPath),
            currentID == userID,
            let cell = tableView.cellForRow(at: indexPath),
            let user = favourites.first(where: { $0.id == userID })
        else {
            return
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

        cell.contentConfiguration = content
    }

    private func loadFavourites() {
        favourites = FavouritesManager.shared.getFavourites()

        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(favourites.map(\.id))

        dataSource?.apply(snapshot, animatingDifferences: true)

        tableView.backgroundView = favourites.isEmpty
            ? emptyStateView()
            : nil
    }

    private func emptyStateView() -> UIView {
        let container = UIView()
        let label = UILabel()

        label.text = "No favourites yet"
        label.textColor = .secondaryLabel
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
