import SwiftUI

enum PhotoScanProgressStatus: Hashable {
    case scanning
    case completed(candidateCount: Int)
    case interrupted(message: String)
}

struct ScanProgressView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var progressRingSize: CGFloat = 158
    @ScaledMetric(relativeTo: .body) private var progressRingLineWidth: CGFloat = 10

    var status: PhotoScanProgressStatus = .scanning
    var scanProgress: PhotoScanProgress = .coarseAnalysis(completed: 0, total: 0)
    var scanDateRange: PhotoScanDateRange = .defaultValue
    var scanLimitationWarning: String? = nil
    var onCancel: () -> Void
    var onContinueBrowsing: () -> Void = {}
    var onRetry: () -> Void = {}
    var onViewResults: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 26)
                    Text(title)
                        .font(TrueKeepTheme.Font.sectionTitle)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    ZStack {
                        Circle()
                            .stroke(TrueKeepTheme.line, lineWidth: progressRingLineWidth)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                TrueKeepTheme.green,
                                style: StrokeStyle(lineWidth: progressRingLineWidth, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 7) {
                            Text(centerValue)
                                .font(TrueKeepTheme.Font.scanValue)
                                .minimumScaleFactor(0.72)
                            Text(centerCaption)
                                .font(TrueKeepTheme.Font.caption)
                                .foregroundStyle(TrueKeepTheme.muted)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(progressRingLineWidth + 10)
                    }
                    .frame(width: progressRingSize, height: progressRingSize)
                    .padding(.top, 24)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(scanProgressAccessibilityLabel)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.scanStage.id)

                    TrustChip(title: "本地扫描", systemImage: "checkmark.circle")
                        .padding(.top, 20)
                    Label("本次范围：\(scanDateRange.title)", systemImage: "calendar")
                        .font(TrueKeepTheme.Font.bodySmall.weight(.medium))
                        .foregroundStyle(TrueKeepTheme.greenStrong)
                        .padding(.top, 12)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.activeScanDateRange.id)
                    Text("照片和视频始终留在你的设备上。")
                        .font(TrueKeepTheme.Font.bodySmall)
                        .foregroundStyle(TrueKeepTheme.muted)
                        .padding(.top, 10)

                    if let scanLimitationWarning {
                        SafetyNotice(
                            title: "访问范围有限",
                            message: scanLimitationWarning
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                    }

                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            ScanRow(title: row.title, value: row.value, done: row.done)
                        }
                    }
                    .background(TrueKeepTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 10) {
                primaryAction
                secondaryAction
                continueBrowsingAction
                Text(footerText)
                    .font(TrueKeepTheme.Font.caption)
                    .foregroundStyle(TrueKeepTheme.muted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .trueKeepScreenBackground()
    }

    private var title: String {
        switch status {
        case .scanning:
            switch scanProgress {
            case .coarseAnalysis:
                "正在快速分析照片"
            case .candidateRefinement:
                "正在复核候选"
            case .finalizing:
                "正在整理扫描结果"
            }
        case .completed:
            "扫描完成"
        case .interrupted:
            "扫描已停止"
        }
    }

    private var progress: CGFloat {
        switch status {
        case .scanning:
            switch scanProgress {
            case .coarseAnalysis(let completed, let total):
                0.05 + (0.50 * fraction(completed: completed, total: total))
            case .candidateRefinement(let completed, let total):
                0.55 + (0.35 * fraction(completed: completed, total: total))
            case .finalizing:
                0.94
            }
        case .completed:
            1
        case .interrupted:
            0.18
        }
    }

    private var centerValue: String {
        switch status {
        case .scanning:
            switch scanProgress {
            case .coarseAnalysis(let completed, let total),
                 .candidateRefinement(let completed, let total):
                total > 0 ? "\(completed)/\(total)" : "准备中"
            case .finalizing:
                "整理中"
            }
        case .completed:
            "100%"
        case .interrupted:
            "已停止"
        }
    }

    private var centerCaption: String {
        switch status {
        case .scanning:
            scanProgress.stageTitle
        case .completed(let candidateCount):
            "\(candidateCount) 项待复核"
        case .interrupted:
            "未改动照片或视频"
        }
    }

    private var rows: [ScanRowModel] {
        switch status {
        case .scanning:
            scanningRows
        case .completed:
            [
                ScanRowModel(title: "快速分析", value: "已完成", done: true),
                ScanRowModel(title: "候选复核", value: "已完成", done: true),
                ScanRowModel(title: "整理结果", value: "已完成", done: true)
            ]
        case .interrupted(let message):
            [
                ScanRowModel(title: "本地扫描", value: "已停止", done: false),
                ScanRowModel(title: "当前状态", value: message, done: false)
            ]
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch status {
        case .scanning:
            PrimaryActionButton(title: "扫描中...", isBusy: true, action: {})
                .disabled(true)
                .opacity(0.72)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.scanInProgress.id)
        case .completed:
            PrimaryActionButton(title: "查看结果", action: onViewResults)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.viewScanResults.id)
        case .interrupted:
            PrimaryActionButton(title: "重新扫描", action: onRetry)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.retryScan.id)
        }
    }

    @ViewBuilder
    private var secondaryAction: some View {
        switch status {
        case .scanning:
            SecondaryActionButton(title: "取消扫描", action: onCancel)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.cancelScan.id)
        case .completed:
            SecondaryActionButton(title: "重新扫描", action: onRetry)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.retryScan.id)
        case .interrupted:
            SecondaryActionButton(title: "回到首页", action: onCancel)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.returnToPermission.id)
        }
    }

    @ViewBuilder
    private var continueBrowsingAction: some View {
        if case .scanning = status {
            SecondaryActionButton(title: "继续浏览", action: onContinueBrowsing)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.continueBrowsing.id)
                .accessibilityHint("扫描会在本机继续运行，可从首页返回进度页")
        }
    }

    private var footerText: String {
        switch status {
        case .scanning:
            "\(scanDateRange.title)扫描正在本机分批进行。离开本页后仍会继续，可以随时返回取消。"
        case .completed:
            "结果只来自\(scanDateRange.title)内当前可访问的照片和视频。"
        case .interrupted:
            "取消扫描不会删除或移动任何照片或视频。"
        }
    }

    private var scanningRows: [ScanRowModel] {
        switch scanProgress {
        case .coarseAnalysis(let completed, let total):
            return [
                ScanRowModel(title: "快速分析", value: progressValue(completed, total), done: false),
                ScanRowModel(title: "候选复核", value: "等待中", done: false),
                ScanRowModel(title: "整理结果", value: "等待中", done: false)
            ]
        case .candidateRefinement(let completed, let total):
            return [
                ScanRowModel(title: "快速分析", value: "已完成", done: true),
                ScanRowModel(title: "候选复核", value: progressValue(completed, total), done: false),
                ScanRowModel(title: "整理结果", value: "等待中", done: false)
            ]
        case .finalizing:
            return [
                ScanRowModel(title: "快速分析", value: "已完成", done: true),
                ScanRowModel(title: "候选复核", value: "已完成", done: true),
                ScanRowModel(title: "整理结果", value: "处理中", done: false)
            ]
        }
    }

    private var scanProgressAccessibilityLabel: String {
        switch status {
        case .scanning:
            "\(scanProgress.stageTitle)，\(scanProgress.progressDescription)，本次范围\(scanDateRange.title)"
        case .completed(let candidateCount):
            "扫描完成，\(candidateCount) 项待复核，本次范围\(scanDateRange.title)"
        case .interrupted(let message):
            "扫描已停止，\(message)，本次范围\(scanDateRange.title)"
        }
    }

    private func fraction(completed: Int, total: Int) -> CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(min(total, max(0, completed))) / CGFloat(total)
    }

    private func progressValue(_ completed: Int, _ total: Int) -> String {
        total > 0 ? "\(min(total, max(0, completed)))/\(total)" : "准备中"
    }
}

