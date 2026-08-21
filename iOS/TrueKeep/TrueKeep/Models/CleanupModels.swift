import Foundation
import SwiftUI

enum PhotoScanDateRange: String, CaseIterable, Identifiable, Hashable, Sendable {
    case lastMonth
    case lastThreeMonths
    case all

    static let defaultValue: PhotoScanDateRange = .lastMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lastMonth: "近一个月"
        case .lastThreeMonths: "近三个月"
        case .all: "全部"
        }
    }

    var detail: String {
        switch self {
        case .lastMonth: "扫描最近一个自然月内拍摄的内容"
        case .lastThreeMonths: "扫描最近三个自然月内拍摄的内容"
        case .all: "全部可访问的照片和视频"
        }
    }

    func dateBounds(
        endingAt referenceDate: Date,
        calendar: Calendar = .current
    ) -> ClosedRange<Date>? {
        let monthOffset: Int
        switch self {
        case .lastMonth:
            monthOffset = -1
        case .lastThreeMonths:
            monthOffset = -3
        case .all:
            return nil
        }

        guard let lowerBound = calendar.date(
            byAdding: .month,
            value: monthOffset,
            to: referenceDate
        ) else {
            return nil
        }
        return lowerBound...referenceDate
    }

    func includes(
        creationDate: Date?,
        endingAt referenceDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let bounds = dateBounds(endingAt: referenceDate, calendar: calendar) else {
            return true
        }
        guard let creationDate else { return false }
        return bounds.contains(creationDate)
    }
}

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
    var isExactDuplicate: Bool = false
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

enum CleanupTaskBuilder {
    static func tasks(from groups: [CleanupGroup]) -> [CleanupTask] {
        groups.compactMap(task(from:))
    }

    static func task(from group: CleanupGroup) -> CleanupTask? {
        guard group.candidates.contains(where: { !$0.recommendedKeep }) else { return nil }

        return CleanupTask(
            id: group.id,
            category: group.category,
            description: taskDescription(
                for: group.category,
                count: group.candidates.count,
                isExactDuplicate: group.candidates.allSatisfy(\.isExactDuplicate)
            ),
            candidateCount: group.candidates.count,
            estimatedBytes: group.estimatedBytes,
            confidenceLabel: confidenceLabel(for: group.category),
            previewCandidates: Array(group.candidates.prefix(4))
        )
    }

    private static func taskDescription(
        for category: CleanupCategory,
        count: Int,
        isExactDuplicate: Bool
    ) -> String {
        switch category {
        case .screenshots:
            return "\(count) 张截图，优先复核临时内容"
        case .largeVideos:
            return "\(count) 个长视频或大视频，建议逐个确认"
        case .similar:
            if isExactDuplicate {
                return "\(count) 张本机确认内容完全相同的照片，已推荐保留一张"
            }
            return "\(count) 张本机识别的相似照片，已推荐保留一张"
        case .accidental:
            return "\(count) 张疑似误拍，低置信度复核"
        case .blurry:
            return "\(count) 张疑似模糊或遮挡，低置信度复核"
        }
    }

    private static func confidenceLabel(for category: CleanupCategory) -> String {
        switch category {
        case .screenshots:
            return "可快速清理"
        case .largeVideos:
            return "建议复核"
        case .similar:
            return "推荐复核"
        case .accidental, .blurry:
            return "谨慎复核"
        }
    }
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

struct PhotoDeletionSummary: Hashable, Sendable {
    private(set) var deletedAssetIDs: Set<String> = []
    private(set) var estimatedBytes: Int64 = 0

    var itemCount: Int {
        deletedAssetIDs.count
    }

    var recoveryMessage: String {
        "所选项目已移至 Photos 的“最近删除”。建议保留恢复窗口，不要立即清空。"
    }

    var detailMessage: String {
        "这些项目仍可在 Photos 中恢复，空间可能尚未立即释放。"
    }

    var accessibilityAnnouncement: String {
        "已移至最近删除，\(itemCount) 项，约 \(estimatedBytes.formattedStorage)。这些项目仍可恢复，空间可能尚未立即释放。"
    }

    mutating func record(
        deletedAssetIDs assetIDs: [String],
        candidatesByID: [String: CleanupCandidate]
    ) {
        for assetID in Set(assetIDs) where !deletedAssetIDs.contains(assetID) {
            deletedAssetIDs.insert(assetID)
            estimatedBytes += candidatesByID[assetID]?.estimatedBytes ?? 0
        }
    }
}

struct CleanupFlowState: Hashable {
    var tasks: [CleanupTask]
    var reviewGroups: [CleanupGroup]
    var currentReviewGroupIndex: Int
    var selectedCandidateIDs: Set<String>
    var reviewBinItems: [ReviewBinItem]
    var deletionSummary: PhotoDeletionSummary?
    var deletionErrorMessage: String?

