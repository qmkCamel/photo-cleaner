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
    var scanDateRange: PhotoScanDateRange = .defaultValue
    var scanLimitationWarning: String? = nil
    var onCancel: () -> Void
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
            "正在扫描你的相册"
        case .completed:
            "扫描完成"
        case .interrupted:
            "扫描已停止"
        }
    }

    private var progress: CGFloat {
        switch status {
        case .scanning:
            0.42
        case .completed:
            1
        case .interrupted:
            0.18
        }
    }

    private var centerValue: String {
        switch status {
        case .scanning:
            "处理中"
        case .completed:
            "100%"
        case .interrupted:
            "已停止"
        }
    }

    private var centerCaption: String {
        switch status {
        case .scanning:
            "本机分批扫描"
        case .completed(let candidateCount):
            "\(candidateCount) 项待复核"
        case .interrupted:
            "未改动照片或视频"
        }
    }

    private var rows: [ScanRowModel] {
        switch status {
        case .scanning:
            [
                ScanRowModel(title: "读取照片", value: "分批中", done: false),
                ScanRowModel(title: "读取视频", value: "等待中", done: false),
                ScanRowModel(title: "检测截图", value: "本机处理", done: false),
                ScanRowModel(title: "分析视觉候选", value: "低置信度", done: false),
                ScanRowModel(title: "分析大视频", value: "本机处理", done: false)
            ]
        case .completed:
            [
                ScanRowModel(title: "读取照片", value: "已完成", done: true),
                ScanRowModel(title: "读取视频", value: "已完成", done: true),
                ScanRowModel(title: "检测截图", value: "已完成", done: true),
                ScanRowModel(title: "分析视觉候选", value: "已完成", done: true),
                ScanRowModel(title: "分析大视频", value: "已完成", done: true)
            ]
        case .interrupted(let message):
            [
                ScanRowModel(title: "读取照片", value: "已停止", done: false),
                ScanRowModel(title: "读取视频", value: "已停止", done: false),
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

    private var footerText: String {
        switch status {
        case .scanning:
            "\(scanDateRange.title)扫描在前台分批进行，可以随时取消。"
        case .completed:
            "结果只来自\(scanDateRange.title)内当前可访问的照片和视频。"
        case .interrupted:
            "取消扫描不会删除或移动任何照片或视频。"
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
