import CoreGraphics
import XCTest
@testable import TrueKeep

final class PhotoThumbnailRequestKeyTests: XCTestCase {
    func testBuildsStablePixelCacheKeyFromAssetAndScaledSize() {
        let key = PhotoThumbnailRequestKey(
            assetID: "asset-1",
            targetSize: CGSize(width: 42.2, height: 108.8),
            scale: 3
        )

        XCTAssertEqual(key.cacheKey, "asset-1@127x326")
        XCTAssertEqual(key.pixelSize, CGSize(width: 127, height: 326))
    }

    func testClampsEmptyTargetSizeToSinglePixel() {
        let key = PhotoThumbnailRequestKey(
            assetID: "asset-1",
            targetSize: .zero,
            scale: 3
        )

        XCTAssertEqual(key.cacheKey, "asset-1@1x1")
        XCTAssertEqual(key.pixelSize, CGSize(width: 1, height: 1))
    }
}
