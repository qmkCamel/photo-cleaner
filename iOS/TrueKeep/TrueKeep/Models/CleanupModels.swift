import Foundation
import SwiftUI

enum CleanupCategory: String, CaseIterable, Identifiable, Hashable {
    case similar
    case screenshots
    case accidental
    case blurry
    case largeVideos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .similar: "相似连拍"
        case .screenshots: "截图和聊天截图"
        case .accidental: "可能是误拍"
        case .blurry: "模糊或遮挡"
        case .largeVideos: "占空间的大视频"
        }
    }

    var systemImage: String {
        switch self {
        case .similar: "rectangle.on.rectangle"
        case .screenshots: "photo.on.rectangle"
        case .accidental: "camera"
        case .blurry: "camera.filters"
        case .largeVideos: "video"
        }
    }
}

enum CandidateConfidence: String, Hashable {
    case high
    case medium
    case low

    var label: String {
        switch self {
        case .high: "推荐复核"
        case .medium: "建议复核"
        case .low: "低置信度"
        }
    }
}

struct ThumbnailStyle: Hashable {
    var symbolName: String
    var topColor: Color
    var bottomColor: Color
}

struct CleanupCandidate: Identifiable, Hashable {
    var id: String
    var category: CleanupCategory
    var confidence: CandidateConfidence
    var defaultSelectedForDeletion: Bool
    var recommendedKeep: Bool
    var reason: String
    var estimatedBytes: Int64
    var thumbnail: ThumbnailStyle
    var thumbnailAssetID: String? = nil
}

struct CleanupGroup: Identifiable, Hashable {
    var id: String
    var category: CleanupCategory
    var title: String
    var subtitle: String
    var groupIndex: Int
    var totalGroups: Int
    var explanation: String
    var candidates: [CleanupCandidate]

    var estimatedBytes: Int64 {
        candidates
            .filter { !$0.recommendedKeep }
            .map(\.estimatedBytes)
            .reduce(0, +)
    }
}

struct CleanupTask: Identifiable, Hashable {
    var id: String
    var category: CleanupCategory
    var description: String
    var candidateCount: Int
    var estimatedBytes: Int64
    var confidenceLabel: String
    var previewCandidates: [CleanupCandidate]
}

struct ReviewBinItem: Identifiable, Hashable {
    var id: String { candidate.id }
    var candidate: CleanupCandidate
    var selectedForDelete: Bool
    var addedAt: Date
}

enum PhotoDeletionResult: Hashable, Sendable {
    case success(deletedAssetIDs: [String])
    case partial(deletedAssetIDs: [String], failedAssetIDs: [String], message: String)
    case failure(assetIDs: [String], message: String)

    static func resolved(
        requestedAssetIDs: [String],
        deletedAssetIDs: [String],
        failureMessage: String
    ) -> PhotoDeletionResult {
        let deletedIDSet = Set(deletedAssetIDs)
        let failedAssetIDs = requestedAssetIDs.filter { !deletedIDSet.contains($0) }

        if deletedAssetIDs.isEmpty {
            return .failure(assetIDs: requestedAssetIDs, message: failureMessage)
        }

        if failedAssetIDs.isEmpty {
            return .success(deletedAssetIDs: deletedAssetIDs)
        }

        return .partial(
            deletedAssetIDs: deletedAssetIDs,
            failedAssetIDs: failedAssetIDs,
            message: failureMessage
        )
    }
}

struct CleanupFlowState: Hashable {
    var tasks: [CleanupTask]
    var reviewGroups: [CleanupGroup]
    var currentReviewGroupIndex: Int
    var selectedCandidateIDs: Set<String>
    var reviewBinItems: [ReviewBinItem]
    var hasDeletedItems: Bool
    var postDeletionRecoveryMessage: String?
    var deletionErrorMessage: String?

    var currentReviewGroup: CleanupGroup {
        reviewGroups[currentReviewGroupIndex]
    }

    var currentReviewSelectionCount: Int {
        selectedCandidateIDs.count
    }

    var totalEstimatedBytes: Int64 {
        tasks.map(\.estimatedBytes).reduce(0, +)
    }

    var selectedReviewBinAssetIDs: [String] {
        reviewBinItems
            .filter(\.selectedForDelete)
            .map(\.id)
    }

    var canMoveToPreviousReviewGroup: Bool {
        currentReviewGroupIndex > 0
    }

