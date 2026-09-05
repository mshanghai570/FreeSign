import SwiftUI
import UIKit

/// Presents the system export sheet for a completed IPA. The user chooses the
/// receiving sideload tool (for example AltStore, SideStore, or Files); iOS
/// cannot install a local IPA directly without that receiving application.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
