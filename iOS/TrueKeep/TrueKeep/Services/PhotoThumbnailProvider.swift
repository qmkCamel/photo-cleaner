import CoreGraphics
@preconcurrency import Photos
@preconcurrency import UIKit

typealias PhotoThumbnailRequestID = PHImageRequestID

struct PhotoThumbnailRequestKey: Hashable, Sendable {
    var assetID: String
    var pixelWidth: Int
    var pixelHeight: Int

    init(assetID: String, targetSize: CGSize, scale: CGFloat) {
        self.assetID = assetID
        self.pixelWidth = Self.pixelLength(for: targetSize.width, scale: scale)
        self.pixelHeight = Self.pixelLength(for: targetSize.height, scale: scale)
    }

    var cacheKey: String {
        "\(assetID)@\(pixelWidth)x\(pixelHeight)"
    }

    var pixelSize: CGSize {
        CGSize(width: pixelWidth, height: pixelHeight)
    }

    var nsCacheKey: NSString {
        cacheKey as NSString
    }

    private static func pixelLength(for length: CGFloat, scale: CGFloat) -> Int {
        guard length.isFinite, scale.isFinite else { return 1 }
        return max(1, Int((length * max(scale, 1)).rounded()))
    }
}

@MainActor
protocol PhotoThumbnailProviding: AnyObject {
    func cachedImage(for key: PhotoThumbnailRequestKey) -> UIImage?

    @discardableResult
    func requestImage(
        for key: PhotoThumbnailRequestKey,
        completion: @escaping @MainActor (UIImage?) -> Void
    ) -> PhotoThumbnailRequestID?

    func cancelRequest(_ requestID: PhotoThumbnailRequestID)
}

@MainActor
final class SystemPhotoThumbnailProvider: PhotoThumbnailProviding {
    static let shared = SystemPhotoThumbnailProvider()

    private let imageManager: PHCachingImageManager
    private let cache: NSCache<NSString, UIImage>

    init(
        imageManager: PHCachingImageManager = PHCachingImageManager(),
        cache: NSCache<NSString, UIImage> = NSCache<NSString, UIImage>()
    ) {
        self.imageManager = imageManager
        self.cache = cache
        self.cache.countLimit = 240
    }

    func cachedImage(for key: PhotoThumbnailRequestKey) -> UIImage? {
        cache.object(forKey: key.nsCacheKey)
    }

    @discardableResult
    func requestImage(
        for key: PhotoThumbnailRequestKey,
        completion: @escaping @MainActor (UIImage?) -> Void
    ) -> PhotoThumbnailRequestID? {
        if let cachedImage = cachedImage(for: key) {
            completion(cachedImage)
            return nil
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [key.assetID], options: nil)
        guard let asset = assets.firstObject else {
            completion(nil)
            return nil
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false

        return imageManager.requestImage(
            for: asset,
            targetSize: key.pixelSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, info in
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) == true
            let hasError = info?[PHImageErrorKey] != nil

            Task { @MainActor in
                guard let self, !isCancelled, !hasError else {
                    completion(nil)
                    return
                }

                if let image {
                    self.cache.setObject(image, forKey: key.nsCacheKey)
                }
                completion(image)
            }
        }
    }

    func cancelRequest(_ requestID: PhotoThumbnailRequestID) {
        imageManager.cancelImageRequest(requestID)
    }
}