extension PhotoScanProgress {
    var stageTitle: String {
        switch self {
        case .coarseAnalysis:
            "快速分析"
        case .candidateRefinement:
            "候选复核"
        case .finalizing:
            "整理结果"
        }
    }

    var progressDescription: String {
        switch self {
        case .coarseAnalysis(let completed, let total),
             .candidateRefinement(let completed, let total):
            total > 0 ? "已完成 \(min(total, max(0, completed))) 项，共 \(total) 项" : "准备中"
        case .finalizing:
            "正在整理最终结果"
        }
    }
}

private struct ScanRowModel: Identifiable {
    var id: String { title }
    var title: String
    var value: String
    var done: Bool
}

private struct ScanRow: View {
    var title: String
    var value: String
    var done: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(TrueKeepTheme.Font.bodySmall.weight(.medium))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text(value)
                .font(TrueKeepTheme.Font.caption)
                .foregroundStyle(TrueKeepTheme.muted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? TrueKeepTheme.green : TrueKeepTheme.quiet)
                .font(TrueKeepTheme.Font.iconSmall)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 45)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TrueKeepTheme.line)
                .frame(height: 1)
                .padding(.leading, 14)
        }
    }
}

#Preview {
    ScanProgressView(onCancel: {}, onViewResults: {})
}
