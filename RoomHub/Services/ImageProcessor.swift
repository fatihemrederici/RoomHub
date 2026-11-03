import UIKit

/// Fotoğrafları Firestore'a sığacak küçük JPEG'lere çevirir.
/// Firebase Storage ücretli plana geçmeyi gerektirdiği için fotoğraflar base64 olarak
/// Firestore dokümanında tutulur; bu yüzden boyut küçük tutulmalı (~30-60 KB).
enum ImageProcessor {
    static func squareJPEG(from image: UIImage, side: CGFloat = 256, maxBytes: Int = 120_000) -> Data? {
        let targetSize = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let squared = renderer.image { _ in
            let size = image.size
            guard size.width > 0, size.height > 0 else { return }
            let scale = max(targetSize.width / size.width, targetSize.height / size.height)
            let scaled = CGSize(width: size.width * scale, height: size.height * scale)
            let origin = CGPoint(x: (targetSize.width - scaled.width) / 2,
                                 y: (targetSize.height - scaled.height) / 2)
            image.draw(in: CGRect(origin: origin, size: scaled))
        }
        
        var quality: CGFloat = 0.7
        var data = squared.jpegData(compressionQuality: quality)
        while let current = data, current.count > maxBytes, quality > 0.2 {
            quality -= 0.15
            data = squared.jpegData(compressionQuality: quality)
        }
        return data
    }
    
    static func image(fromBase64 base64: String?) -> UIImage? {
        guard let base64 = base64, let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}
