
import UIKit

final class SearchViewController: UIViewController {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "GitHub Followers"
        label.font = .systemFont(ofSize: 30, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Find a GitHub user and explore their followers."
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let usernameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter GitHub username"
        textField.borderStyle = .roundedRect
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.returnKeyType = .search
        textField.accessibilityLabel = "GitHub username"
        return textField
    }()

    private let searchButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Get Followers"
        configuration.cornerStyle = .medium

        let button = UIButton(configuration: configuration)
        button.accessibilityHint = "Search for a GitHub user"
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        setupLayout()
        searchButton.addTarget(
            self,
            action: #selector(searchButtonTapped),
            for: .touchUpInside
        )
    }

    private func setupLayout() {
        let stackView = UIStackView(
            arrangedSubviews: [
                titleLabel,
                subtitleLabel,
                usernameTextField,
                searchButton
            ]
        )

        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor,
                constant: 24
            ),
            stackView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -24
            ),
            stackView.centerYAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.centerYAnchor
            ),
            usernameTextField.heightAnchor.constraint(equalToConstant: 48),
            searchButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func searchButtonTapped() {
        guard let username = usernameTextField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !username.isEmpty else {
            showAlert(
                title: "Username Required",
                message: "Please enter a GitHub username."
            )
            return
        }

        print("Search requested for: \(username)")
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(title: "OK", style: .default)
        )

        present(alert, animated: true)
    }
}
