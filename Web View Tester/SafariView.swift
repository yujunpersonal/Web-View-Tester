import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    let entersReaderIfAvailable: Bool
    let barCollapsingEnabled: Bool
    let dismissButtonStyleIndex: Int
    var onInitialRedirect: ((URL) -> Void)?

    private var dismissButtonStyle: SFSafariViewController.DismissButtonStyle {
        switch dismissButtonStyleIndex {
        case 0:
            return .done
        case 1:
            return .cancel
        default:
            return .close
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = entersReaderIfAvailable
        configuration.barCollapsingEnabled = barCollapsingEnabled

        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = dismissButtonStyle
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let parent: SafariView

        init(_ parent: SafariView) {
            self.parent = parent
        }

        func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {
            parent.onInitialRedirect?(URL)
        }
    }
}
