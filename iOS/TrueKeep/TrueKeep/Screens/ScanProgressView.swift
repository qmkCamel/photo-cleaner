import SwiftUI

enum PhotoScanProgressStatus: Hashable {
    case scanning
    case completed(candidateCount: Int)
    case interrupted(message: String)
}

struct ScanProgressView: View {
    var status: PhotoScanProgressStatus = .scanning
    var scanProgress: PhotoScanProgress = .coarseAnalysis(completed: 0, total: 0)
    var scanDateRange: PhotoScanDateRange = .defaultValue
    var scanLimitationWarning: String? = nil
    var isCancelling = false
    var onCancel: () -> Void
    var onContinueBrowsing: () -> Void = {}
    var onRetry: () -> Void = {}
    var onViewResults: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(title).font(TrueKeepTheme.Font.pageTitle)
                statusContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(TrueKeepTheme.paper, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.scanStage.id)
                Label("本次范围：\(scanDateRange.title)", systemImage: "calendar")
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.activeScanDateRange.id)
                Text("仅在本机处理，不上传，不自动删除照片。")
                    .font(TrueKeepTheme.Font.caption).foregroundStyle(TrueKeepTheme.muted)
                if let scanLimitationWarning {
                    SafetyNotice(title: "访问范围有限", message: scanLimitationWarning)
                }
                actions
            }
            .padding(20)
            .readableContent()
        }
        .trueKeepScreenBackground()
    }

    private var title: String {
        switch status {
        case .scanning:
            if isCancelling { "正在停止扫描" }
            else if case .candidateRefinement = scanProgress { "正在复核候选" }
            else { "正在\(scanProgress.stageTitle)" }
        case .completed: "扫描完成"
        case .interrupted: "扫描已停止"
        }
    }

    @ViewBuilder private var statusContent: some View {
        switch status {
        case .scanning:
            VStack(alignment: .leading, spacing: 12) {
                if isCancelling {
                    ProgressView("正在停止本地请求…")
                } else {
                    if let fraction {
                        ProgressView(value: fraction).tint(TrueKeepTheme.greenStrong)
                    } else {
                        ProgressView().tint(TrueKeepTheme.greenStrong)
                    }
                    Text(scanProgress.progressDescription)
                    Text(scanProgress.stageTitle).font(TrueKeepTheme.Font.caption)
                }
            }
        case .completed(let count):
            VStack(alignment: .leading, spacing: 12) {
                Label("\(count) 项待复核", systemImage: "checkmark.circle")
                    .font(TrueKeepTheme.Font.sectionTitle)
                Text("结果来自所选范围内可访问且本地可读取的内容。")
            }
        case .interrupted(let message):
            VStack(alignment: .leading, spacing: 12) {
                Text(message)
                Text("没有发布本轮未完成结果，也没有删除或移动照片。上次可用结果仍保留。")
            }
        }
    }

    private var fraction: Double? {
        switch scanProgress {
        case .coarseAnalysis(let done, let total), .candidateRefinement(let done, let total), .duplicateVerification(let done, let total):
            total > 0 ? Double(min(total, max(0, done))) / Double(total) : nil
        case .finalizing: nil
        }
    }

    @ViewBuilder private var actions: some View {
        switch status {
        case .scanning:
            PrimaryActionButton(title: "继续浏览", action: onContinueBrowsing)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.continueBrowsing.id)
            Button(isCancelling ? "正在停止…" : "取消扫描", action: onCancel)
                .frame(minHeight: 44).disabled(isCancelling)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.cancelScan.id)
        case .completed:
            PrimaryActionButton(title: "查看结果", action: onViewResults)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.viewScanResults.id)
        case .interrupted:
            PrimaryActionButton(title: "重试此范围", action: onRetry)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.retryScan.id)
            Button("返回首页与上次结果", action: onCancel).frame(minHeight: 44)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.returnToPermission.id)
        }
    }
}

extension PhotoScanProgress {
    var stageTitle: String {
        switch self {
        case .coarseAnalysis:
            "快速分析"
        case .candidateRefinement:
            "候选复核"
        case .duplicateVerification:
            "确认重复内容"
        case .finalizing:
            "整理结果"
        }
    }

    var progressDescription: String {
        switch self {
        case .coarseAnalysis(let completed, let total),
             .candidateRefinement(let completed, let total),
             .duplicateVerification(let completed, let total):
            total > 0 ? "已完成 \(min(total, max(0, completed))) 项，共 \(total) 项" : "准备中"
        case .finalizing:
            "正在整理最终结果"
        }
    }
}


#Preview {
    ScanProgressView(onCancel: {}, onViewResults: {})
}
