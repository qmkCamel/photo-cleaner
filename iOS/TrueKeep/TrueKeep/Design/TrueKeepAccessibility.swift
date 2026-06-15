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
        case cancelScan = "truekeep.scan.cancel"
        case retryScan = "truekeep.scan.retry"
        case viewScanResults = "truekeep.scan.view-results"
        case homeTab = "truekeep.tab.home"
        case reviewBinTab = "truekeep.tab.review-bin"
        case privacySafetyTab = "truekeep.tab.privacy-safety"
        case cleanupResultsScreen = "truekeep.cleanup.results"
        case addToReviewBin = "truekeep.review.add-to-review-bin"
        case reviewAllInGroup = "truekeep.review.review-all"
        case previousReviewGroup = "truekeep.review.previous-group"
        case nextReviewGroup = "truekeep.review.next-group"
        case restoreReviewBinSelection = "truekeep.review-bin.restore-selection"
        case deleteReviewBinSelection = "truekeep.review-bin.delete-selection"
        case confirmPhotoDeletion = "truekeep.delete.confirm"
        case cancelPhotoDeletion = "truekeep.delete.cancel"

        var id: String { rawValue }
    }

    static func cleanupTask(category: CleanupCategory) -> String {
        "truekeep.cleanup.task.\(category.rawValue)"
    }

    static func reviewCandidate(id: String) -> String {
        "truekeep.review.candidate.\(id)"
    }

    static func reviewBinItem(id: String) -> String {
        "truekeep.review-bin.item.\(id)"
    }
}
