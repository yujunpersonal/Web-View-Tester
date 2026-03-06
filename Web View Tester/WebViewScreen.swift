import SwiftUI
import WebKit

struct WebViewScreen: View {
    let urlString: String
    var onResult: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var pageTitle = ""
    @State private var currentURL = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var webViewRef = WebViewRef()

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
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

            // Current URL display
            Text(currentURL)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 4)

            WebView(
                urlString: urlString,
                webViewRef: webViewRef,
                isLoading: $isLoading,
                pageTitle: $pageTitle,
                currentURL: $currentURL,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward
            )
        }
        .navigationTitle(pageTitle.isEmpty ? "Loading..." : pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            onResult?(currentURL)
        }
    }
}

class WebViewRef {
    var webView: WKWebView?
}

struct WebView: UIViewRepresentable {
    let urlString: String
    let webViewRef: WebViewRef
    @Binding var isLoading: Bool
    @Binding var pageTitle: String
    @Binding var currentURL: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
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

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            updateState(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            updateState(webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("[WKWebView] Navigating to: \(url.absoluteString)")
            }
            decisionHandler(.allow)
        }

        private func updateState(_ webView: WKWebView) {
            parent.pageTitle = webView.title ?? ""
            parent.currentURL = webView.url?.absoluteString ?? ""
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
        }
    }
}
