import UIKit
import SwiftUI
import GitHubNetworking

@MainActor
enum ProfileScreenBuilder {

    static func makeHostingController(
        for user: GitHubUser,
        navigationController: UINavigationController?
    ) -> UIHostingController<UserProfileView> {

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
                let repositoryView = RepositoryView(username: login)
                let hostingController = UIHostingController(
                    rootView: repositoryView
                )

                navigationController?.pushViewController(
                    hostingController,
                    animated: true
                )
            }
        )

        return UIHostingController(rootView: profileView)
    }
}
