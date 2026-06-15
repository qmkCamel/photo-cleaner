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
    case reviewGroup(CleanupCategory)
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
        usesSampleCleanupData ? .sample() : PhotoScanResultBuilder.state(from: [])
    }

    func initialPhase(for access: PhotoLibraryAccess) -> AppPhase {
        switch uiTestScenario {
        case .permissionDenied:
            .permissionIssue(.denied)
        case .scanInterrupted, .limitedCompletedScan, .scanInProgress:
            .scan
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
        case .limitedCompletedScan:
            .limited
        case .scanInterrupted, .scanInProgress:
            .full
        case nil:
            .notDetermined
        }
    }

    func initialScanStatus(for state: CleanupFlowState) -> PhotoScanProgressStatus {
        switch uiTestScenario {
        case .scanInterrupted:
            .interrupted(message: "用户已取消")
        case .limitedCompletedScan:
            .completed(candidateCount: state.tasks.map(\.candidateCount).reduce(0, +))
        case .scanInProgress, .permissionDenied, nil:
            .scanning
        }
    }

    static func markIntroCompleted() {
        UserDefaults.standard.set(true, forKey: completedIntroDefaultsKey)
    }
}

enum AppUITestLaunchScenario: Hashable {
    case permissionDenied
    case scanInterrupted
    case limitedCompletedScan
    case scanInProgress

    init?(arguments: [String]) {
        if arguments.contains(AppLaunchConfiguration.uiTestPermissionDeniedArgument) {
            self = .permissionDenied
        } else if arguments.contains(AppLaunchConfiguration.uiTestScanInterruptedArgument) {
            self = .scanInterrupted
        } else if arguments.contains(AppLaunchConfiguration.uiTestLimitedCompletedScanArgument) {
            self = .limitedCompletedScan
        } else if arguments.contains(AppLaunchConfiguration.uiTestScanInProgressArgument) {
            self = .scanInProgress
        } else {
            return nil
        }
    }
}

enum AppUITestActionDelay {
    static let nanoseconds: UInt64 = 1_200_000_000

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
    @State private var scanStatus: PhotoScanProgressStatus = .scanning
    @State private var scanTask: Task<Void, Never>?
    @State private var activeScanID = UUID()

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
        self._scanStatus = State(initialValue: launchConfiguration.initialScanStatus(for: initialCleanupState))
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
                    scanLimitationWarning: photoAccess.scanLimitationWarning,
                    onCancel: { handleScanCancelOrBack() },
                    onRetry: { startPhotoScan(access: photoAccess) },
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
                startPhotoScan(access: access)
            }
        }
    }

    private func startPhotoScan(access: PhotoLibraryAccess) {
        guard access.canScan else { return }

        scanTask?.cancel()
        let scanID = UUID()
        activeScanID = scanID
        scanStatus = .scanning
        cleanupState = PhotoScanResultBuilder.state(from: [])
        phase = .scan

        let photoScanner = photoScanner
        scanTask = Task {
            let scannedState = await photoScanner.scan(access: access)
            let wasCancelled = Task.isCancelled

            await MainActor.run {
                guard activeScanID == scanID else { return }

                if wasCancelled {
                    scanStatus = .interrupted(message: "用户已取消")
                } else {
                    cleanupState = scannedState
                    scanStatus = .completed(candidateCount: scannedState.tasks.map(\.candidateCount).reduce(0, +))
                }
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
                    isRequestingAccess: isRequestingPhotoAccess,
                    onRequestPhotoAccess: { requestPhotoAccess() },
                    onReviewTask: { task in
                        guard cleanupState.selectReviewGroup(for: task.category) else { return }
                        homePath.append(.reviewGroup(task.category))
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
