import SwiftUI
import UIKit

enum AppPhase: Hashable {
    case welcome
    case permissionIssue(PhotoLibraryAccess)
    case scan
    case main
}

enum AppTab: Hashable {
    case home
    case reviewBin
    case settings
}

enum CleanupRoute: Hashable {
    case reviewGroup(CleanupGroup.ID)
}

struct AppLaunchConfiguration: Hashable {
    static let sampleCleanupDataArgument = "-TrueKeepUseSampleCleanupData"
    static let sampleCleanupDataEnvironmentKey = "TRUEKEEP_USE_SAMPLE_CLEANUP_DATA"
    static let completedIntroDefaultsKey = "truekeep.completedIntro"
    static let resetIntroStateArgument = "-TrueKeepResetIntroState"
    static let uiTestForceNotDeterminedAccessArgument = "-TrueKeepUITestForceNotDeterminedAccess"
    static let uiTestPermissionDeniedArgument = "-TrueKeepUITestPermissionDenied"
    static let uiTestScanInterruptedArgument = "-TrueKeepUITestScanInterrupted"
    static let uiTestLimitedCompletedScanArgument = "-TrueKeepUITestLimitedCompletedScan"
    static let uiTestScanInProgressArgument = "-TrueKeepUITestScanInProgress"
    static let uiTestScanRefiningArgument = "-TrueKeepUITestScanRefining"
    static let uiTestAuthorizedHomeArgument = "-TrueKeepUITestAuthorizedHome"
    static let uiTestPostDeletionSuccessArgument = "-TrueKeepUITestPostDeletionSuccess"
    static let uiTestMultipleSimilarGroupsArgument = "-TrueKeepUITestMultipleSimilarGroups"
    static let uiTestDelayedPhotoAccessArgument = "-TrueKeepUITestDelayPhotoAccess"
    static let uiTestDelayedPhotoDeletionArgument = "-TrueKeepUITestDelayPhotoDeletion"

    var usesSampleCleanupData: Bool
    var hasCompletedIntro: Bool
    var forcesNotDeterminedPhotoAccess: Bool
    var uiTestScenario: AppUITestLaunchScenario?

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        if arguments.contains(Self.resetIntroStateArgument) {
            UserDefaults.standard.removeObject(forKey: Self.completedIntroDefaultsKey)
        }

        usesSampleCleanupData = arguments.contains(Self.sampleCleanupDataArgument)
            || environment[Self.sampleCleanupDataEnvironmentKey] == "1"
        hasCompletedIntro = UserDefaults.standard.bool(forKey: Self.completedIntroDefaultsKey)
        forcesNotDeterminedPhotoAccess = arguments.contains(Self.uiTestForceNotDeterminedAccessArgument)
        uiTestScenario = AppUITestLaunchScenario(arguments: arguments)
    }

    var initialCleanupState: CleanupFlowState {
        if uiTestScenario == .postDeletionSuccess {
            return Self.postDeletionSuccessState()
        }
        if uiTestScenario == .multipleSimilarGroups {
            return .multipleSimilarGroupsSample()
        }
        return usesSampleCleanupData ? .sample() : PhotoScanResultBuilder.state(from: [])
    }

    func initialPhase(for access: PhotoLibraryAccess) -> AppPhase {
        switch uiTestScenario {
        case .permissionDenied:
            .permissionIssue(.denied)
        case .scanInterrupted, .limitedCompletedScan, .scanInProgress, .scanRefining:
            .scan
        case .authorizedHome, .postDeletionSuccess, .multipleSimilarGroups:
            .main
        case nil:
            if access.requiresSettings {
                .permissionIssue(access)
            } else if hasCompletedIntro || access.canScan {
                .main
            } else {
                .welcome
            }
        }
    }

    var initialPhotoAccess: PhotoLibraryAccess {
        switch uiTestScenario {
        case .permissionDenied:
            .denied
        case .limitedCompletedScan, .postDeletionSuccess:
            .limited
        case .scanInterrupted, .scanInProgress, .scanRefining, .authorizedHome, .multipleSimilarGroups:
            .full
        case nil:
            .notDetermined
        }
    }

    func initialScanStatus(for state: CleanupFlowState) -> PhotoScanProgressStatus {
        switch uiTestScenario {
        case .scanInterrupted:
            .interrupted(message: "用户已取消")
        case .limitedCompletedScan, .postDeletionSuccess, .multipleSimilarGroups:
            .completed(candidateCount: state.tasks.map(\.candidateCount).reduce(0, +))
        case .scanInProgress, .scanRefining, .authorizedHome, .permissionDenied, nil:
            .scanning
        }
    }

    var initialScanProgress: PhotoScanProgress {
        if uiTestScenario == .scanRefining {
            return .candidateRefinement(completed: 2, total: 5)
        }
        return .coarseAnalysis(completed: 1, total: 8)
    }

    var initialHasCompletedScan: Bool {
        usesSampleCleanupData
            || uiTestScenario == .limitedCompletedScan
            || uiTestScenario == .postDeletionSuccess
            || uiTestScenario == .multipleSimilarGroups
    }

    var initialHasActiveScan: Bool {
        uiTestScenario == .scanInProgress || uiTestScenario == .scanRefining
    }

    static func markIntroCompleted() {
        UserDefaults.standard.set(true, forKey: completedIntroDefaultsKey)
    }

    private static func postDeletionSuccessState() -> CleanupFlowState {
        var state = CleanupFlowState.sample()
        let deletedCandidates = state.reviewGroups
            .flatMap(\.candidates)
            .filter { !$0.recommendedKeep }
        state.reviewBinItems = deletedCandidates.map {
            ReviewBinItem(
                candidate: $0,
                selectedForDelete: true,
                addedAt: Date(timeIntervalSince1970: 0)
            )
        }
        state.applyDeletionResult(.success(deletedAssetIDs: deletedCandidates.map(\.id)))
        return state
    }
}

