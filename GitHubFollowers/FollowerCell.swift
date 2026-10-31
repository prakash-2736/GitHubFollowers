
import UIKit
import GitHubNetworking

final class FollowerCell: UICollectionViewCell {

    static let reuseIdentifier = "FollowerCell"

    private static let imageCache = NSCache<NSString, UIImage>()

    private let avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 35
        imageView.backgroundColor = .secondarySystemBackground
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let usernameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.textColor = .label
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var representedAvatarURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        usernameLabel.text = nil
        avatarImageView.image = nil
        representedAvatarURL = nil
    }

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
            avatarImageView.widthAnchor.constraint(equalToConstant: 70),
            avatarImageView.heightAnchor.constraint(equalToConstant: 70),

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

    func configure(with follower: GitHubUser) {
        usernameLabel.text = follower.login
        avatarImageView.image = nil
        representedAvatarURL = follower.avatarURL

        let cacheKey = follower.avatarURL.absoluteString as NSString

        if let cachedImage = Self.imageCache.object(forKey: cacheKey) {
            avatarImageView.image = cachedImage
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(
                    from: follower.avatarURL
                )

                guard let image = UIImage(data: data) else {
                    return
                }

                Self.imageCache.setObject(image, forKey: cacheKey)

                await MainActor.run {
                    guard self.representedAvatarURL == follower.avatarURL else {
                        return
                    }

                    self.avatarImageView.image = image
                }
            } catch {
                // Keep the placeholder background if loading fails.
            }
        }
    }
}
