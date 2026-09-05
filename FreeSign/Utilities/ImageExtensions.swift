import UIKit

// MARK: - UIImage Extensions

extension UIImage {

    /// Resizes the image to a square aspect, matching app icon proportions.
    func resizeToSquare(size: CGFloat = 1024) -> UIImage? {
        let targetSize = CGSize(width: size, height: size)

        // Calculate the scaling factor to fill the square
        let widthScale = targetSize.width / size
        let heightScale = targetSize.height / size
        let scale = max(widthScale, heightScale)

        let scaledSize = CGSize(width: size * scale, height: size * scale)

        // Center crop
        let drawRect = CGRect(
            x: (targetSize.width - scaledSize.width) / 2,
            y: (targetSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }

        self.draw(in: drawRect)
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Creates a placeholder image with a colored background and system icon.
    static func placeholderIcon(systemName: String, color: UIColor, size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let color = UIColor(AppColors.accent)
            ctx.fill(CGRect(origin: .zero, size: size))

            let imageSize = CGSize(width: size.width * 0.5, height: size.height * 0.5)
            let imageOrigin = CGPoint(x: (size.width - imageSize.width) / 2, y: (size.height - imageSize.height) / 2)
            let imageRect = CGRect(origin: imageOrigin, size: imageSize)

            if let img = UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)) {
                img.draw(in: imageRect)
            }
        }
    }
}