enum AppUITestLaunchScenario: Hashable {
    case permissionDenied
    case scanInterrupted
    case limitedCompletedScan
    case scanInProgress
    case scanRefining
    case authorizedHome
    case postDeletionSuccess
    case multipleSimilarGroups

    init?(arguments: [String]) {
        if arguments.contains(AppLaunchConfiguration.uiTestPermissionDeniedArgument) {
            self = .permissionDenied
        } else if arguments.contains(AppLaunchConfiguration.uiTestScanInterruptedArgument) {
            self = .scanInterrupted
        } else if arguments.contains(AppLaunchConfiguration.uiTestLimitedCompletedScanArgument) {
            self = .limitedCompletedScan
        } else if arguments.contains(AppLaunchConfiguration.uiTestScanInProgressArgument) {
            self = .scanInProgress
        } else if arguments.contains(AppLaunchConfiguration.uiTestScanRefiningArgument) {
            self = .scanRefining
        } else if arguments.contains(AppLaunchConfiguration.uiTestAuthorizedHomeArgument) {
            self = .authorizedHome
        } else if arguments.contains(AppLaunchConfiguration.uiTestPostDeletionSuccessArgument) {
            self = .postDeletionSuccess
        } else if arguments.contains(AppLaunchConfiguration.uiTestMultipleSimilarGroupsArgument) {
            self = .multipleSimilarGroups
        } else {
            return nil
        }
    }
}

enum AppUITestActionDelay {
    static let nanoseconds: UInt64 = 3_500_000_000

    static func isEnabled(_ argument: String, arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(argument)
    }

