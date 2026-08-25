import Foundation

enum TrueKeepAccessibility {
    enum Control: String, CaseIterable {
        case welcomeContinue = "truekeep.welcome.continue"
        case welcomeLearnMore = "truekeep.welcome.learn-more"
        case permissionBack = "truekeep.permission.back"
        case allowPhotos = "truekeep.permission.allow-photos"
        case permissionNotNow = "truekeep.permission.not-now"
        case permissionIssueBack = "truekeep.permission-issue.back"
        case openSettings = "truekeep.permission-issue.open-settings"
        case retryPhotoAccess = "truekeep.permission-issue.retry"
        case returnToPermission = "truekeep.permission-issue.return-to-permission"
        case scanInProgress = "truekeep.scan.in-progress"
        case scanStage = "truekeep.scan.stage"
        case cancelScan = "truekeep.scan.cancel"
        case continueBrowsing = "truekeep.scan.continue-browsing"
        case retryScan = "truekeep.scan.retry"
        case viewScanResults = "truekeep.scan.view-results"
        case activeScanDateRange = "truekeep.scan.date-range.active"
        case homeTab = "truekeep.tab.home"
        case reviewBinTab = "truekeep.tab.review-bin"
        case privacySafetyTab = "truekeep.tab.privacy-safety"
        case cleanupResultsScreen = "truekeep.cleanup.results"
        case homeScan = "truekeep.cleanup.scan"
        case homeActiveScan = "truekeep.cleanup.active-scan"
        case scanDateRangeSelector = "truekeep.cleanup.date-range.selector"
        case selectedScanDateRange = "truekeep.cleanup.date-range.selected"
        case completedScanDateRange = "truekeep.cleanup.date-range.completed"
        case deletionSummary = "truekeep.cleanup.deletion-summary"
        case addToReviewBin = "truekeep.review.add-to-review-bin"
        case directDeleteSelection = "truekeep.review.direct-delete-selection"
        case reviewAllInGroup = "truekeep.review.review-all"
        case confirmedKeepFeedback = "truekeep.review.confirmed-keep-feedback"
        case previousReviewGroup = "truekeep.review.previous-group"
        case nextReviewGroup = "truekeep.review.next-group"
        case restoreReviewBinSelection = "truekeep.review-bin.restore-selection"
        case deleteReviewBinSelection = "truekeep.review-bin.delete-selection"
        case confirmPhotoDeletion = "truekeep.delete.confirm"
        case cancelPhotoDeletion = "truekeep.delete.cancel"
        case resetConfirmedKeeps = "truekeep.settings.confirmed-keeps.reset"

        var id: String { rawValue }
    }

    static func cleanupTask(id: CleanupTask.ID) -> String {
        "truekeep.cleanup.task.\(id)"
    }

    static func scanDateRange(_ dateRange: PhotoScanDateRange) -> String {
        "truekeep.cleanup.date-range.\(dateRange.rawValue)"
    }

    static func reviewCandidate(id: String) -> String {
        "truekeep.review.candidate.\(id)"
    }

    static func reviewCandidateActions(id: String) -> String {
        "truekeep.review.candidate-actions.\(id)"
    }

    static func confirmedKeepItem(id: String) -> String {
        "truekeep.settings.confirmed-keep.\(id)"
    }

    static func reviewBinItem(id: String) -> String {
        "truekeep.review-bin.item.\(id)"
    }
}
