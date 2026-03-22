import AuthenticationServices
import SwiftUI

struct BankAuthView: View {
    let url: URL
    let onDismiss: (URL?) -> Void

    @State private var hasCompleted = false

    var body: some View {
        NavigationStack {
            WebAuthenticationView(url: url) { callbackURL in
                guard !hasCompleted else { return }
                hasCompleted = true
                onDismiss(callbackURL)
            }
            .navigationTitle("Authorize Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        guard !hasCompleted else { return }
                        hasCompleted = true
                        onDismiss(nil)
                    }
                }
            }
        }
    }
}

// MARK: - ASWebAuthenticationSession wrapper

struct WebAuthenticationView: UIViewControllerRepresentable {
    let url: URL
    let onComplete: (URL?) -> Void

    func makeUIViewController(context: Context) -> WebAuthViewController {
        WebAuthViewController(url: url, onComplete: onComplete)
    }

    func updateUIViewController(_ uiViewController: WebAuthViewController, context: Context) {}
}

class WebAuthViewController: UIViewController {
    private let url: URL
    private let onComplete: (URL?) -> Void

    init(url: URL, onComplete: @escaping (URL?) -> Void) {
        self.url = url
        self.onComplete = onComplete
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAuthSession()
    }

    private func startAuthSession() {
        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "oak"
        ) { [weak self] callbackURL, error in
            if let error {
                print("Bank auth error: \(error.localizedDescription)")
                self?.onComplete(nil)
                return
            }
            self?.onComplete(callbackURL)
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }
}

extension WebAuthViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }
}
