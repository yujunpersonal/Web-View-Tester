import SwiftUI
import WebKit

struct NavigationHistoryEntry: Identifiable {
    let id = UUID()
    let url: String
    let type: String      // "request", "start", "redirect", "loaded", "error"
    let timestamp: Date
}

struct WebViewScreen: View {
    let urlString: String
    let showAddressBar: Bool
    let showNavigationBar: Bool
    let showPageTitle: Bool
    let javaScriptEnabled: Bool
    let allowsBackForwardGestures: Bool
    let allowsLinkPreview: Bool
    let allowsInlineMediaPlayback: Bool
    let useNonPersistentDataStore: Bool
    let listenURL: String
    var onResult: ((String, [NavigationHistoryEntry]) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var pageTitle = ""
    @State private var currentURL = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webViewRef = WebViewRef()
    @State private var navigationHistory: [NavigationHistoryEntry] = []
    @State private var capturedResultURL: String?

    var body: some View {
        VStack(spacing: 0) {
            if showNavigationBar {
                // In-webview navigation controls.
                HStack(spacing: 16) {
                    Button {
                        webViewRef.webView?.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(!canGoBack)

                    Button {
                        webViewRef.webView?.goForward()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(!canGoForward)

                    Button {
                        webViewRef.webView?.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }

                    Spacer()

                    if isLoading {
                        ProgressView()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            if showAddressBar {
                Text(currentURL)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }

            WebView(
                urlString: urlString,
                javaScriptEnabled: javaScriptEnabled,
                allowsBackForwardGestures: allowsBackForwardGestures,
                allowsLinkPreview: allowsLinkPreview,
                allowsInlineMediaPlayback: allowsInlineMediaPlayback,
                useNonPersistentDataStore: useNonPersistentDataStore,
                listenURL: listenURL,
                webViewRef: webViewRef,
                isLoading: $isLoading,
                pageTitle: $pageTitle,
                currentURL: $currentURL,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                navigationHistory: $navigationHistory,
                onListenURLMatched: { matchedURL in
                    capturedResultURL = matchedURL
                    dismiss()
                }
            )
        }
        .navigationTitle(showPageTitle ? (pageTitle.isEmpty ? "Loading..." : pageTitle) : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onDisappear {
            onResult?(capturedResultURL ?? currentURL, navigationHistory)
        }
    }
}

class WebViewRef {
    var webView: WKWebView?
}

struct WebView: UIViewRepresentable {
    let urlString: String
    let javaScriptEnabled: Bool
    let allowsBackForwardGestures: Bool
    let allowsLinkPreview: Bool
    let allowsInlineMediaPlayback: Bool
    let useNonPersistentDataStore: Bool
    let listenURL: String
    let webViewRef: WebViewRef
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var currentURL: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var navigationHistory: [NavigationHistoryEntry]
    var onListenURLMatched: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = javaScriptEnabled
        config.allowsInlineMediaPlayback = allowsInlineMediaPlayback
        if useNonPersistentDataStore {
            config.websiteDataStore = .nonPersistent()
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = allowsBackForwardGestures
        webView.allowsLinkPreview = allowsLinkPreview
        webViewRef.webView = webView

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        private func recordNavigation(url: URL, type: String) {
            let entry = NavigationHistoryEntry(url: url.absoluteString, type: type, timestamp: Date())
            DispatchQueue.main.async {
                self.parent.navigationHistory.append(entry)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            if let url = webView.url {
                recordNavigation(url: url, type: "start")
            }
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            if let url = webView.url {
                recordNavigation(url: url, type: "redirect")
            }
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            if let url = webView.url {
                recordNavigation(url: url, type: "loaded")
            }
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            if let url = webView.url {
                recordNavigation(url: url, type: "error")
            }
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            if let url = webView.url {
                recordNavigation(url: url, type: "error")
            }
            updateState(webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("[WKWebView] Navigating to: \(url.absoluteString)")
                recordNavigation(url: url, type: "request")
                maybeAutoClose(for: url)
            }
            decisionHandler(.allow)
        }

        private func maybeAutoClose(for url: URL) {
            let listen = parent.listenURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !listen.isEmpty else { return }

            let current = url.absoluteString
            if current.hasPrefix(listen) {
                DispatchQueue.main.async {
                    self.parent.onListenURLMatched?(current)
                }
            }
        }

        private func updateState(_ webView: WKWebView) {
            parent.pageTitle = webView.title ?? ""
            parent.currentURL = webView.url?.absoluteString ?? ""
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }
    }
}
