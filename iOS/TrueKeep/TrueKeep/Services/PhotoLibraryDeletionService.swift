import Foundation
import Photos

protocol PhotoLibraryDeleting: Sendable {
    func deleteAssets(withLocalIdentifiers assetIDs: [String]) async -> PhotoDeletionResult
}

struct PhotoDeletionSafetyPolicy: Hashable, Sendable {
    static let deletionDisabledArgument = "-TrueKeepDisablePhotoDeletion"
    static let deletionDisabledEnvironmentKey = "TRUEKEEP_DISABLE_PHOTO_DELETION"
    static let destructiveDeletionEnabledArgument = "-TrueKeepEnableDestructivePhotoDeletion"
    static let destructiveDeletionEnabledEnvironmentKey = "TRUEKEEP_ENABLE_DESTRUCTIVE_PHOTO_DELETION"

    var isDeletionDisabled: Bool

    init(isDeletionDisabled: Bool) {
        self.isDeletionDisabled = isDeletionDisabled
    }

    static var current: PhotoDeletionSafetyPolicy {
        resolved(
            arguments: ProcessInfo.processInfo.arguments,
            environment: ProcessInfo.processInfo.environment,
            isDebugBuild: isDebugBuild
        )
    }

    static func resolved(
        arguments: [String],
        environment: [String: String],
        isDebugBuild: Bool
    ) -> PhotoDeletionSafetyPolicy {
        if arguments.contains(deletionDisabledArgument) || environment[deletionDisabledEnvironmentKey] == "1" {
            return PhotoDeletionSafetyPolicy(isDeletionDisabled: true)
        }

        let destructiveDeletionEnabled = arguments.contains(destructiveDeletionEnabledArgument)
            || environment[destructiveDeletionEnabledEnvironmentKey] == "1"

        if isDebugBuild && !destructiveDeletionEnabled {
            return PhotoDeletionSafetyPolicy(isDeletionDisabled: true)
        }

        return PhotoDeletionSafetyPolicy(isDeletionDisabled: false)
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}

struct SystemPhotoLibraryDeletionService: PhotoLibraryDeleting {
    private let safetyPolicy: PhotoDeletionSafetyPolicy

    init(safetyPolicy: PhotoDeletionSafetyPolicy = .current) {
        self.safetyPolicy = safetyPolicy
    }

    func deleteAssets(withLocalIdentifiers assetIDs: [String]) async -> PhotoDeletionResult {
        guard !assetIDs.isEmpty else {
            return .success(deletedAssetIDs: [])
        }

        guard !safetyPolicy.isDeletionDisabled else {
            return .failure(
                assetIDs: assetIDs,
                message: "真机调试删除安全锁已开启，未删除任何照片或视频。"
            )
        }

        let assets = fetchAssets(withLocalIdentifiers: assetIDs)
        guard !assets.isEmpty else {
            return .failure(
                assetIDs: assetIDs,
                message: "没有找到可删除的照片或视频项目，可能已被移动、删除或权限发生变化。"
            )
        }

        do {
            try await performDeletion(for: assets)
            return PhotoDeletionResult.resolved(
                requestedAssetIDs: assetIDs,
                deletedAssetIDs: assets.map(\.localIdentifier),
                failureMessage: "部分项目未能删除，可能已被移动、删除或权限发生变化。"
            )
        } catch {
            return .failure(
                assetIDs: assetIDs,
                message: "Photos 删除失败：\(error.localizedDescription)"
            )
        }
    }

    private func fetchAssets(withLocalIdentifiers assetIDs: [String]) -> [PHAsset] {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    private func performDeletion(for assets: [PHAsset]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhotoLibraryDeletionError.unknown)
                }
            }
        }
    }
}

private enum PhotoLibraryDeletionError: LocalizedError {
    case unknown

    var errorDescription: String? {
        "系统未返回具体错误。"
    }
}
