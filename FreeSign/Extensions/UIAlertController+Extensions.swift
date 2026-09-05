import UIKit

// MARK: - UIAlertController Extensions

extension UIAlertController {
    
    /// Show an alert with a text field for user input
    static func showAlertWithTextBox(
        title: String,
        message: String? = nil,
        textFieldPlaceholder: String = "",
        textFieldText: String = "",
        submit: String = "OK",
        cancel: String = "Cancel",
        onSubmit: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = textFieldPlaceholder
            textField.text = textFieldText
            textField.autocapitalizationType = .sentences
            textField.clearButtonMode = .whileEditing
        }
        
        let submitAction = UIAlertAction(title: submit, style: .default) { _ in
            let text = alert.textFields?.first?.text ?? ""
            onSubmit(text)
        }
        
        let cancelAction = UIAlertAction(title: cancel, style: .cancel)
        
        alert.addAction(submitAction)
        alert.addAction(cancelAction)
        
        // Enable submit only if text field has content
        if textFieldText.isEmpty {
            submitAction.isEnabled = false
            
            NotificationCenter.default.addObserver(
                forName: UITextField.textDidChangeNotification,
                object: alert.textFields?.first,
                queue: .main
            ) { _ in
                submitAction.isEnabled = !(alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            }
        }
        
        presentOnTop(alert)
    }
    
    /// Show a simple alert with OK button
    static func showAlertWithOk(
        title: String,
        message: String? = nil,
        okTitle: String = "OK",
        onOK: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: okTitle, style: .default) { _ in
            onOK?()
        }
        alert.addAction(okAction)
        presentOnTop(alert)
    }
    
    /// Show an action sheet with multiple options
    static func showActionSheet(
        title: String? = nil,
        message: String? = nil,
        actions: [(String, UIAlertAction.Style, () -> Void)],
        sourceView: UIView? = nil,
        sourceRect: CGRect? = nil
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        for (title, style, handler) in actions {
            let action = UIAlertAction(title: title, style: style) { _ in
                handler()
            }
            alert.addAction(action)
        }
        
        // For iPad support
        if let sourceView = sourceView {
            alert.popoverPresentationController?.sourceView = sourceView
            alert.popoverPresentationController?.sourceRect = sourceRect ?? sourceView.bounds
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first {
            alert.popoverPresentationController?.sourceView = window
            alert.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
        }
        
        presentOnTop(alert)
    }
    
    /// Present an alert on the top-most view controller
    private static func presentOnTop(_ alert: UIAlertController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        var topVC = rootVC
        while let presentedVC = topVC.presentedViewController {
            topVC = presentedVC
        }
        
        topVC.present(alert, animated: true)
    }
}