    static func sleepIfEnabled(_ argument: String) async {
        guard isEnabled(argument) else { return }
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

struct AppRootView: View {
    @State private var phase: AppPhase = .welcome
    @State private var selectedTab: AppTab = .home
    @State private var homePath: [CleanupRoute] = []
    @State private var cleanupState: CleanupFlowState
    @State private var isRequestingPhotoAccess = false
    @State private var photoAccess: PhotoLibraryAccess = .notDetermined
    @State private var hasCompletedScan = false
    @State private var scanStatus: PhotoScanProgressStatus = .scanning
    @State private var scanProgress: PhotoScanProgress = .coarseAnalysis(completed: 0, total: 0)
    @State private var selectedScanDateRange: PhotoScanDateRange = .defaultValue
    @State private var activeScanDateRange: PhotoScanDateRange = .defaultValue
    @State private var completedScanDateRange: PhotoScanDateRange?
    @State private var scanTask: Task<Void, Never>?
    @State private var activeScanID = UUID()
    @State private var isScanActive = false

    private let photoAuthorization: any PhotoLibraryAuthorizing
    private let photoScanner: any PhotoLibraryScanning
    private let photoDeletion: any PhotoLibraryDeleting

    init(
        photoAuthorization: any PhotoLibraryAuthorizing = SystemPhotoLibraryAuthorizationService(),
        photoScanner: any PhotoLibraryScanning = SystemPhotoLibraryScanner(),
        photoDeletion: any PhotoLibraryDeleting = SystemPhotoLibraryDeletionService(),
        launchConfiguration: AppLaunchConfiguration = .init()
    ) {
        self.photoAuthorization = photoAuthorization
        self.photoScanner = photoScanner
        self.photoDeletion = photoDeletion
        let initialCleanupState = launchConfiguration.initialCleanupState
        let initialPhotoAccess: PhotoLibraryAccess
        if launchConfiguration.uiTestScenario != nil {
            initialPhotoAccess = launchConfiguration.initialPhotoAccess
        } else if launchConfiguration.forcesNotDeterminedPhotoAccess {
            initialPhotoAccess = .notDetermined
        } else {
            initialPhotoAccess = photoAuthorization.currentAccess()
        }
        self._phase = State(initialValue: launchConfiguration.initialPhase(for: initialPhotoAccess))
        self._photoAccess = State(initialValue: initialPhotoAccess)
        self._hasCompletedScan = State(initialValue: launchConfiguration.initialHasCompletedScan)
        self._scanStatus = State(initialValue: launchConfiguration.initialScanStatus(for: initialCleanupState))
        self._scanProgress = State(initialValue: launchConfiguration.initialScanProgress)
        self._completedScanDateRange = State(
            initialValue: launchConfiguration.initialHasCompletedScan ? .defaultValue : nil
        )
        self._isScanActive = State(initialValue: launchConfiguration.initialHasActiveScan)
        self._cleanupState = State(initialValue: initialCleanupState)
    }

    var body: some View {
        Group {
            switch phase {
            case .welcome:
                WelcomeView(
                    isRequestingAccess: isRequestingPhotoAccess,
                    onAllowPhotos: { requestPhotoAccess() },
                    onNotNow: { completeIntroAndShowHome() },
                    onLearnMore: {
                        AppLaunchConfiguration.markIntroCompleted()
                        phase = .main
                        selectedTab = .settings
                    }
                )
            case .permissionIssue(let access):
                PermissionIssueView(
                    access: access,
                    isRequestingAccess: isRequestingPhotoAccess,
                    onBack: { completeIntroAndShowHome() },
                    onOpenSettings: { openAppSettings() },
                    onRetry: { requestPhotoAccess() }
                )
            case .scan:
                ScanProgressView(
                    status: scanStatus,
                    scanProgress: scanProgress,
                    scanDateRange: activeScanDateRange,
                    scanLimitationWarning: photoAccess.scanLimitationWarning,
                    onCancel: { handleScanCancelOrBack() },
                    onContinueBrowsing: {
                        phase = .main
                        selectedTab = .home
                    },
                    onRetry: {
                        startPhotoScan(
                            access: photoAccess,
                            dateRange: activeScanDateRange
                        )
                    },
                    onViewResults: {
                        guard case .completed = scanStatus else { return }
                        phase = .main
                        selectedTab = .home
                    }
                )
            case .main:
                mainTabs
            }
        }
        .tint(TrueKeepTheme.green)
    }

    private func requestPhotoAccess() {
        guard !isRequestingPhotoAccess else { return }
        AppLaunchConfiguration.markIntroCompleted()
        isRequestingPhotoAccess = true
        let photoAuthorization = photoAuthorization
        Task {
            if AppUITestActionDelay.isEnabled(AppLaunchConfiguration.uiTestDelayedPhotoAccessArgument) {
                await AppUITestActionDelay.sleepIfEnabled(AppLaunchConfiguration.uiTestDelayedPhotoAccessArgument)
                await MainActor.run {
                    photoAccess = .denied
                    isRequestingPhotoAccess = false
                    phase = .permissionIssue(.denied)
                }
                return
            }

            let access = await photoAuthorization.requestReadWriteAccess()
            await MainActor.run {
                photoAccess = access
                isRequestingPhotoAccess = false
                phase = PhotoPermissionDecision.phase(after: access)
            }
            guard access.canScan else { return }
            await MainActor.run {
                startPhotoScan(access: access, dateRange: selectedScanDateRange)
            }
        }
    }

    private func startPhotoScan(
        access: PhotoLibraryAccess,
        dateRange: PhotoScanDateRange
    ) {
        guard access.canScan else { return }

        scanTask?.cancel()
        let scanID = UUID()
        activeScanID = scanID
        activeScanDateRange = dateRange
        scanStatus = .scanning
        scanProgress = .coarseAnalysis(completed: 0, total: 0)
        cleanupState = PhotoScanResultBuilder.state(from: [])
        hasCompletedScan = false
        isScanActive = true
        completedScanDateRange = nil
        phase = .scan

        let photoScanner = photoScanner
        scanTask = Task {
            let scannedState = await photoScanner.scan(
                access: access,
                dateRange: dateRange,
                onProgress: { progress in
                    await MainActor.run {
                        guard activeScanID == scanID else { return }
                        scanProgress = progress
                    }
                }
            )
            let wasCancelled = Task.isCancelled

            await MainActor.run {
                guard activeScanID == scanID else { return }

                if wasCancelled {
                    scanStatus = .interrupted(message: "用户已取消")
                } else {
                    cleanupState = scannedState
                    hasCompletedScan = true
                    completedScanDateRange = dateRange
                    scanStatus = .completed(candidateCount: scannedState.tasks.map(\.candidateCount).reduce(0, +))
                }
                isScanActive = false
                scanTask = nil
            }
        }
    }

    private func handleScanCancelOrBack() {
        switch scanStatus {
        case .scanning:
            scanTask?.cancel()
            scanTask = nil
            activeScanID = UUID()
            scanStatus = .interrupted(message: "用户已取消")
            isScanActive = false
        case .completed, .interrupted:
            completeIntroAndShowHome()
        }
    }

    private func completeIntroAndShowHome() {
        AppLaunchConfiguration.markIntroCompleted()
        phase = .main
        selectedTab = .home
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                CleanupResultsView(
                    state: cleanupState,
                    scanLimitationWarning: photoAccess.scanLimitationWarning,
                    shouldShowPhotoAccessPrompt: photoAccess == .notDetermined,
                    hasCompletedScan: hasCompletedScan,
                    canScan: photoAccess.canScan,
                    isRequestingAccess: isRequestingPhotoAccess,
                    selectedScanDateRange: selectedScanDateRange,
                    completedScanDateRange: completedScanDateRange,
                    activeScanProgress: isScanActive ? scanProgress : nil,
                    onRequestPhotoAccess: { requestPhotoAccess() },
                    onSelectScanDateRange: { selectedScanDateRange = $0 },
                    onScan: {
                        startPhotoScan(
                            access: photoAccess,
                            dateRange: selectedScanDateRange
                        )
                    },
                    onViewScanProgress: {
                        guard isScanActive else { return }
                        phase = .scan
                    },
                    onReviewTask: { task in
                        guard cleanupState.selectReviewGroup(id: task.id) else { return }
                        homePath.append(.reviewGroup(task.id))
                    }
                )
                .navigationDestination(for: CleanupRoute.self) { route in
                    switch route {
                    case .reviewGroup:
                        ReviewGroupView(state: $cleanupState) {
                            selectedTab = .reviewBin
                            homePath.removeAll()
                        }
                    }
                }
            }
            .tabItem {
                Label("首页", systemImage: "house")
            }
            .tag(AppTab.home)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.homeTab.id)

            ReviewBinView(state: $cleanupState, photoDeletion: photoDeletion)
                .tabItem {
                    Label("复核箱", systemImage: "trash")
                }
                .tag(AppTab.reviewBin)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.reviewBinTab.id)

            NavigationStack {
                PrivacySafetyView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.privacySafetyTab.id)
        }
        .toolbarBackground(TrueKeepTheme.page, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview {
    AppRootView()
}
