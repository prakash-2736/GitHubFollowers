
import UIKit
import SwiftUI
import GitHubNetworking

final class FavouritesViewController: UIViewController {

    private var favourites: [GitHubUser] = []
    private var dataSource: UITableViewDiffableDataSource<Int, Int>?
    private var imageTasks: [Int: Task<Void, Never>] = [:]

    private let tableView = UITableView(
        frame: .zero,
        style: .insetGrouped
    )

    // MARK: - Lifecycle

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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        imageTasks.values.forEach { $0.cancel() }
        imageTasks.removeAll()
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

            var content = cell.defaultContentConfiguration()

            content.text = user.login
            content.secondaryText = user.name ?? "GitHub user"
            content.image = UIImage(
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

            self.loadAvatar(for: user)

            return cell
        }

        dataSource?.defaultRowAnimation = .automatic
    }

    // MARK: - Avatar Loading

    private func loadAvatar(for user: GitHubUser) {
        guard imageTasks[user.id] == nil else {
            return
        }

        let task = Task { [weak self] in
            do {
                let image = try await ImageLoader.shared.loadImage(
                    from: user.avatarURL
                )

                guard !Task.isCancelled else {
                    return
                }

                self?.updateVisibleAvatar(
                    image,
                    for: user.id
                )

            } catch is CancellationError {
                // Expected when the screen disappears.
            } catch {
                // Keep the placeholder if loading fails.
            }

            self?.imageTasks[user.id] = nil
        }

        imageTasks[user.id] = task
    }

    @MainActor
    private func updateVisibleAvatar(
        _ image: UIImage,
        for userID: Int
    ) {
        for cell in tableView.visibleCells {
            guard
                let indexPath = tableView.indexPath(for: cell),
                dataSource?.itemIdentifier(for: indexPath) == userID,
                let user = favourites.first(where: {
                    $0.id == userID
                })
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

        let favouriteIDs = Set(favourites.map(\.id))

        for (userID, task) in imageTasks
        where !favouriteIDs.contains(userID) {
            task.cancel()
            imageTasks[userID] = nil
        }

        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])

        let userIDs = favourites.map(\.id)
        snapshot.appendItems(userIDs)

        // Reconfigure existing rows so cancelled avatar tasks restart.
        let existingIDs = Set(
            dataSource?.snapshot().itemIdentifiers ?? []
        )

        let IDsToReconfigure = userIDs.filter {
            existingIDs.contains($0)
        }

        if !IDsToReconfigure.isEmpty {
            snapshot.reconfigureItems(IDsToReconfigure)
        }

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
        let navigationController = self.navigationController

        let profileView = UserProfileView(
            username: user.login,
            user: user,
            onGetFollowers: { [weak navigationController] login in
                navigationController?.pushViewController(
                    FollowersViewController(username: login),
                    animated: true
                )
            },
            onGetRepositories: { [weak navigationController] login in
                let repositoryView = RepositoryView(
                    username: login
                )

                let hostingController = UIHostingController(
                    rootView: repositoryView
                )

                navigationController?.pushViewController(
                    hostingController,
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
            let user = favourites.first(where: {
                $0.id == userID
            })
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
