import SwiftUI
import AuthenticationServices
import WebKit

private enum CallbackSource {
    case safariViewController
    case externalBrowser
}

private enum ResultItemKind {
    case asAuthURL(URL)
    case asAuthError(String)
    case wkURL(URL)
    case wkText(String)
    case wkHistory([NavigationHistoryEntry])
    case safari(URL)
    case safariHistory([NavigationHistoryEntry])
    case external(URL)
    case universal(URL)
}

private struct ResultItem: Identifiable {
    let id = UUID()
    let date: Date
    let kind: ResultItemKind
}

class AuthSessionManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published var callbackURL: URL?
    @Published var callbackCode: String?
    @Published var errorMessage: String?

    private var session: ASWebAuthenticationSession?

    func start(url: URL, callbackURLScheme: String?, ephemeral: Bool) {
        // Reset previous results
        callbackURL = nil
        callbackCode = nil
        errorMessage = nil

        session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme
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

        session?.prefersEphemeralWebBrowserSession = ephemeral
        session?.presentationContextProvider = self

        let started = session?.start() ?? false
        if !started {
            errorMessage = "session.start() returned false — failed to present"
            session = nil
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
        return scene.keyWindow ?? UIWindow(windowScene: scene)
    }
}

struct ContentView: View {
    private static let defaultURL = "https://peteryu.auth0.com/authorize?response_type=code&client_id=9qfn5VEiOfi9AsexmVmz07Je1IckdDkW&redirect_uri=dummy://login&scope=openid%20email"
    private static let savedURLKey = "savedURL"
    private static let freeLaunchLimit = 10

