
import UIKit
import GitHubNetworking

final class FollowersViewController: UIViewController {

    private let username: String
    private let apiClient = GitHubAPIClient()

    private var collectionView: UICollectionView!
    private var followers: [String: GitHubUser] = [:]
    private var filteredLogins: [String] = []

    private var dataSource:
        UICollectionViewDiffableDataSource<Int, String>!

    private var searchController: UISearchController!

    // Pagination
    private var currentPage = 1
    private var isLoading = false
    private var hasMoreFollowers = true
    private let perPage = 50

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
        view.backgroundColor = .systemBackground

        configureCollectionView()
        configureDataSource()
        configureSearchController()
        fetchFollowers()
    }

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

        collectionView.backgroundColor = .systemBackground
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

    private func configureSearchController() {
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search followers"

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    // MARK: - Pagination

    private func fetchFollowers() {
        guard !isLoading, hasMoreFollowers else { return }

        isLoading = true

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

                    updateFilteredLogins()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showError(message: error.localizedDescription)
                }
            }
        }
    }

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

        applySnapshot(for: filteredLogins)
    }

    private func applySnapshot(for logins: [String]) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(logins)

        dataSource.apply(snapshot, animatingDifferences: true)
    }

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

// MARK: - Search

extension FollowersViewController: UISearchResultsUpdating {

    func updateSearchResults(
        for searchController: UISearchController
    ) {
        updateFilteredLogins()
    }
}
