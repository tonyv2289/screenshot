import ImageIO
import SwiftUI
import UIKit

enum LocalImageCache {
    private static let cache = NSCache<NSURL, UIImage>()

    static func thumbnail(for url: URL, maxPixelSize: CGFloat = 420) -> UIImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key)
        return image
    }

    static func fullImage(for url: URL) -> UIImage? {
        UIImage(contentsOfFile: url.path)
    }
}

struct LocalThumbnailView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url, let image = LocalImageCache.thumbnail(for: url) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.89, green: 0.86, blue: 0.78), Color(red: 0.78, green: 0.76, blue: 0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "photo")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }
}