    @State private var urlString = UserDefaults.standard.string(forKey: savedURLKey) ?? defaultURL
    @State private var launchCount = KeychainHelper.launchCount
    @State private var showWebView = false
    @State private var showWebViewOptions = false
    @AppStorage("wk_showAddressBar") private var showWebViewAddressBar = false
    @AppStorage("wk_showNavigationBar") private var showWebViewNavigationBar = false
    @AppStorage("wk_showPageTitle") private var showWebViewPageTitle = true
    @AppStorage("wk_clearCookiesBeforeLaunch") private var clearWebViewCookiesBeforeLaunch = false
    @AppStorage("wk_javaScriptEnabled") private var webViewJavaScriptEnabled = true
    @AppStorage("wk_allowsBackForwardGestures") private var webViewAllowsBackForwardGestures = true
    @AppStorage("wk_allowsLinkPreview") private var webViewAllowsLinkPreview = true
    @AppStorage("wk_allowsInlineMediaPlayback") private var webViewAllowsInlineMediaPlayback = false
    @AppStorage("wk_useNonPersistentDataStore") private var webViewUseNonPersistentDataStore = false
    @State private var webViewListenURL = ""
    @State private var showAuthSchemeConfirm = false
    @State private var pendingAuthScheme = ""
    @AppStorage("as_ephemeralSession") private var pendingAuthEphemeral = false
    @State private var pendingAuthLaunch = false
    @State private var showSafariView = false
    @State private var showSafariOptions = false
    @State private var safariListenURL = ""
    @AppStorage("safari_entersReaderIfAvailable") private var safariEntersReaderIfAvailable = false
    @AppStorage("safari_barCollapsingEnabled") private var safariBarCollapsingEnabled = true
    @AppStorage("safari_dismissButtonStyleIndex") private var safariDismissButtonStyleIndex = 2
    @State private var pendingCallbackSource: CallbackSource?
    @State private var safariViewResultURL: URL?
    @State private var externalBrowserResultURL: URL?
    @State private var receivedUniversalLink: URL?
    @State private var showUniversalLinkAlert = false
    @State private var webViewResult: String?
    @State private var webViewHistory: [NavigationHistoryEntry] = []
    @State private var safariHistory: [NavigationHistoryEntry] = []
    @State private var authResultUpdatedAt: Date?
    @State private var webViewResultUpdatedAt: Date?
    @State private var webViewHistoryUpdatedAt: Date?
    @State private var safariResultUpdatedAt: Date?
    @State private var safariHistoryUpdatedAt: Date?
    @State private var externalResultUpdatedAt: Date?
    @State private var universalLinkUpdatedAt: Date?
    @State private var showPaywall = false
    @State private var showProStatus = false
    @StateObject private var authManager = AuthSessionManager()
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @FocusState private var isURLEditorFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Great Web View Tester")
                        .font(.largeTitle.bold())
                        .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter URL")
                            .font(.headline)
                        TextEditor(text: $urlString)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .focused($isURLEditorFocused)
                            .frame(minHeight: 80, maxHeight: 150)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .scrollContentBackground(.hidden)
                            .padding(4)
                    }
                    .padding(.horizontal)
                    .onChange(of: urlString) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: ContentView.savedURLKey)
                    }

                    VStack(spacing: 12) {
                        HStack(spacing: 10) {
                            Button {
                                if canLaunch {
                                    let parsedScheme = parseRedirectURIScheme(from: urlString) ?? ""
                                    pendingAuthScheme = parsedScheme
                                    showAuthSchemeConfirm = true
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                Label("ASWebAuthentication", systemImage: "person.badge.key")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .disabled(URL(string: urlString) == nil)

                            Button {
                                if canLaunch {
                                    // Keep persisted WK settings; only refresh dynamic listen URL.
                                    webViewListenURL = parseRedirectURI(from: urlString) ?? ""
                                    showWebViewOptions = true
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                Label("WKWebView", systemImage: "globe")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(URL(string: urlString) == nil)
                        }

                        HStack(spacing: 10) {
                            Button {
                                if canLaunch {
                                    guard URL(string: urlString) != nil else { return }
                                    // Keep persisted Safari settings; only refresh dynamic listen URL.
                                    safariListenURL = parseRedirectURI(from: urlString) ?? ""
                                    showSafariOptions = true
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                Label("SFSafariViewController", systemImage: "safari")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(URL(string: urlString) == nil)

                            Button {
                                if canLaunch {
                                    guard let url = URL(string: urlString) else { return }
                                    recordLaunch()
                                    pendingCallbackSource = .externalBrowser
                                    UIApplication.shared.open(url)
                                } else {
                                    showPaywall = true
                                }
                            } label: {
                                Label("External Browser", systemImage: "arrow.up.forward.app")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                            .disabled(URL(string: urlString) == nil)
                        }

                        if !subscriptionManager.isPro {
                            Text("\(freeLaunchesRemaining) free launch\(freeLaunchesRemaining == 1 ? "" : "es") remaining")
                                .font(.caption)
                                .foregroundStyle(freeLaunchesRemaining <= 3 ? .red : .secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Unlock Unlimited Usage button (only for non-pro users)
                    if !subscriptionManager.isPro {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.open.fill")
                                    .font(.title3)
                                Text("Unlock Unlimited Usage")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }

                    // Result section
                    resultSection
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showWebViewOptions) {
                NavigationStack {
                    Form {
                        Section("Listen On") {
                            TextField("Listen On", text: $webViewListenURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Section {
                            Button {
                                recordLaunch()
                                showWebViewOptions = false
                                if clearWebViewCookiesBeforeLaunch {
                                    clearWKWebsiteData {
                                        showWebView = true
                                    }
                                } else {
                                    showWebView = true
                                }
                            } label: {
                                Text("Launch")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Section("Common Settings") {
                            HStack(spacing: 12) {
                                Toggle("Clear Cookies", isOn: $clearWebViewCookiesBeforeLaunch)
                                Toggle("Show URL Bar", isOn: $showWebViewAddressBar)
                            }
                            HStack(spacing: 12) {
                                Toggle("Show Nav Bar", isOn: $showWebViewNavigationBar)
                                Toggle("Show Page Title", isOn: $showWebViewPageTitle)
                            }
                        }

                        Section("More Settings") {
                            HStack(spacing: 12) {
                                Toggle("JavaScript", isOn: $webViewJavaScriptEnabled)
                                Toggle("Back/Forward", isOn: $webViewAllowsBackForwardGestures)
                            }
                            HStack(spacing: 12) {
                                Toggle("Link Preview", isOn: $webViewAllowsLinkPreview)
                                Toggle("Inline Media", isOn: $webViewAllowsInlineMediaPlayback)
                            }
                            HStack(spacing: 12) {
                                Toggle("Non-Persistent", isOn: $webViewUseNonPersistentDataStore)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .environment(\.defaultMinListRowHeight, 34)
                    .font(.footnote)
                    .navigationTitle("WKWebView Options")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showWebViewOptions = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showWebView) {
                NavigationStack {
                    WebViewScreen(
                        urlString: urlString,
                        showAddressBar: showWebViewAddressBar,
                        showNavigationBar: showWebViewNavigationBar,
                        showPageTitle: showWebViewPageTitle,
                        javaScriptEnabled: webViewJavaScriptEnabled,
                        allowsBackForwardGestures: webViewAllowsBackForwardGestures,
                        allowsLinkPreview: webViewAllowsLinkPreview,
                        allowsInlineMediaPlayback: webViewAllowsInlineMediaPlayback,
                        useNonPersistentDataStore: webViewUseNonPersistentDataStore,
                        listenURL: webViewListenURL,
                        onResult: { result, history in
                    webViewResult = result
                    webViewHistory = history
                    webViewResultUpdatedAt = Date()
                    if !history.isEmpty {
                        webViewHistoryUpdatedAt = Date()
                    }
                        }
                    )
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showSafariView, onDismiss: {
                if pendingCallbackSource == .safariViewController {
                    pendingCallbackSource = nil
                }
            }) {
                if let url = URL(string: urlString) {
                    SafariView(
                        url: url,
                        entersReaderIfAvailable: safariEntersReaderIfAvailable,
                        barCollapsingEnabled: safariBarCollapsingEnabled,
                        dismissButtonStyleIndex: safariDismissButtonStyleIndex,
                        onInitialRedirect: { redirectedURL in
                            appendSafariHistory(url: redirectedURL, type: "redirect")
                        }
                    )
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $showSafariOptions) {
                NavigationStack {
                    Form {
                        Section("Listen On") {
                            TextField("Listen On", text: $safariListenURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Section {
                            Button {
                                recordLaunch()
                                pendingCallbackSource = .safariViewController
                                safariHistory = []
                                if let initialURL = URL(string: urlString) {
                                    appendSafariHistory(url: initialURL, type: "request")
                                }
                                showSafariOptions = false
                                showSafariView = true
                            } label: {
                                Text("Launch")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }

                        Section("Other Settings") {
                            HStack(spacing: 12) {
                                Toggle("Reader If Available", isOn: $safariEntersReaderIfAvailable)
                                Toggle("Bar Collapsing", isOn: $safariBarCollapsingEnabled)
                            }

                            Picker("Dismiss Button Style", selection: $safariDismissButtonStyleIndex) {
                                Text("Done").tag(0)
                                Text("Cancel").tag(1)
                                Text("Close").tag(2)
                            }
                            .pickerStyle(.menu)

                            Text("Safari controls its own address and navigation bars. Those cannot be hidden.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .environment(\.defaultMinListRowHeight, 34)
                    .font(.footnote)
                    .navigationTitle("SFSafari Options")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showSafariOptions = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onOpenURL { url in
                receivedUniversalLink = url
                switch pendingCallbackSource {
                case .safariViewController:
                    appendSafariHistory(url: url, type: "redirect")
                    safariViewResultURL = url
                    safariResultUpdatedAt = Date()

                    let listen = safariListenURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    if listen.isEmpty || url.absoluteString.hasPrefix(listen) {
                        showSafariView = false
                        pendingCallbackSource = nil
                    }
                case .externalBrowser:
                    externalBrowserResultURL = url
                    externalResultUpdatedAt = Date()
                    pendingCallbackSource = nil
                case .none:
                    break
                }
                universalLinkUpdatedAt = Date()
                showUniversalLinkAlert = true
            }
            .alert("Universal Link Received", isPresented: $showUniversalLinkAlert) {
                Button("OK") {}
            } message: {
                Text(receivedUniversalLink?.absoluteString ?? "")
            }
            .sheet(isPresented: $showAuthSchemeConfirm, onDismiss: {
                guard pendingAuthLaunch else { return }
                pendingAuthLaunch = false
                recordLaunch()
                if let url = URL(string: urlString) {
                    let trimmedScheme = pendingAuthScheme.trimmingCharacters(in: .whitespacesAndNewlines)
                    authManager.start(url: url, callbackURLScheme: trimmedScheme.isEmpty ? nil : trimmedScheme, ephemeral: pendingAuthEphemeral)
                }
            }) {
                NavigationStack {
                    Form {
                        Section("Callback URL Scheme") {
                            TextField("Callback Scheme", text: $pendingAuthScheme)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Section {
                            Button {
                                pendingAuthLaunch = true
                                showAuthSchemeConfirm = false
                            } label: {
                                Text("Launch")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }

                        Section("Common Settings") {
                            Toggle("Ephemeral Session", isOn: $pendingAuthEphemeral)
                        }
                    }
                    .environment(\.defaultMinListRowHeight, 34)
                    .font(.footnote)
                    .navigationTitle("ASWebAuth Options")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showAuthSchemeConfirm = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .toolbar {
                if subscriptionManager.isPro {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showProStatus = true
                        } label: {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(
                                    subscriptionManager.isLifetimeVIP || subscriptionManager.isUnlockedByCode
                                        ? .yellow
                                        : Color(.systemGray3)
                                )
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showProStatus) {
                ProStatusView()
            }
            .onChange(of: authManager.callbackURL) { _, newValue in
                if newValue != nil {
                    authResultUpdatedAt = Date()
                }
            }
            .onChange(of: authManager.errorMessage) { _, newValue in
                if newValue != nil {
                    authResultUpdatedAt = Date()
                }
            }
        }
    }

    private func parseRedirectURIScheme(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let redirectURI = components.queryItems?.first(where: { $0.name == "redirect_uri" })?.value,
              let redirectURL = URL(string: redirectURI) else {
            return nil
        }
        return redirectURL.scheme
    }

    private func parseRedirectURI(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let redirectURI = components.queryItems?.first(where: { $0.name == "redirect_uri" })?.value,
              !redirectURI.isEmpty else {
            return nil
        }
        return redirectURI
    }

    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Results")
                    .font(.headline)
                Spacer()
                if hasResults {
                    Button("Clear") {
                        clearResults()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

            let items = orderedResultItems
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                resultItemView(item.kind)
                if index < items.count - 1 {
                    Divider()
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func resultItemView(_ kind: ResultItemKind) -> some View {
        switch kind {
        case .asAuthURL(let url):
            urlResultCard(title: "ASWebAuthenticationSession", color: .green, url: url)
        case .asAuthError(let error):
            resultCard(title: "ASWebAuthenticationSession", color: .red, items: [("Error", error)])
        case .wkURL(let url):
            urlResultCard(title: "WKWebView", color: .blue, url: url)
        case .wkText(let text):
            resultCard(title: "WKWebView", color: .blue, items: [("Last URL", text)])
        case .wkHistory(let history):
            navigationHistoryCard(title: "WKWebView Navigation History", color: .blue, history: history)
        case .safari(let url):
            urlResultCard(title: "SFSafariViewController", color: .orange, url: url)
        case .safariHistory(let history):
            navigationHistoryCard(title: "SFSafariViewController Navigation History", color: .orange, history: history)
        case .external(let url):
            urlResultCard(title: "External Browser", color: .indigo, url: url)
        case .universal(let url):
            urlResultCard(title: "Universal Link", color: .orange, url: url)
        }
    }

    private var orderedResultItems: [ResultItem] {
        var items: [ResultItem] = []

        if let url = authManager.callbackURL {
            items.append(ResultItem(date: authResultUpdatedAt ?? .distantPast, kind: .asAuthURL(url)))
        } else if let error = authManager.errorMessage {
            items.append(ResultItem(date: authResultUpdatedAt ?? .distantPast, kind: .asAuthError(error)))
        }

        if let result = webViewResult, let url = URL(string: result) {
            items.append(ResultItem(date: webViewResultUpdatedAt ?? .distantPast, kind: .wkURL(url)))
        } else if let result = webViewResult {
            items.append(ResultItem(date: webViewResultUpdatedAt ?? .distantPast, kind: .wkText(result)))
        }

        if !webViewHistory.isEmpty {
            let historyDate: Date
            if let resultDate = webViewResultUpdatedAt {
                // Keep final WK URL result above captured redirects/history.
                historyDate = resultDate.addingTimeInterval(-0.001)
            } else {
                historyDate = webViewHistoryUpdatedAt ?? .distantPast
            }
            items.append(ResultItem(date: historyDate, kind: .wkHistory(webViewHistory)))
        }

        if let safariURL = safariViewResultURL {
            items.append(ResultItem(date: safariResultUpdatedAt ?? .distantPast, kind: .safari(safariURL)))
        }

        if !safariHistory.isEmpty {
            items.append(ResultItem(date: safariHistoryUpdatedAt ?? .distantPast, kind: .safariHistory(safariHistory)))
        }

        if let externalURL = externalBrowserResultURL {
            items.append(ResultItem(date: externalResultUpdatedAt ?? .distantPast, kind: .external(externalURL)))
        }

        if let link = receivedUniversalLink {
            items.append(ResultItem(date: universalLinkUpdatedAt ?? .distantPast, kind: .universal(link)))
        }

        return items.sorted { $0.date > $1.date }
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func urlResultCard(title: String, color: Color, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(color)

            // Full URL
            VStack(alignment: .leading, spacing: 2) {
                Text("Full URL")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(url.absoluteString)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            // Parameters
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems, !queryItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Parameters")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(queryItems, id: \.name) { item in
                        HStack(alignment: .top, spacing: 4) {
                            Text("\(item.name):")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(item.value ?? "nil")
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding(.leading, 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func navigationHistoryCard(title: String, color: Color, history: [NavigationHistoryEntry]) -> some View {
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss.SSS"
            return f
        }()

        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(color)

            Text("\(history.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                HStack(alignment: .top, spacing: 6) {
                    Text("\(index + 1)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .trailing)

                    typeBadge(entry.type)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.url)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(3)
                        Text(formatter.string(from: entry.timestamp))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func typeBadge(_ type: String) -> some View {
        let (label, badgeColor): (String, Color) = switch type {
        case "request":  ("REQ", .gray)
        case "start":    ("START", .blue)
        case "redirect": ("30x", .orange)
        case "loaded":   ("DONE", .green)
        case "error":    ("ERR", .red)
        default:         (type.uppercased(), .gray)
        }

        return Text(label)
            .font(.system(.caption2, design: .monospaced).bold())
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(badgeColor.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var hasResults: Bool {
        authManager.callbackURL != nil ||
        authManager.errorMessage != nil ||
        webViewResult != nil ||
        !webViewHistory.isEmpty ||
        safariViewResultURL != nil ||
        !safariHistory.isEmpty ||
        externalBrowserResultURL != nil ||
        receivedUniversalLink != nil
    }

    private var freeLaunchesRemaining: Int {
        max(ContentView.freeLaunchLimit - launchCount, 0)
    }

    private var isAllowlistedURL: Bool {
        urlString.hasPrefix("https://peteryu.auth0.com")
    }

    private var canLaunch: Bool {
        subscriptionManager.isPro || isAllowlistedURL || launchCount < ContentView.freeLaunchLimit
    }

    private func recordLaunch() {
        launchCount += 1
        KeychainHelper.launchCount = launchCount
    }

    private func clearResults() {
        authManager.callbackURL = nil
        authManager.callbackCode = nil
        authManager.errorMessage = nil
        webViewResult = nil
        webViewHistory = []
        safariViewResultURL = nil
        safariHistory = []
        externalBrowserResultURL = nil
        receivedUniversalLink = nil
        authResultUpdatedAt = nil
        webViewResultUpdatedAt = nil
        webViewHistoryUpdatedAt = nil
        safariResultUpdatedAt = nil
        safariHistoryUpdatedAt = nil
        externalResultUpdatedAt = nil
        universalLinkUpdatedAt = nil
        pendingCallbackSource = nil
    }

    private func appendSafariHistory(url: URL, type: String) {
        let entry = NavigationHistoryEntry(url: url.absoluteString, type: type, timestamp: Date())
        safariHistory.append(entry)
        safariHistoryUpdatedAt = Date()
    }

    private func dismissKeyboard() {
        // Use UIKit responder chain to avoid focus-transition constraint churn in TextEditor.
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isURLEditorFocused = false
    }

    private func clearWKWebsiteData(completion: @escaping () -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            dataStore.removeData(ofTypes: dataTypes, for: records) {
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }

}

#Preview {
    ContentView()
}
