
import UIKit
import GitHubNetworking

final class FollowersViewController: UIViewController {

    // MARK: - Properties

    private let username: String
    private let apiClient = GitHubAPIClient()

    private var collectionView: UICollectionView!
    private var followers: [GitHubUser] = []
    private var followerIDs = Set<Int>()
    private var followersByLogin: [String: GitHubUser] = [:]
    private var filteredLogins: [String] = []

    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!
    private var searchController: UISearchController!

    // MARK: - Pagination

    private var currentPage = 1
    private var isLoading = false
    private var hasMoreFollowers = true
    private var hasLoadError = false
    private var errorMessage: String?

    private let perPage = 50
    private var fetchTask: Task<Void, Never>?

    // MARK: - Loading and Empty States

    private let statusView = UIView()
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let retryButton = UIButton(type: .system)

    // MARK: - Initialization

    init(username: String) {
        self.username = username
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        fetchTask?.cancel()
        fetchTask = nil
        isLoading = false
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
                  let follower = self.followersByLogin[login],
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
        searchController = UISearchController(
            searchResultsController: nil
        )

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search followers"

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private var isSearchFiltering: Bool {
        let searchText = searchController.searchBar.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return !searchText.isEmpty
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

        retryButton.setTitle("Retry", for: .normal)
        retryButton.setTitleColor(AppTheme.accent, for: .normal)
        retryButton.titleLabel?.font = .systemFont(
            ofSize: 16,
            weight: .semibold
        )
        retryButton.addTarget(
            self,
            action: #selector(retryButtonTapped),
            for: .touchUpInside
        )
        retryButton.isHidden = true
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        statusView.backgroundColor = AppTheme.background
        statusView.addSubview(statusLabel)
        statusView.addSubview(activityIndicator)
        statusView.addSubview(retryButton)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(
                equalTo: statusView.centerXAnchor
            ),
            activityIndicator.centerYAnchor.constraint(
                equalTo: statusView.centerYAnchor,
                constant: -35
            ),

            statusLabel.topAnchor.constraint(
                equalTo: activityIndicator.bottomAnchor,
                constant: 12
            ),
            statusLabel.centerXAnchor.constraint(
                equalTo: statusView.centerXAnchor
            ),
            statusLabel.leadingAnchor.constraint(
                greaterThanOrEqualTo: statusView.leadingAnchor,
                constant: 24
            ),
            statusLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: statusView.trailingAnchor,
                constant: -24
            ),

            retryButton.topAnchor.constraint(
                equalTo: statusLabel.bottomAnchor,
                constant: 12
            ),
            retryButton.centerXAnchor.constraint(
                equalTo: statusView.centerXAnchor
            )
        ])

        collectionView.backgroundView = statusView
    }

    private func updateEmptyState(searchText: String) {

        let shouldShowStatus = filteredLogins.isEmpty

        collectionView.backgroundView = shouldShowStatus
            ? statusView
            : nil

        guard shouldShowStatus else {
            activityIndicator.stopAnimating()
            return
        }

        if isLoading && followers.isEmpty {
            statusLabel.isHidden = true
            retryButton.isHidden = true
            activityIndicator.startAnimating()
            return
        }

        activityIndicator.stopAnimating()

        if hasLoadError && followers.isEmpty {
            statusLabel.text = """
            Unable to load followers.

            \(errorMessage ?? "Please try again.")
            """
            retryButton.isHidden = false

        } else if !searchText.isEmpty {
            statusLabel.text = "No followers found for \"\(searchText)\"."
            retryButton.isHidden = true

        } else {
            statusLabel.text = "This user doesn't have any followers yet."
            retryButton.isHidden = true
        }

        statusLabel.isHidden = false
    }

    // MARK: - Pagination

    private func fetchFollowers(isRetry: Bool = false) {

        guard !isLoading,
              hasMoreFollowers,
              !isSearchFiltering,
              !hasLoadError || isRetry else {
            return
        }

        if isRetry {
            hasLoadError = false
            errorMessage = nil
        }

        isLoading = true
        updateFilteredLogins()

        fetchTask = Task { [weak self] in

            guard let self else { return }

            do {
                let results = try await apiClient.fetchFollowers(
                    username: username,
                    page: currentPage,
                    perPage: perPage
                )

                guard !Task.isCancelled else {
                    return
                }

                // Append results in GitHub API order.
                for follower in results {

                    // Deduplicate using GitHub user ID.
                    if followerIDs.insert(follower.id).inserted {
                        followers.append(follower)
                        followersByLogin[follower.login] = follower
                    }
                }

                if results.count < perPage {
                    hasMoreFollowers = false
                }

                currentPage += 1
                isLoading = false
                hasLoadError = false
                errorMessage = nil
                fetchTask = nil

                updateFilteredLogins()

            } catch {

                if Task.isCancelled {
                    isLoading = false
                    fetchTask = nil
                    return
                }

                isLoading = false
                hasLoadError = true
                errorMessage = error.localizedDescription
                fetchTask = nil

                updateFilteredLogins()

                // Initial failure is shown in the empty state.
                // Later page failures get an explicit Retry alert.
                if !followers.isEmpty {
                    showPaginationError()
                }
            }
        }
    }

    // MARK: - Retry

    @objc private func retryButtonTapped() {
        fetchFollowers(isRetry: true)
    }

    private func showPaginationError() {

        let alert = UIAlertController(
            title: "Unable to Load More Followers",
            message: errorMessage ?? "Please try again.",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "Cancel", style: .cancel)
        )

        alert.addAction(
            UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
                self?.fetchFollowers(isRetry: true)
            }
        )

        present(alert, animated: true)
    }

    // MARK: - Filtering

    private func updateFilteredLogins() {

        let searchText = searchController.searchBar.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Preserve the original API order.
        filteredLogins = followers
            .filter {
                searchText.isEmpty ||
                $0.login.localizedCaseInsensitiveContains(searchText)
            }
            .map(\.login)

        updateEmptyState(searchText: searchText)
        applySnapshot(for: filteredLogins)
    }

    // MARK: - Diffable Data Source

    private func applySnapshot(for logins: [String]) {

        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()

        snapshot.appendSections([0])
        snapshot.appendItems(logins)

        dataSource.apply(
            snapshot,
            animatingDifferences: true
        )
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

        // Do not paginate while filtering or after a failed request.
        guard !isSearchFiltering,
              !hasLoadError,
              !isLoading,
              hasMoreFollowers else {
            return
        }

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
