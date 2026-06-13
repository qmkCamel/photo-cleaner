import XCTest
@testable import TrueKeep

final class PhotoLibraryScanPolicyTests: XCTestCase {
    func testUsesSmallerBatchSizeInLowPowerMode() {
        let standardPolicy = PhotoLibraryScanPolicy(
            isLowPowerModeEnabled: false,
            standardBatchSize: 200,
            lowPowerBatchSize: 50
        )
        let lowPowerPolicy = PhotoLibraryScanPolicy(
            isLowPowerModeEnabled: true,
            standardBatchSize: 200,
            lowPowerBatchSize: 50
        )

        XCTAssertEqual(standardPolicy.effectiveBatchSize, 200)
        XCTAssertEqual(lowPowerPolicy.effectiveBatchSize, 50)
    }

    func testUsesSmallerVisualClassificationLimitInLowPowerMode() {
        let standardPolicy = PhotoLibraryScanPolicy(
            isLowPowerModeEnabled: false,
            standardVisualClassificationLimit: 300,
            lowPowerVisualClassificationLimit: 80
        )
        let lowPowerPolicy = PhotoLibraryScanPolicy(
            isLowPowerModeEnabled: true,
            standardVisualClassificationLimit: 300,
            lowPowerVisualClassificationLimit: 80
        )

        XCTAssertEqual(standardPolicy.effectiveVisualClassificationLimit, 300)
        XCTAssertEqual(lowPowerPolicy.effectiveVisualClassificationLimit, 80)
    }

    func testBatchRangesCoverAllItemsWithoutOvershooting() {
        let ranges = PhotoAssetSnapshotBatcher.batchRanges(totalCount: 5, batchSize: 2)

        XCTAssertEqual(ranges.map { Array($0) }, [[0, 1], [2, 3], [4]])
    }

    func testBatchCollectStopsBeforeReadingWhenCancelled() async {
        var readIndexes: [Int] = []

        do {
            _ = try await PhotoAssetSnapshotBatcher.collect(
                totalCount: 3,
                batchSize: 2,
                shouldCancel: { true },
                itemAt: { index in
                    readIndexes.append(index)
                    return index
                }
            )
            XCTFail("Expected cancellation to throw before collecting snapshots.")
        } catch is CancellationError {
            XCTAssertTrue(readIndexes.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