    var hasDeletedItems: Bool {
        deletionSummary != nil
    }

    var postDeletionRecoveryMessage: String? {
        deletionSummary?.recoveryMessage
    }

    var currentReviewGroup: CleanupGroup {
        reviewGroups[currentReviewGroupIndex]
    }

    var currentReviewSelectionCount: Int {
        selectedCandidateIDs.count
    }

    var currentReviewSelectableCandidateIDs: Set<String> {
        Set(currentReviewGroup.candidates.filter { !$0.recommendedKeep }.map(\.id))
    }

    var canToggleAllCandidatesInCurrentGroup: Bool {
        !currentReviewSelectableCandidateIDs.isEmpty
    }

    var areAllCandidatesInCurrentGroupSelected: Bool {
        let selectableIDs = currentReviewSelectableCandidateIDs
        return !selectableIDs.isEmpty && selectableIDs.isSubset(of: selectedCandidateIDs)
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

    mutating func toggleAllCandidatesInCurrentGroup() {
        let selectableIDs = currentReviewSelectableCandidateIDs
        guard !selectableIDs.isEmpty else { return }

        if selectableIDs.isSubset(of: selectedCandidateIDs) {
            selectedCandidateIDs.subtract(selectableIDs)
        } else {
            selectedCandidateIDs.formUnion(selectableIDs)
        }
    }

    @discardableResult
    mutating func selectReviewGroup(id groupID: CleanupGroup.ID) -> Bool {
        guard let index = reviewGroups.firstIndex(where: { $0.id == groupID }) else { return false }

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
        let candidatesByID = Dictionary(
            uniqueKeysWithValues: reviewBinItems.map { ($0.id, $0.candidate) }
        )

        switch result {
        case .success(let deletedAssetIDs):
            reconcileDeletedAssets(deletedAssetIDs, candidatesByID: candidatesByID)
            deletionErrorMessage = nil
        case .partial(let deletedAssetIDs, let failedAssetIDs, let message):
            reconcileDeletedAssets(deletedAssetIDs, candidatesByID: candidatesByID)
            selectFailedReviewBinItems(failedAssetIDs)
            deletionErrorMessage = message
        case .failure(_, let message):
            deletionErrorMessage = message
        }
    }

    private mutating func reconcileDeletedAssets(
        _ deletedAssetIDs: [String],
        candidatesByID: [String: CleanupCandidate]
    ) {
        let deletedIDs = Set(deletedAssetIDs)
        guard !deletedIDs.isEmpty else { return }
        let currentGroupID = reviewGroups.indices.contains(currentReviewGroupIndex)
            ? reviewGroups[currentReviewGroupIndex].id
            : nil

        reviewBinItems.removeAll { deletedIDs.contains($0.id) }
        selectedCandidateIDs.subtract(deletedIDs)

        reviewGroups = reviewGroups.compactMap { group in
            var updatedGroup = group
            updatedGroup.candidates.removeAll { deletedIDs.contains($0.id) }
            guard updatedGroup.candidates.contains(where: { !$0.recommendedKeep }) else { return nil }
            return updatedGroup
        }
        normalizeReviewGroupMetadata()
        tasks = CleanupTaskBuilder.tasks(from: reviewGroups)

        let remainingCandidateIDs = Set(reviewGroups.flatMap { $0.candidates.map(\.id) })
        selectedCandidateIDs.formIntersection(remainingCandidateIDs)
        if reviewGroups.isEmpty {
            currentReviewGroupIndex = 0
        } else if let currentGroupID,
                  let preservedIndex = reviewGroups.firstIndex(where: { $0.id == currentGroupID }) {
            currentReviewGroupIndex = preservedIndex
        } else {
            currentReviewGroupIndex = min(currentReviewGroupIndex, reviewGroups.count - 1)
        }

        var summary = deletionSummary ?? PhotoDeletionSummary()
        summary.record(deletedAssetIDs: Array(deletedIDs), candidatesByID: candidatesByID)
        deletionSummary = summary
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

    private mutating func normalizeReviewGroupMetadata() {
        let totalsByCategory = Dictionary(grouping: reviewGroups.indices) { reviewGroups[$0].category }
        for indices in totalsByCategory.values {
            for (offset, index) in indices.enumerated() {
                reviewGroups[index].groupIndex = offset + 1
                reviewGroups[index].totalGroups = indices.count
                reviewGroups[index].subtitle = indices.count == 1
                    ? "\(reviewGroups[index].candidates.count) 项"
                    : "第 \(offset + 1) 组 / \(indices.count) 组"
            }
        }
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
