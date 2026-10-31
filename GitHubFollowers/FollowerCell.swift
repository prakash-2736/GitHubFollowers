
import UIKit
import GitHubNetworking

final class FollowerCell: UICollectionViewCell {

    // MARK: - Reuse Identifier

    static let reuseIdentifier = "FollowerCell"

    // MARK: - Properties

    private var representedAvatarURL: URL?
    private var imageTask: Task<Void, Never>?

    // MARK: - UI Components

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 35

        imageView.backgroundColor = AppTheme.secondaryBackground
        imageView.image = UIImage(
            systemName: "person.crop.circle.fill"
        )
        imageView.tintColor = AppTheme.secondaryText

        imageView.translatesAutoresizingMaskIntoConstraints = false

        return imageView
    }()

    private let usernameLabel: UILabel = {
        let label = UILabel()

        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.textColor = AppTheme.primaryText
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8

        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Cell Reuse

    override func prepareForReuse() {
        super.prepareForReuse()

        // Cancel the previous image request.
        imageTask?.cancel()
        imageTask = nil

        usernameLabel.text = nil
        avatarImageView.image = UIImage(
            systemName: "person.crop.circle.fill"
        )
        avatarImageView.tintColor = AppTheme.secondaryText

        representedAvatarURL = nil
    }

    // MARK: - Configure Subviews

    private func configureSubviews() {

        contentView.addSubview(avatarImageView)
        contentView.addSubview(usernameLabel)

        NSLayoutConstraint.activate([

            avatarImageView.topAnchor.constraint(
                equalTo: contentView.topAnchor
            ),

            avatarImageView.centerXAnchor.constraint(
                equalTo: contentView.centerXAnchor
            ),

            avatarImageView.widthAnchor.constraint(
                equalToConstant: 70
            ),

            avatarImageView.heightAnchor.constraint(
                equalToConstant: 70
            ),

            usernameLabel.topAnchor.constraint(
                equalTo: avatarImageView.bottomAnchor,
                constant: 8
            ),

            usernameLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 2
            ),

            usernameLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -2
            ),

            usernameLabel.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor
            )
        ])
    }

    // MARK: - Configure Cell

    func configure(with follower: GitHubUser) {

        // Cancel any previous request.
        imageTask?.cancel()
        imageTask = nil

        usernameLabel.text = follower.login

        // Show placeholder while loading.
        avatarImageView.image = UIImage(
            systemName: "person.crop.circle.fill"
        )
        avatarImageView.tintColor = AppTheme.secondaryText

        representedAvatarURL = follower.avatarURL

        let avatarURL = follower.avatarURL

        // Request image from shared ImageLoader.
        imageTask = Task { [weak self] in

            do {

                let image = try await ImageLoader.shared.loadImage(
                    from: avatarURL
                )

                // Ignore cancelled requests.
                guard !Task.isCancelled else {
                    return
                }

                // Make sure this cell still represents the same user.
                guard let self,
                      self.representedAvatarURL == avatarURL else {
                    return
                }

                self.avatarImageView.image = image

            } catch is CancellationError {

                // Expected when the cell is reused.

            } catch {

                // Keep the placeholder if loading fails.
            }
        }
    }
}
