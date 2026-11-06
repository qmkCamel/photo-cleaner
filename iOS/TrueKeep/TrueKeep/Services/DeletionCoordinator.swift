import Foundation
import Combine

/// Scene-owned. Neither a column disappearing nor a sheet re-layout owns the request.
@MainActor
final class DeletionCoordinator: ObservableObject {
    enum Source: Equatable { case group(String), reviewBin }
    struct Request: Identifiable, Equatable {
        let id: UUID
        let source: Source
        var assetIDs: [String]
    }
    @Published private(set) var request: Request?
    @Published private(set) var isDeleting = false
    @Published private(set) var message: String?
    @Published private(set) var submissionCount = 0
    @Published private(set) var completedGroups: [String: CleanupGroup] = [:]
    @Published private(set) var resultMessage: String?
    @Published private(set) var resultSource: Source?

    func clearMessage() { message = nil }

    func prepare(source: Source, assetIDs: [String]) {
        guard !isDeleting, request == nil, !assetIDs.isEmpty else { return }
        message = nil
        resultMessage = nil
        resultSource = nil
        request = Request(id: UUID(), source: source, assetIDs: Array(Set(assetIDs)).sorted())
    }

    func dismiss() {
        guard !isDeleting, request != nil else { return }
        request = nil
        message = "未提交删除，照片没有变化。"
    }

    func resetCompletedResults() {
        guard !isDeleting else { return }
        completedGroups = [:]
        resultMessage = nil
        resultSource = nil
    }

    /// Snapshot changes consume this confirmation. The next tap is a fresh confirmation.
    func submit(validIDs: [String], service: any PhotoLibraryDeleting,
                completion: @escaping @MainActor (Request, PhotoDeletionResult) -> Void) {
        guard var current = request, !isDeleting else { return }
        let valid = Set(validIDs).intersection(current.assetIDs).sorted()
        guard valid == current.assetIDs else {
            current.assetIDs = valid
            request = current
            message = valid.isEmpty ? "这些项目已不可删除。请取消并返回复核。" : "项目或访问权限已变化，请核对剩余 \(valid.count) 项并重新确认。"
            return
        }
        guard !valid.isEmpty else { return }
        isDeleting = true
        resultSource = current.source
        message = nil
        submissionCount += 1
        Task {
            let result = await service.deleteAssets(withLocalIdentifiers: current.assetIDs)
            completion(current, result)
            self.isDeleting = false
            self.request = nil
        }
    }

    func record(_ result: PhotoDeletionResult, group: CleanupGroup?) {
        let deleted: [String]
        switch result {
        case .success(let ids), .partial(let ids, _, _): deleted = ids
        case .failure: deleted = []
        }
        resultMessage = deleted.isEmpty ? nil : "\(Set(deleted).count) 项已移至照片 App 的“最近删除”，仍可恢复，空间可能尚未立即释放。"
        if var group, !deleted.isEmpty {
            group.candidates.removeAll { Set(deleted).contains($0.id) }
            if CleanupTaskBuilder.task(from: group) == nil {
                group.subtitle = "\(group.candidates.count) 项"
                completedGroups[group.id] = group
            }
        }
    }
}