    var canMoveToNextReviewGroup: Bool {
        currentReviewGroupIndex < reviewGroups.count - 1
    }

    mutating func toggleReviewCandidate(_ candidate: CleanupCandidate) {
        guard !candidate.recommendedKeep else { return }
        if selectedCandidateIDs.contains(candidate.id) {
            selectedCandidateIDs.remove(candidate.id)
        } else {
            selectedCandidateIDs.insert(candidate.id)
        }
    }

    mutating func selectAllCandidatesInCurrentGroup() {
        selectedCandidateIDs = Set(currentReviewGroup.candidates.filter { !$0.recommendedKeep }.map(\.id))
    }

    @discardableResult
    mutating func selectReviewGroup(for category: CleanupCategory) -> Bool {
        guard let index = reviewGroups.firstIndex(where: { $0.category == category }) else {
            selectedCandidateIDs.removeAll()
            return false
        }

        currentReviewGroupIndex = index
        selectDefaultCandidatesInCurrentGroup()
        return true
    }

    @discardableResult
    mutating func moveToPreviousReviewGroup() -> Bool {
        guard canMoveToPreviousReviewGroup else { return false }
        currentReviewGroupIndex -= 1
        selectDefaultCandidatesInCurrentGroup()
        return true
    }

    @discardableResult
    mutating func moveToNextReviewGroup() -> Bool {
        guard canMoveToNextReviewGroup else { return false }
        currentReviewGroupIndex += 1
        selectDefaultCandidatesInCurrentGroup()
        return true
    }

    mutating func addCurrentSelectionToReviewBin() {
        let alreadyAdded = Set(reviewBinItems.map(\.candidate.id))
        let selectedCandidates = currentReviewGroup.candidates.filter { candidate in
            selectedCandidateIDs.contains(candidate.id) && !alreadyAdded.contains(candidate.id)
        }

        reviewBinItems.append(
            contentsOf: selectedCandidates.map {
                ReviewBinItem(candidate: $0, selectedForDelete: true, addedAt: Date())
            }
        )
    }

    mutating func toggleReviewBinItem(_ item: ReviewBinItem) {
        guard let index = reviewBinItems.firstIndex(where: { $0.id == item.id }) else { return }
        reviewBinItems[index].selectedForDelete.toggle()
        deletionErrorMessage = nil
    }

    mutating func restoreSelectedReviewBinItems() {
        reviewBinItems.removeAll { $0.selectedForDelete }
        deletionErrorMessage = nil
    }

    mutating func confirmDeletion() {
        applyDeletionResult(.success(deletedAssetIDs: selectedReviewBinAssetIDs))
    }

    mutating func applyDeletionResult(_ result: PhotoDeletionResult) {
        switch result {
        case .success(let deletedAssetIDs):
            removeDeletedReviewBinItems(deletedAssetIDs)
            deletionErrorMessage = nil
            markDeletedIfNeeded(deletedAssetIDs)
        case .partial(let deletedAssetIDs, let failedAssetIDs, let message):
            removeDeletedReviewBinItems(deletedAssetIDs)
            selectFailedReviewBinItems(failedAssetIDs)
            deletionErrorMessage = message
            markDeletedIfNeeded(deletedAssetIDs)
        case .failure(_, let message):
            deletionErrorMessage = message
        }
    }

    private mutating func removeDeletedReviewBinItems(_ deletedAssetIDs: [String]) {
        let deletedIDs = Set(deletedAssetIDs)
        reviewBinItems.removeAll { deletedIDs.contains($0.id) }
    }

    private mutating func selectDefaultCandidatesInCurrentGroup() {
        selectedCandidateIDs = Set(currentReviewGroup.candidates.filter(\.defaultSelectedForDeletion).map(\.id))
    }

    private mutating func selectFailedReviewBinItems(_ failedAssetIDs: [String]) {
        let failedIDs = Set(failedAssetIDs)
        for index in reviewBinItems.indices {
            if failedIDs.contains(reviewBinItems[index].id) {
                reviewBinItems[index].selectedForDelete = true
            }
        }
    }

    private mutating func markDeletedIfNeeded(_ deletedAssetIDs: [String]) {
        guard !deletedAssetIDs.isEmpty else { return }
        hasDeletedItems = true
        postDeletionRecoveryMessage = "所选项目已移入 Photos 的 Recently Deleted。建议保留恢复窗口，不要立即清空。"
    }
}

extension Int64 {
    var formattedStorage: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
