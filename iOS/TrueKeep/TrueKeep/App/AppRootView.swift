import SwiftUI
import UIKit
import Photos

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

struct ConfirmedKeepStore {
    static let defaultsKey = "truekeep.confirmedKeepAssetIDs"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAssetIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.defaultsKey) ?? [])
    }

    func saveAssetIDs(_ assetIDs: Set<String>) {
        defaults.set(assetIDs.sorted(), forKey: Self.defaultsKey)
    }

    func reset() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
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
    static let uiTestSuccessfulPhotoDeletionArgument = "-TrueKeepUITestSuccessfulPhotoDeletion"
    static let resetConfirmedKeepsArgument = "-TrueKeepResetConfirmedKeeps"

    var usesSampleCleanupData: Bool
    var hasCompletedIntro: Bool
    var forcesNotDeterminedPhotoAccess: Bool
    var resetsConfirmedKeeps: Bool
    var uiTestScenario: AppUITestLaunchScenario?
    var usesTestSession: Bool
    var resetsTestSession: Bool

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
        resetsConfirmedKeeps = arguments.contains(Self.resetConfirmedKeepsArgument)
        uiTestScenario = AppUITestLaunchScenario(arguments: arguments)
        usesTestSession = arguments.contains("-TrueKeepUITestPersistentSession")
            && usesSampleCleanupData
        resetsTestSession = usesTestSession && arguments.contains("-TrueKeepResetReviewSession")
    }

    var initialCleanupState: CleanupFlowState {
        if uiTestScenario == .postDeletionSuccess {
            return Self.postDeletionSuccessState()
        }
        if uiTestScenario == .multipleSimilarGroups {
            return .multipleSimilarGroupsSample()
        }
        var state = usesSampleCleanupData ? CleanupFlowState.sample() : PhotoScanResultBuilder.state(from: [])
        if argumentsContainCoverageFixture {
            state.scanReport = PhotoScanReport(eligiblePhotos: 701, analyzedPhotos: 699, unavailablePhotos: 2, cacheHits: 300, refinedPhotos: 8, elapsedSeconds: 12, sampledPeakMemoryMB: 90)
        }
        return state
    }

    private var argumentsContainCoverageFixture: Bool {
        usesSampleCleanupData && ProcessInfo.processInfo.arguments.contains("-TrueKeepUITestCoverage")
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
            .filter { !$0.isRecommendedKeepActive && !$0.confirmedKeep }
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var phase: AppPhase = .welcome
    @State private var selectedTab: AppTab = .home
    @State private var homePath: [CleanupRoute] = []
    @State private var preferredHomeColumn: NavigationSplitViewColumn = .sidebar
    @StateObject private var deletion = DeletionCoordinator()
    @State private var cleanupState: CleanupFlowState
    @State private var isRequestingPhotoAccess = false
    @State private var photoAccess: PhotoLibraryAccess = .notDetermined
    @State private var hasCompletedScan = false
    @State private var scanStatus: PhotoScanProgressStatus = .scanning
    @State private var scanProgress: PhotoScanProgress = .coarseAnalysis(completed: 0, total: 0)
    @AppStorage("TrueKeepSelectedScanDateRange") private var selectedScanDateRange: PhotoScanDateRange = .defaultValue
    @State private var activeScanDateRange: PhotoScanDateRange = .defaultValue
    @State private var completedScanDateRange: PhotoScanDateRange?
    @State private var scanTask: Task<Void, Never>?
    @State private var isCancellingScan = false
    @State private var activeScanID = UUID()
    @State private var isScanActive = false
    @State private var confirmedKeepAssetIDs: Set<String>
    @StateObject private var localModels = LocalPhotoModelController()
    @State private var sessionMessage: String?
    @State private var canSaveSession = true
    @State private var libraryObserver: PhotoLibraryObserver?
    private let sessionStore: ReviewSessionStore
    private let usesPersistentSession: Bool
    private let observesPhotoLibrary: Bool

    private let photoAuthorization: any PhotoLibraryAuthorizing
    private let photoScanner: any PhotoLibraryScanning
    private let photoDeletion: any PhotoLibraryDeleting
    private let confirmedKeepStore: ConfirmedKeepStore

    init(
        photoAuthorization: any PhotoLibraryAuthorizing = SystemPhotoLibraryAuthorizationService(),
        photoScanner: any PhotoLibraryScanning = SystemPhotoLibraryScanner(),
        photoDeletion: any PhotoLibraryDeleting = SystemPhotoLibraryDeletionService(),
        confirmedKeepStore: ConfirmedKeepStore = .init(),
        launchConfiguration: AppLaunchConfiguration = .init()
    ) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-TrueKeepResetScanPreferences") {
            UserDefaults.standard.removeObject(forKey: "TrueKeepSelectedScanDateRange")
        }
        #endif
        self.photoAuthorization = photoAuthorization
        self.photoScanner = photoScanner
        self.photoDeletion = photoDeletion
        self.confirmedKeepStore = confirmedKeepStore
        if launchConfiguration.resetsConfirmedKeeps {
            confirmedKeepStore.reset()
        }
        let initialConfirmedKeepAssetIDs = confirmedKeepStore.loadAssetIDs()
        let observesPhotoLibrary = !launchConfiguration.usesSampleCleanupData
            && launchConfiguration.uiTestScenario == nil
            && !launchConfiguration.forcesNotDeterminedPhotoAccess
        self.observesPhotoLibrary = observesPhotoLibrary
        let usesPersistentSession = observesPhotoLibrary || launchConfiguration.usesTestSession
        self.usesPersistentSession = usesPersistentSession
        let store = launchConfiguration.usesTestSession
            ? ReviewSessionStore(fileURL: URL.applicationSupportDirectory.appendingPathComponent("TrueKeep/ui-test-review-session.json"))
            : ReviewSessionStore()
        self.sessionStore = store
        if launchConfiguration.resetsTestSession { try? FileManager.default.removeItem(at: store.fileURL) }
        var initialCleanupState = launchConfiguration.initialCleanupState
        var restoredRange: PhotoScanDateRange?
        if usesPersistentSession {
            do {
                if let saved = try store.load() {
                    initialCleanupState = saved.state
                    restoredRange = saved.completedRange
                }
            } catch {
                self._sessionMessage = State(initialValue: "暂时无法读取本地复核记录。原记录已保留，请稍后重试。")
                self._canSaveSession = State(initialValue: false)
            }
        }
        initialCleanupState.applyConfirmedKeepAssetIDs(initialConfirmedKeepAssetIDs, hideProtectedNonSimilarCandidates: true)
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
        self._hasCompletedScan = State(initialValue: restoredRange != nil || launchConfiguration.initialHasCompletedScan)
        self._scanStatus = State(initialValue: launchConfiguration.initialScanStatus(for: initialCleanupState))
        self._scanProgress = State(initialValue: launchConfiguration.initialScanProgress)
        self._completedScanDateRange = State(
            initialValue: restoredRange ?? (launchConfiguration.initialHasCompletedScan ? .defaultValue : nil)
        )
        self._isScanActive = State(initialValue: launchConfiguration.initialHasActiveScan)
        self._confirmedKeepAssetIDs = State(initialValue: initialConfirmedKeepAssetIDs)
        self._cleanupState = State(initialValue: initialCleanupState)
    }

    var body: some View {
        AdaptiveWindow {
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
                    isCancelling: isCancellingScan,
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
        .overlay(alignment: .bottomLeading) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-TrueKeepUITestLayoutMetrics") {
                Text("删除请求：\(deletion.submissionCount)")
                    .font(.caption2).accessibilityIdentifier("deletion.submissions")
                    .allowsHitTesting(false)
            }
            #endif
        }
        .sheet(isPresented: Binding(get: { deletion.request != nil }, set: { if !$0 { deletion.dismiss() } })) {
            DeleteConfirmationSheet(
                count: deletion.request?.assetIDs.count ?? 0,
                isDeleting: deletion.isDeleting,
                message: deletion.message,
                onCancel: { deletion.dismiss() },
                onConfirm: { submitDeletion() }
            )
            .presentationDetents([.large])
            .interactiveDismissDisabled(deletion.isDeleting)
        }
        .task {
            guard observesPhotoLibrary else { return }
            if photoAccess.canScan { libraryObserver = PhotoLibraryObserver() }
            refreshPhotoLibrary()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshPhotoLibrary() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .trueKeepPhotoLibraryChanged).receive(on: RunLoop.main)) { _ in
            guard observesPhotoLibrary else { return }
            if isScanActive { handleScanCancelOrBack() }
            PhotoAnalysisCache.clear()
            refreshPhotoLibrary()
        }
        .onChange(of: cleanupState) { _, _ in
            saveSession()
        }
    }

    private func saveSession() {
        guard usesPersistentSession, canSaveSession else { return }
        do {
            try sessionStore.save(SavedReviewSession(state: cleanupState, completedRange: completedScanDateRange))
            sessionMessage = nil
        } catch {
            sessionMessage = "本地记录保存失败，当前选择仍在。请保持 App 打开并重试。"
        }
    }

    private func retrySession() {
        if canSaveSession { saveSession(); return }
        do {
            if let saved = try sessionStore.load() {
                cleanupState = saved.state
                cleanupState.applyConfirmedKeepAssetIDs(confirmedKeepAssetIDs, hideProtectedNonSimilarCandidates: true)
                completedScanDateRange = saved.completedRange
                hasCompletedScan = saved.completedRange != nil
            }
            canSaveSession = true
            sessionMessage = nil
            refreshPhotoLibrary()
        } catch {
            sessionMessage = "记录仍无法读取，原文件没有被覆盖。请稍后重试。"
        }
    }

    private func rebuildSession() {
        do {
            try sessionStore.rebuildPreservingBackup(SavedReviewSession(state: cleanupState, completedRange: completedScanDateRange))
            canSaveSession = true
            sessionMessage = nil
        } catch {
            sessionMessage = "暂时无法重建记录，旧文件仍保留。请稍后重试。"
        }
    }

    private func refreshPhotoLibrary() {
        guard observesPhotoLibrary else { return }
        let access = photoAuthorization.currentAccess()
        let changed = access != photoAccess
        photoAccess = access
        if changed { PhotoAnalysisCache.clear() }
        if changed, isScanActive { handleScanCancelOrBack() }
        if access.canScan {
            if libraryObserver == nil { libraryObserver = PhotoLibraryObserver() }
            if case .permissionIssue = phase { phase = .main }
        }
        let ids = Set(cleanupState.reviewGroups.flatMap { $0.candidates.map(\.id) }
            + cleanupState.reviewBinItems.map(\.id))
        let cutoff = Date().addingTimeInterval(-30 * 86_400)
        cleanupState.reviewBinItems.removeAll { $0.addedAt < cutoff }
        var accessible: Set<String> = []
        if access.canScan {
            PHAsset.fetchAssets(withLocalIdentifiers: Array(ids), options: nil).enumerateObjects { asset, _, _ in
                accessible.insert(asset.localIdentifier)
            }
        }
        cleanupState.reconcileAccessibleAssets(accessible)
        SystemPhotoThumbnailProvider.shared.clearCache()
        NotificationCenter.default.post(name: .trueKeepThumbnailsInvalidated, object: nil)
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
                completeIntroAndShowHome()
            }
        }
    }

    private func startPhotoScan(
        access: PhotoLibraryAccess,
        dateRange: PhotoScanDateRange
    ) {
        guard access.canScan, !isScanActive else { return }

        scanTask?.cancel()
        let scanID = UUID()
        activeScanID = scanID
        activeScanDateRange = dateRange
        scanStatus = .scanning
        scanProgress = .coarseAnalysis(completed: 0, total: 0)
        isScanActive = true
        isCancellingScan = false
        phase = .scan

        let photoScanner = photoScanner
        scanTask = Task {
            let scannedState = await photoScanner.scan(
                access: access,
                dateRange: dateRange,
                onProgress: { progress in
                    await MainActor.run {
                        guard activeScanID == scanID, !isCancellingScan else { return }
                        scanProgress = progress
                    }
                }
            )
            let wasCancelled = Task.isCancelled

            await MainActor.run {
                guard activeScanID == scanID else { return }

                if wasCancelled || isCancellingScan {
                    scanStatus = .interrupted(message: "用户已取消")
                } else if let error = scannedState.scanErrorMessage {
                    scanStatus = .interrupted(message: error)
                } else {
                    deletion.resetCompletedResults()
                    cleanupState.mergeScanResult(scannedState, confirmedKeepAssetIDs: confirmedKeepAssetIDs)
                    cleanupState.scanReport?.completedAt = Date()
                    hasCompletedScan = true
                    completedScanDateRange = dateRange
                    scanStatus = .completed(candidateCount: cleanupState.tasks.map(\.candidateCount).reduce(0, +))
                }
                isScanActive = false
                isCancellingScan = false
                scanTask = nil
                if usesPersistentSession { refreshPhotoLibrary() }
                saveSession()
            }
        }
    }

    private func handleScanCancelOrBack() {
        switch scanStatus {
        case .scanning:
            guard !isCancellingScan else { return }
            guard scanTask != nil else {
                scanStatus = .interrupted(message: "用户已取消")
                isScanActive = false
                return
            }
            isCancellingScan = true
            scanTask?.cancel()
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
            AdaptiveHomeNavigation(preferredColumn: $preferredHomeColumn) {
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
                    sessionMessage: sessionMessage,
                    sessionNeedsRecovery: !canSaveSession,
                    onRetrySession: { retrySession() },
                    onRebuildSession: { rebuildSession() },
                    onManagePhotoAccess: { openAppSettings() },
                    onRequestPhotoAccess: { requestPhotoAccess() },
                    onSelectScanDateRange: { selectedScanDateRange = $0 },
                    onScan: { range in
                        startPhotoScan(
                            access: photoAccess,
                            dateRange: range
                        )
                    },
                    onViewScanProgress: {
                        guard isScanActive else { return }
                        phase = .scan
                    },
                    onReviewTask: { task in
                        guard !deletion.isDeleting else { return }
                        localModels.invalidateAnalysis()
                        guard cleanupState.selectReviewGroup(id: task.id) else { return }
                        homePath = [.reviewGroup(task.id)]
                        preferredHomeColumn = .detail
                    }
                )
            } detail: {
                NavigationStack {
                    if case .reviewGroup(let id) = homePath.last {
                        ReviewGroupView(
                            state: $cleanupState,
                            groupID: id,
                            onNavigate: {
                                localModels.invalidateAnalysis()
                                homePath = [.reviewGroup($0)]
                            },
                            onReturnToTasks: {
                                localModels.invalidateAnalysis()
                                preferredHomeColumn = .sidebar
                                homePath.removeAll()
                            },
                            localModels: localModels,
                            deletion: deletion,
                            onAddedToReviewBin: {
                                selectedTab = .reviewBin
                                homePath.removeAll()
                                preferredHomeColumn = .sidebar
                            },
                            onSetConfirmedKeep: { assetID, isConfirmed in
                                setConfirmedKeep(assetID, isConfirmed: isConfirmed)
                            },
                            onConfirmKeepGroup: { ids in
                                let updated = confirmedKeepAssetIDs.union(ids)
                                confirmedKeepStore.saveAssetIDs(updated)
                                confirmedKeepAssetIDs = updated
                                cleanupState.applyConfirmedKeepAssetIDs(updated)
                            }
                        )
                        .id(id)
                    } else {
                        ContentUnavailableView("选择一个任务开始复核", systemImage: "photo.on.rectangle",
                                               description: Text("这里只提供整理建议，不会自动删除照片。"))
                    }
                }
            }
            .tabItem {
                Label("首页", systemImage: "house")
            }
            .tag(AppTab.home)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.homeTab.id)

            ReviewBinView(state: $cleanupState, deletion: deletion)
                .tabItem {
                    Label("复核箱", systemImage: "trash")
                }
                .tag(AppTab.reviewBin)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.reviewBinTab.id)

            NavigationStack {
                PrivacySafetyView(
                    localModels: localModels,
                    confirmedKeepAssetIDs: confirmedKeepAssetIDs,
                    onRemoveConfirmedKeep: { assetID in
                        setConfirmedKeep(assetID, isConfirmed: false)
                    },
                    onResetConfirmedKeeps: { resetConfirmedKeeps() },
                    onRestoreConfirmedKeeps: { ids in
                        let restored = confirmedKeepAssetIDs.union(ids)
                        confirmedKeepStore.saveAssetIDs(restored)
                        confirmedKeepAssetIDs = restored
                        cleanupState.applyConfirmedKeepAssetIDs(restored)
                    }
                )
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.privacySafetyTab.id)
        }
        .toolbarBackground(TrueKeepTheme.page, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .modifier(AdaptiveNativeToolbar())
    }

    private func submitDeletion() {
        guard let request = deletion.request else { return }
        // Re-check access and confirmed keeps immediately before the side effect.
        // Fixture sessions intentionally do not consult the device's private library.
        if observesPhotoLibrary { refreshPhotoLibrary() }
        let validIDs: [String]
        let group: CleanupGroup?
        switch request.source {
        case .group(let id):
            group = cleanupState.reviewGroups.first { $0.id == id }
            validIDs = group?.candidates.filter { !$0.confirmedKeep }.map(\.id) ?? []
        case .reviewBin:
            group = nil
            validIDs = cleanupState.reviewBinItems.filter { !$0.candidate.confirmedKeep }.map(\.id)
        }
        deletion.submit(validIDs: validIDs, service: photoDeletion) { request, result in
            deletion.record(result, group: group)
            switch request.source {
            case .group: cleanupState.applyDirectDeletionResult(result)
            case .reviewBin: cleanupState.applyDeletionResult(result)
            }
            UIAccessibility.post(notification: .announcement,
                                 argument: deletion.resultMessage ?? "删除未完成，请查看失败原因并复核。")
        }
    }

    private func setConfirmedKeep(_ assetID: String, isConfirmed: Bool) {
        var updatedAssetIDs = confirmedKeepAssetIDs
        if isConfirmed {
            updatedAssetIDs.insert(assetID)
        } else {
            updatedAssetIDs.remove(assetID)
        }
        confirmedKeepStore.saveAssetIDs(updatedAssetIDs)
        confirmedKeepAssetIDs = updatedAssetIDs
        cleanupState.applyConfirmedKeepAssetIDs(updatedAssetIDs)
    }

    private func resetConfirmedKeeps() {
        confirmedKeepStore.reset()
        confirmedKeepAssetIDs = []
        cleanupState.applyConfirmedKeepAssetIDs([])
    }
}

#Preview {
    AppRootView()
}
