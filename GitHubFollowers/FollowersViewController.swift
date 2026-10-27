
import UIKit
import GitHubNetworking

final class FollowersViewController: UIViewController {

    private let username: String
    private let apiClient = GitHubAPIClient()

    private var collectionView: UICollectionView!
    private var followers: [String: GitHubUser] = [:]
    private var filteredLogins: [String] = []

    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!
    private var searchController: UISearchController!

    // Pagination
    private var currentPage = 1
    private var isLoading = false
    private var hasMoreFollowers = true
    private let perPage = 50

    // Loading and empty states
    private let statusView = UIView()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    init(username: String) {
        self.username = username
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "\(username)'s Followers"
        view.backgroundColor = AppTheme.background

        configureCollectionView()
        configureDataSource()
        configureSearchController()
        configureStatusView()
        fetchFollowers()
    }

    // MARK: - Collection View

    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(
            top: 16,
            left: 16,
            bottom: 16,
            right: 16
        )

        collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        collectionView.backgroundColor = AppTheme.background
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        collectionView.register(
            FollowerCell.self,
            forCellWithReuseIdentifier: FollowerCell.reuseIdentifier
        )

        collectionView.delegate = self
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            collectionView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            collectionView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            collectionView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])
    }

    // MARK: - Data Source

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Int, String>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, login in

            guard let self,
                  let follower = self.followers[login],
                  let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: FollowerCell.reuseIdentifier,
                    for: indexPath
                  ) as? FollowerCell else {
                return UICollectionViewCell()
            }

            cell.configure(with: follower)
            return cell
        }
    }

    // MARK: - Search

    private func configureSearchController() {
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search followers"

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    // MARK: - Loading and Empty States

    private func configureStatusView() {
        statusLabel.textAlignment = .center
        statusLabel.textColor = AppTheme.secondaryText
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        activityIndicator.color = AppTheme.accent
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        statusView.backgroundColor = AppTheme.background
        statusView.addSubview(statusLabel)
        statusView.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(
                equalTo: statusView.centerXAnchor
            ),
            statusLabel.centerYAnchor.constraint(
                equalTo: statusView.centerYAnchor
            ),
            statusLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: statusView.leadingAnchor,
                constant: 24
            ),
            statusLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: statusView.trailingAnchor,
                constant: -24
            ),
            activityIndicator.centerXAnchor.constraint(
                equalTo: statusView.centerXAnchor
            ),
            activityIndicator.centerYAnchor.constraint(
                equalTo: statusView.centerYAnchor
            )
        ])

        collectionView.backgroundView = statusView
    }

    // MARK: - Pagination

    private func fetchFollowers() {
        guard !isLoading, hasMoreFollowers else { return }

        isLoading = true

        if followers.isEmpty {
            statusLabel.isHidden = true
            activityIndicator.startAnimating()
        }

        Task {
            do {
                let results = try await apiClient.fetchFollowers(
                    username: username,
                    page: currentPage,
                    perPage: perPage
                )

                await MainActor.run {
                    for follower in results {
                        followers[follower.login] = follower
                    }

                    if results.count < perPage {
                        hasMoreFollowers = false
                    }

                    currentPage += 1
                    isLoading = false
                    activityIndicator.stopAnimating()

                    updateFilteredLogins()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    activityIndicator.stopAnimating()
                    updateFilteredLogins()
                    showError(message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Filtering

    private func updateFilteredLogins() {
        let searchText = searchController.searchBar.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let allLogins = followers.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        if searchText.isEmpty {
            filteredLogins = allLogins
        } else {
            filteredLogins = allLogins.filter {
                $0.localizedCaseInsensitiveContains(searchText)
            }
        }

        updateEmptyState(searchText: searchText)
        applySnapshot(for: filteredLogins)
    }

    private func updateEmptyState(searchText: String) {
        if isLoading && followers.isEmpty {
            statusLabel.isHidden = true
            activityIndicator.startAnimating()
            return
        }

        activityIndicator.stopAnimating()

        if !filteredLogins.isEmpty {
            statusLabel.isHidden = true
        } else {
            statusLabel.text = searchText.isEmpty
                ? "This user doesn't have any followers yet."
                : "No followers found for \"\(searchText)\"."

            statusLabel.isHidden = false
        }
    }

    // MARK: - Diffable Data Source

    private func applySnapshot(for logins: [String]) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(logins)

        dataSource.apply(snapshot, animatingDifferences: true)
    }

    // MARK: - Error Handling

    private func showError(message: String) {
        let alert = UIAlertController(
            title: "Unable to Load Followers",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "OK", style: .default)
        )

        present(alert, animated: true)
    }
}

// MARK: - Collection View Layout and Scrolling

extension FollowersViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let layout = collectionViewLayout as! UICollectionViewFlowLayout

        let spacing = layout.sectionInset.left
            + layout.sectionInset.right
            + layout.minimumInteritemSpacing * 2

        let width = (collectionView.bounds.width - spacing) / 3

        return CGSize(width: width, height: 110)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let visibleHeight = scrollView.frame.height

        if offsetY > contentHeight - visibleHeight - 200 {
            fetchFollowers()
        }
    }
}

// MARK: - Search Results Updating

extension FollowersViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        updateFilteredLogins()
    }
}
