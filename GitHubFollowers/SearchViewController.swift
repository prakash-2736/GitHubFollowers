
import UIKit
import GitHubNetworking

final class SearchViewController: UIViewController,
    UITextFieldDelegate,
    UIGestureRecognizerDelegate {
    private let apiClient = GitHubAPIClient()

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
        textField.clearButtonMode = .whileEditing
        textField.accessibilityLabel = "GitHub username"
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()

    private let searchButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Get Followers"
        configuration.cornerStyle = .medium

        let button = UIButton(configuration: configuration)
        button.accessibilityHint = "Search for a GitHub user"
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let keyboardToolbar = UIToolbar()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        setupLayout()
        setupKeyboard()

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
            stackView.topAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 20
            ),
            stackView.bottomAnchor.constraint(
                lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor,
                constant: -20
            ),
            usernameTextField.heightAnchor.constraint(equalToConstant: 48),
            searchButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupKeyboard() {
        usernameTextField.delegate = self

        keyboardToolbar.sizeToFit()

        let flexibleSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )

        let doneButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissKeyboard)
        )

        keyboardToolbar.items = [flexibleSpace, doneButton]
        usernameTextField.inputAccessoryView = keyboardToolbar

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(dismissKeyboard)
        )
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        searchButtonTapped()
        return true
    }

    @objc private func searchButtonTapped() {
        view.endEditing(true)

        guard let username = usernameTextField.text?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !username.isEmpty else {
            showAlert(
                title: "Username Required",
                message: "Please enter a GitHub username."
            )
            return
        }

        guard searchButton.isEnabled else { return }

        searchButton.isEnabled = false
        searchButton.configuration?.title = "Searching..."

        Task { @MainActor in
            defer {
                searchButton.isEnabled = true
                searchButton.configuration?.title = "Get Followers"
            }

            do {
                let user = try await apiClient.fetchUser(username: username)

                let followersVC = FollowersViewController(
                    username: user.login
                )

                navigationController?.pushViewController(
                    followersVC,
                    animated: true
                )
            } catch let error as GitHubAPIError {
                showAlert(
                    title: "Search Failed",
                    message: error.localizedDescription
                )
            } catch {
                showAlert(
                    title: "Search Failed",
                    message: "Something went wrong. Please try again."
                )
            }
        }
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

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard let touchedView = touch.view else { return true }

        // Don't let the outside-tap gesture intercept button taps.
        if touchedView is UIButton {
            return false
        }

        return true
    }
}
