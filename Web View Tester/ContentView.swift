import SwiftUI
import AuthenticationServices

class AuthSessionManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var callbackURL: URL?
    @Published var callbackCode: String?
    @Published var errorMessage: String?

    private var session: ASWebAuthenticationSession?

    func start(url: URL) {
        // Reset previous results
        callbackURL = nil
        callbackCode = nil
        errorMessage = nil

        session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "ealogin"
        ) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    self?.errorMessage = "Error domain: \(error.domain)\nCode: \(error.code)\n\(error.localizedDescription)"
                } else if let callbackURL = callbackURL {
                    self?.callbackURL = callbackURL
                    // Parse the code from query parameters
                    if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                       let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                        self?.callbackCode = code
                    }
                } else {
                    self?.errorMessage = "No callback URL returned"
                }
                self?.session = nil
            }
        }

        session?.prefersEphemeralWebBrowserSession = true
        session?.presentationContextProvider = self

        let started = session?.start() ?? false
        if !started {
            errorMessage = "session.start() returned false — failed to present"
            session = nil
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

struct ContentView: View {
    @State private var urlString = "https://accounts.ea.com/connect/auth?client_id=xxxxx&response_type=code"
    @State private var showWebView = false
    @State private var receivedUniversalLink: URL?
    @State private var showUniversalLinkAlert = false
    @State private var webViewResult: String?
    @StateObject private var authManager = AuthSessionManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Web View Tester")
                        .font(.largeTitle.bold())
                        .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter URL")
                            .font(.headline)
                        TextField("https://example.com", text: $urlString)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 16) {
                        Button {
                            showWebView = true
                        } label: {
                            Label("Open in WKWebView", systemImage: "globe")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(URL(string: urlString) == nil)

                        Button {
                            if let url = URL(string: urlString) {
                                authManager.start(url: url)
                            }
                        } label: {
                            Label("Open in ASWebAuthenticationSession", systemImage: "person.badge.key")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(URL(string: urlString) == nil)
                    }
                    .padding(.horizontal)

                    // Result section
                    resultSection
                }
            }
            .navigationDestination(isPresented: $showWebView) {
                WebViewScreen(urlString: urlString, onResult: { result in
                    webViewResult = result
                })
            }
            .onOpenURL { url in
                receivedUniversalLink = url
                showUniversalLinkAlert = true
            }
            .alert("Universal Link Received", isPresented: $showUniversalLinkAlert) {
                Button("OK") {}
            } message: {
                Text(receivedUniversalLink?.absoluteString ?? "")
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Results")
                .font(.headline)

            // ASWebAuthenticationSession result
            if let code = authManager.callbackCode {
                resultCard(
                    title: "ASWebAuthenticationSession",
                    color: .green,
                    items: [
                        ("Code", code),
                        ("Callback URL", authManager.callbackURL?.absoluteString ?? "")
                    ]
                )
            } else if let url = authManager.callbackURL {
                resultCard(
                    title: "ASWebAuthenticationSession",
                    color: .green,
                    items: parseURLItems(url: url, prefix: "Callback URL")
                )
            } else if let error = authManager.errorMessage {
                resultCard(
                    title: "ASWebAuthenticationSession",
                    color: .red,
                    items: [("Error", error)]
                )
            }

            // WKWebView result
            if let result = webViewResult {
                resultCard(
                    title: "WKWebView",
                    color: .blue,
                    items: [("Last URL", result)]
                )
            }

            // Universal Link result
            if let link = receivedUniversalLink {
                resultCard(
                    title: "Universal Link",
                    color: .orange,
                    items: parseURLItems(url: link, prefix: "URL")
                )
            }
        }
        .padding(.horizontal)
    }

    private func resultCard(title: String, color: Color, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            ForEach(items, id: \.0) { key, value in
                VStack(alignment: .leading, spacing: 2) {
                    Text(key)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func parseURLItems(url: URL, prefix: String) -> [(String, String)] {
        var items: [(String, String)] = [(prefix, url.absoluteString)]
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                items.append((item.name, item.value ?? "nil"))
            }
        }
        return items
    }
}

#Preview {
    ContentView()
}
