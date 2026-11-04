import UIKit

/// Shrinks photos before they're stored, keeping iCloud usage small
/// (~300 KB per bartender instead of several MB straight off the camera).
enum ImageProcessor {
    static func prepare(_ image: UIImage) -> (photo: Data, thumbnail: Data)? {
        guard
            let photo = resized(image, maxDimension: 1600).jpegData(compressionQuality: 0.75),
            let thumbnail = squareThumbnail(image, side: 200).jpegData(compressionQuality: 0.7)
        else { return nil }
        return (photo, thumbnail)
    }

    static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static func squareThumbnail(_ image: UIImage, side: CGFloat) -> UIImage {
        let size = image.size
        let scale = side / min(size.width, size.height)
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: drawn))
        }
    }
}
