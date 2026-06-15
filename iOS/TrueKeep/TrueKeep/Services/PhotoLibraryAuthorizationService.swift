import Photos

enum SupportedScanCopy {
    static let currentScanScope = "截图、大视频和低置信度视觉候选"
    static let permissionSafetyMessage = "本机读取元数据并分析缩略图，寻找截图、大视频、相似、误拍和模糊候选。不会上传；删除前必须由你确认。"
    static let photoLibraryUsageDescription = "留真会在本机扫描照片和视频，找出截图、大视频、相似、误拍和模糊候选。照片和视频不会上传，删除前需要你确认。"
}

enum PhotoLibraryAccess: Hashable {
    case notDetermined
    case full
    case limited
    case denied
    case restricted

    var canScan: Bool {
        switch self {
        case .full, .limited:
            true
        case .notDetermined, .denied, .restricted:
            false
        }
    }

    var requiresSettings: Bool {
        switch self {
        case .denied, .restricted:
            true
        case .notDetermined, .full, .limited:
            false
        }
    }

    var displayTitle: String {
        switch self {
        case .notDetermined:
            "还没有选择照片权限"
        case .full:
            "已允许访问全部照片和视频"
        case .limited:
            "已允许访问部分照片和视频"
        case .denied:
            "照片权限已关闭"
        case .restricted:
            "照片权限受限制"
        }
    }

    var displayMessage: String {
        switch self {
        case .notDetermined:
            "留真需要照片权限，才能在本机扫描\(SupportedScanCopy.currentScanScope)。"
        case .full:
            "留真可以扫描你的照片和视频，所有分析仍只在此 iPhone 上进行。"
        case .limited:
            "留真只能扫描你选择的照片和视频，因此结果可能不完整。你可以在系统设置里扩大访问范围。"
        case .denied:
            "你可以在系统设置中重新开启照片权限。开启前，留真不会读取或扫描你的相册。"
        case .restricted:
            "当前设备或家长控制限制了照片权限。解除限制前，留真无法扫描相册。"
        }
    }

    var scanLimitationWarning: String? {
        switch self {
        case .limited:
            "当前只能扫描你允许访问的照片和视频，结果可能不完整。你可以稍后在系统设置里扩大访问范围。"
        case .notDetermined, .full, .denied, .restricted:
            nil
        }
    }
}

extension PhotoLibraryAccess {
    init(authorizationStatus: PHAuthorizationStatus) {
        switch authorizationStatus {
        case .notDetermined:
            self = .notDetermined
        case .restricted:
            self = .restricted
        case .denied:
            self = .denied
        case .authorized:
            self = .full
        case .limited:
            self = .limited
        @unknown default:
            self = .denied
        }
    }
}

protocol PhotoLibraryAuthorizing: Sendable {
    func currentAccess() -> PhotoLibraryAccess
    func requestReadWriteAccess() async -> PhotoLibraryAccess
}

struct SystemPhotoLibraryAuthorizationService: PhotoLibraryAuthorizing {
    func currentAccess() -> PhotoLibraryAccess {
        PhotoLibraryAccess(authorizationStatus: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestReadWriteAccess() async -> PhotoLibraryAccess {
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
        return PhotoLibraryAccess(authorizationStatus: status)
    }
}

enum PhotoPermissionDecision {
    static func phase(after access: PhotoLibraryAccess) -> AppPhase {
        switch access {
        case .full, .limited:
            .scan
        case .denied, .restricted:
            .permissionIssue(access)
        case .notDetermined:
            .main
        }
    }
}
