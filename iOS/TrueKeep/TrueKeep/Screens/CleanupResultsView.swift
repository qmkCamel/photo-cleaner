import SwiftUI

struct CleanupResultsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var state: CleanupFlowState
    var scanLimitationWarning: String? = nil
    var shouldShowPhotoAccessPrompt: Bool = false
    var hasCompletedScan: Bool = true
    var canScan: Bool = false
    var isRequestingAccess: Bool = false
    var selectedScanDateRange: PhotoScanDateRange = .defaultValue
    var completedScanDateRange: PhotoScanDateRange? = nil
    var activeScanProgress: PhotoScanProgress? = nil
    var sessionMessage: String? = nil
    var sessionNeedsRecovery = false
    var onRetrySession: () -> Void = {}
    var onRebuildSession: () -> Void = {}
    var onManagePhotoAccess: () -> Void = {}
    var onRequestPhotoAccess: () -> Void = {}
    var onSelectScanDateRange: (PhotoScanDateRange) -> Void = { _ in }
    var onScan: (PhotoScanDateRange) -> Void = { _ in }
    var onViewScanProgress: () -> Void = {}
    var onReviewTask: (CleanupTask) -> Void
    @State private var confirmsRebuild = false
    @State private var showsScanSetup = false
    @State private var showsScanDetails = false
    @State private var draftRange: PhotoScanDateRange = .defaultValue
    @State private var exportText: String?
    @State private var exportError: String?
    @State private var isExporting = false
    @State private var exportTask: Task<Void, Never>?
    @State private var exportAttempts = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(hasCompletedScan ? "扫描结果" : "开始整理")
                            .font(TrueKeepTheme.Font.pageTitle)
                        Text(headerMessage)
                            .font(TrueKeepTheme.Font.bodySmall)
                            .foregroundStyle(TrueKeepTheme.muted)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        if hasCompletedScan, let completedScanDateRange {
                            Label(
                                "本次范围：\(completedScanDateRange.title)",
                                systemImage: "calendar"
                            )
                            .font(TrueKeepTheme.Font.caption.weight(.medium))
                            .foregroundStyle(TrueKeepTheme.greenStrong)
                            .accessibilityIdentifier(
                                TrueKeepAccessibility.Control.completedScanDateRange.id
                            )
                        }
                        if hasCompletedScan, let completedAt = state.scanReport?.completedAt {
                            Text("扫描于 \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(TrueKeepTheme.Font.bodySmall)
                                .foregroundStyle(TrueKeepTheme.ink)
                        }
                    }
                    Spacer()
                    TrustChip(title: "本地", systemImage: "checkmark.circle")
                }

                if let activeScanProgress {
                    ActiveScanNotice(progress: activeScanProgress, action: onViewScanProgress)
                }

                if let sessionMessage {
                    SafetyNotice(title: "本地记录需要处理", message: sessionMessage)
                    Button("重试本地记录", action: onRetrySession)
                        .accessibilityIdentifier("session.retry")
                    if sessionNeedsRecovery {
                        Button("重建本地记录") { confirmsRebuild = true }
                            .accessibilityIdentifier("session.rebuild")
                    }
                }

                if activeScanProgress != nil, hasCompletedScan {
                    Text("以下为上次扫描结果，新扫描完成后更新。")
                        .font(TrueKeepTheme.Font.caption).foregroundStyle(TrueKeepTheme.muted)
                }
                if let report = state.scanReport, report.unavailablePhotos > 0 {
                    Text("有 \(report.unavailablePhotos) 项本地内容未能读取，结果可能不完整。")
                        .font(TrueKeepTheme.Font.caption).foregroundStyle(TrueKeepTheme.muted)
                }
                if let deletionSummary = state.deletionSummary {
                    PhotoDeletionSummaryNotice(summary: deletionSummary)
                }

                if let scanLimitationWarning {
                    SafetyNotice(
                        title: "访问范围有限",
                        message: scanLimitationWarning
                    )
                }

                if scanLimitationWarning != nil || (!canScan && !shouldShowPhotoAccessPrompt) {
                    Button("管理照片访问权限", action: onManagePhotoAccess)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("photos.manage-access")
                }

                if shouldShowPhotoAccessPrompt {
                    PhotoAccessPrompt(
                        isRequestingAccess: isRequestingAccess,
                        onRequestAccess: onRequestPhotoAccess
                    )
                }

                if state.tasks.isEmpty {
                    if canScan, activeScanProgress == nil {
                        scanAction
                    }
                    if state.deletionSummary != nil {
                        PostDeletionEmptyState()
                    } else if canScan {
                        EmptyResultsState(hasCompletedScan: hasCompletedScan)
                    }
                } else {
                    HStack {
                        Text(state.deletionSummary == nil ? "预计可释放空间" : "剩余预计可释放空间")
                            .font(TrueKeepTheme.Font.bodySmall.weight(.medium))
                            .foregroundStyle(TrueKeepTheme.greenStrong)
                        Spacer()
                        Text(state.totalEstimatedBytes.formattedStorage)
                            .font(TrueKeepTheme.Font.metric)
                            .foregroundStyle(TrueKeepTheme.ink)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(TrueKeepTheme.greenSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    LazyVStack(spacing: 9) {
                        ForEach(state.tasks) { task in
                            CleanupTaskCard(task: task) {
                                onReviewTask(task)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .readableContent()
        }
        .accessibilityIdentifier(TrueKeepAccessibility.Control.cleanupResultsScreen.id)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .trueKeepScreenBackground()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TrueKeepTheme.page.frame(height: 1)
                .background(TrueKeepTheme.page.ignoresSafeArea(edges: .bottom))
                .accessibilityHidden(true)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if hasCompletedScan {
                    Button {
                        exportText = nil
                        exportError = nil
                        showsScanDetails = true
                    } label: {
                        Text("扫描详情").font(TrueKeepTheme.Font.caption)
                            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                        .foregroundStyle(TrueKeepTheme.greenStrong)
                        .buttonStyle(.plain)
                        .dynamicTypeSize(dynamicTypeSize)
                        .accessibilityIdentifier("scan.details")
                }
                if canScan, !state.tasks.isEmpty, activeScanProgress == nil {
                    Button(action: openScanSetup) {
                        Text("重新扫描").font(TrueKeepTheme.Font.caption)
                            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                        .foregroundStyle(TrueKeepTheme.greenStrong)
                        .buttonStyle(.plain)
                        .dynamicTypeSize(dynamicTypeSize)
                        .accessibilityIdentifier(TrueKeepAccessibility.Control.homeScan.id)
                }
            }
        }
        .sheet(isPresented: $showsScanSetup) {
            NavigationStack {
                ScrollView {
                    ScanDateRangeSelector(title: "扫描范围", selection: draftRange, usesCompactLayout: false) { draftRange = $0 }
                    if let scanLimitationWarning {
                        SafetyNotice(title: "访问范围有限", message: scanLimitationWarning)
                    }
                }.padding()
                .safeAreaInset(edge: .bottom) {
                    PrimaryActionButton(title: "开始扫描") {
                        let range = draftRange
                        showsScanSetup = false
                        onSelectScanDateRange(range)
                        onScan(range)
                    }
                    .accessibilityIdentifier("scan.setup.start")
                    .padding()
                }
                .navigationTitle("本地扫描")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { showsScanSetup = false } label: {
                            Text("取消").font(TrueKeepTheme.Font.caption)
                                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                        }
                            .foregroundStyle(TrueKeepTheme.greenStrong)
                            .buttonStyle(.plain)
                            .dynamicTypeSize(dynamicTypeSize)
                            .accessibilityIdentifier("scan.setup.cancel")
                    }
                }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsScanDetails, onDismiss: {
            exportTask?.cancel()
            exportTask = nil
            isExporting = false
        }) {
            NavigationStack {
                Form {
                    if let completedScanDateRange { Text("本次范围：\(completedScanDateRange.title)") }
                    if let report = state.scanReport {
                        Text(report.summary).accessibilityIdentifier("scan.coverage")
                        Text("耗时 \(report.elapsedSeconds, specifier: "%.1f") 秒。未读取不代表没有问题。")
                    }
                    if let scanLimitationWarning { Text(scanLimitationWarning) }
                    Section("导出复核报告") {
                        Text("报告含本地项目标识和分析统计，不含照片。分享前请确认接收方。")
                        if let exportText {
                            ShareLink(item: exportText) {
                                Label("分享本次复核报告", systemImage: "square.and.arrow.up")
                            }.accessibilityIdentifier("scan.share-report")
                        } else {
                            Button(action: prepareReport) {
                                HStack {
                                    if isExporting { ProgressView() }
                                    Text(isExporting ? "正在生成报告…" : "生成本次复核报告")
                                }
                            }.disabled(isExporting).accessibilityIdentifier("scan.export-report")
                        }
                        if let exportError { Text(exportError).foregroundStyle(TrueKeepTheme.danger) }
                    }
                }
                .accessibilityIdentifier("scan.details.form")
                .navigationTitle("扫描详情")
                .toolbar {
                    Button { showsScanDetails = false } label: {
                        Text("完成").font(TrueKeepTheme.Font.caption)
                            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                        .foregroundStyle(TrueKeepTheme.greenStrong)
                        .buttonStyle(.plain)
                        .dynamicTypeSize(dynamicTypeSize)
                }
            }
        }
        .confirmationDialog("重建本地复核记录？", isPresented: $confirmsRebuild, titleVisibility: .visible) {
            Button("保留备份并重建", action: onRebuildSession)
            Button("取消", role: .cancel) {}
        } message: {
            Text("无法读取的旧记录会保留备份。新的记录使用当前会话，系统照片不会被删除。")
        }
    }

    private var headerMessage: String {
        if !hasCompletedScan {
            return "扫描后，本地复核候选会显示在这里。"
        }
        if state.tasks.isEmpty {
            if state.deletionSummary != nil {
                return "本轮候选已处理完成。"
            }
            return "本次扫描没有发现需要复核的项目。"
        }
        if state.deletionSummary != nil {
            return "已更新当前扫描结果。"
        }
        return "我们找到了值得你复核的项目。"
    }

    private func openScanSetup() {
        guard activeScanProgress == nil else { return }
        draftRange = selectedScanDateRange
        showsScanSetup = true
    }

    private func prepareReport() {
        guard !isExporting else { return }
        isExporting = true
        exportError = nil
        exportAttempts += 1
        let snapshot = state.evaluationExport
        let attempt = exportAttempts
        exportTask = Task { @MainActor in
            let worker = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                #if DEBUG
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("-TrueKeepDisablePhotoDeletion"), arguments.contains("-TrueKeepUITestReportExportFailure") {
                    try await Task.sleep(for: .seconds(2))
                    if attempt == 1 { throw CocoaError(.fileWriteUnknown) }
                }
                #endif
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(snapshot)
                try Task.checkCancellation()
                return String(decoding: data, as: UTF8.self)
            }
            do {
                let text = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                guard !Task.isCancelled else { return }
                exportText = text
            } catch {
                guard !Task.isCancelled else { return }
                exportError = "报告生成失败，请重试。"
            }
            isExporting = false
            exportTask = nil
        }
    }

    private var scanAction: some View {
        PrimaryActionButton(title: hasCompletedScan ? "重新扫描" : "扫描相册", action: openScanSetup)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.homeScan.id)
    }

}

private struct ActiveScanNotice: View {
    var progress: PhotoScanProgress
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ProgressView()
                    .tint(TrueKeepTheme.greenStrong)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("正在\(progress.stageTitle)")
                        .font(TrueKeepTheme.Font.bodySmall.weight(.semibold))
                        .foregroundStyle(TrueKeepTheme.ink)
                    Text("\(progress.progressDescription)，点击查看或取消")
                        .font(TrueKeepTheme.Font.caption)
                        .foregroundStyle(TrueKeepTheme.muted)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(TrueKeepTheme.Font.iconSmall)
                    .foregroundStyle(TrueKeepTheme.greenStrong)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TrueKeepTheme.greenSoft)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.quiet))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(TrueKeepAccessibility.Control.homeActiveScan.id)
        .accessibilityLabel("正在\(progress.stageTitle)，\(progress.progressDescription)")
        .accessibilityHint("打开扫描进度，可取消扫描")
    }
}

private struct ScanDateRangeSelector: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var title: String
    var selection: PhotoScanDateRange
    var usesCompactLayout: Bool
    var onSelect: (PhotoScanDateRange) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(TrueKeepTheme.Font.cardTitle)
                    .foregroundStyle(TrueKeepTheme.ink)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.scanDateRangeSelector.id)
                Text("只影响本地扫描，不改变照片权限。")
                    .font(TrueKeepTheme.Font.caption)
                    .foregroundStyle(TrueKeepTheme.muted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if usesCompactLayout, !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 8) {
                    ForEach(PhotoScanDateRange.allCases) { dateRange in
                        option(dateRange, showsDetail: false)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(PhotoScanDateRange.allCases) { dateRange in
                        option(dateRange, showsDetail: true)
                    }
                }
            }

            Text("已选择：\(selection.title)")
                .font(TrueKeepTheme.Font.caption.weight(.medium))
                .foregroundStyle(TrueKeepTheme.greenStrong)
                .accessibilityIdentifier(TrueKeepAccessibility.Control.selectedScanDateRange.id)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrueKeepTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
    }

    private func option(
        _ dateRange: PhotoScanDateRange,
        showsDetail: Bool
    ) -> some View {
        let isSelected = selection == dateRange

        return Button {
            onSelect(dateRange)
        } label: {
            Group {
                if showsDetail {
                    HStack(alignment: .top, spacing: 10) {
                        selectionImage(isSelected, size: 24)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(dateRange.title)
                                .font(TrueKeepTheme.Font.bodySmall.weight(.semibold))
                                .foregroundStyle(isSelected ? .white : TrueKeepTheme.ink)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(dateRange.detail)
                                .font(TrueKeepTheme.Font.caption)
                                .foregroundStyle(isSelected ? .white : TrueKeepTheme.muted)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)
                    }
                } else {
                    HStack(spacing: 5) {
                        selectionImage(isSelected, size: 20)

                        Text(dateRange.title)
                            .font(TrueKeepTheme.Font.bodySmall.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : TrueKeepTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .padding(.horizontal, showsDetail ? 12 : 7)
            .padding(.vertical, 10)
            .frame(
                maxWidth: .infinity,
                minHeight: 52,
                alignment: showsDetail ? .leading : .center
            )
            .background(isSelected ? TrueKeepTheme.greenStrong : TrueKeepTheme.page)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? TrueKeepTheme.greenStrong : TrueKeepTheme.quiet)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(TrueKeepAccessibility.scanDateRange(dateRange))
        .accessibilityLabel("\(dateRange.title)，\(dateRange.detail)")
        .accessibilityValue(isSelected ? "已选择" : "未选择")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "当前扫描范围" : "双击选择为下一次扫描范围")
    }

    private func selectionImage(_ isSelected: Bool, size: CGFloat) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(TrueKeepTheme.Font.iconSmall)
            .foregroundStyle(isSelected ? .white : TrueKeepTheme.greenStrong)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct PostDeletionEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(TrueKeepTheme.Font.iconLarge)
                .foregroundStyle(TrueKeepTheme.green)
                .accessibilityHidden(true)
            Text("本轮没有待复核项目")
                .font(TrueKeepTheme.Font.sectionTitle)
                .foregroundStyle(TrueKeepTheme.ink)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text("重新扫描后，会根据当前可访问的照片生成新的候选。")
                .font(TrueKeepTheme.Font.bodySmall)
                .foregroundStyle(TrueKeepTheme.muted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrueKeepTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
        .accessibilityElement(children: .combine)
    }
}

private struct PhotoAccessPrompt: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var isRequestingAccess: Bool
    var onRequestAccess: () -> Void

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            Image(systemName: "photo.on.rectangle")
                .font(TrueKeepTheme.Font.iconMedium)
                .foregroundStyle(TrueKeepTheme.greenStrong)
                .frame(width: 34, height: 34)
                .background(Color(red: 0.953, green: 0.965, blue: 0.957))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("需要照片访问才能扫描")
                    .font(TrueKeepTheme.Font.cardTitle)
                    .foregroundStyle(TrueKeepTheme.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text("仅在本机查找候选，删除前仍需确认。")
                    .font(TrueKeepTheme.Font.caption)
                    .foregroundStyle(TrueKeepTheme.muted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryActionButton(
                title: isRequestingAccess ? "请求中..." : "开启访问",
                isBusy: isRequestingAccess,
                action: onRequestAccess
            )
            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 116)
            .disabled(isRequestingAccess)
            .opacity(isRequestingAccess ? 0.72 : 1)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.allowPhotos.id)
            .accessibilityLabel(isRequestingAccess ? "正在请求照片访问" : "开启照片访问")
        }
        .padding(12)
        .background(TrueKeepTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
    }
}

private struct EmptyResultsState: View {
    var hasCompletedScan: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: hasCompletedScan ? "checkmark.seal" : "photo.on.rectangle")
                .font(TrueKeepTheme.Font.iconLarge)
                .foregroundStyle(TrueKeepTheme.green)
            Text(hasCompletedScan ? "暂未发现可清理项目" : "尚未扫描相册")
                .font(TrueKeepTheme.Font.sectionTitle)
                .foregroundStyle(TrueKeepTheme.ink)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(TrueKeepTheme.Font.bodySmall)
                .foregroundStyle(TrueKeepTheme.muted)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrueKeepTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
    }

    private var message: String {
        if hasCompletedScan {
            return "当前本机规则没有发现可复核候选。截图、大视频、相似、误拍和模糊结果都会只作为候选项呈现，由你逐项确认。"
        }
        return "扫描只在本机进行。截图、大视频、相似、误拍和模糊结果都会先作为候选项呈现，由你逐项确认。"
    }
}

private struct CleanupTaskCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var availableWidth: CGFloat = 320

    var task: CleanupTask
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            cardContent
            .padding(11)
            .background(TrueKeepTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .accessibilityIdentifier(TrueKeepAccessibility.cleanupTask(id: task.id))
        .accessibilityLabel("\(task.category.title)，\(task.description)，\(task.candidateCount) 项，\(task.confidenceLabel)")
        .accessibilityHint("打开复核列表")
    }

    @ViewBuilder
    private var cardContent: some View {
        if dynamicTypeSize.isAccessibilitySize || availableWidth < 340 {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    categoryIcon
                    taskTitle
                    Spacer(minLength: 8)
                }

                previewStrip

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    candidateCount
                    Spacer(minLength: 8)
                    confidenceBadge
                }
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                categoryIcon

                VStack(alignment: .leading, spacing: 6) {
                    taskTitle
                    previewStrip
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    candidateCount
                    confidenceBadge
                }
            }
        }
    }

    private var categoryIcon: some View {
        Image(systemName: task.category.systemImage)
            .font(TrueKeepTheme.Font.iconMedium)
            .foregroundStyle(TrueKeepTheme.greenStrong)
            .frame(width: 34, height: 34)
            .background(Color(red: 0.953, green: 0.965, blue: 0.957))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }

    private var taskTitle: some View {
        Text(task.category.title)
            .font(TrueKeepTheme.Font.cardTitle)
            .foregroundStyle(TrueKeepTheme.ink)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var previewStrip: some View {
        HStack(spacing: 4) {
            ForEach(task.previewCandidates.prefix(4)) { candidate in
                ThumbnailView(
                    style: candidate.thumbnail,
                    assetID: candidate.thumbnailAssetID,
                    showsSelectionIndicator: false
                )
                .frame(width: 37, height: 37)
            }
        }
        .accessibilityHidden(true)
    }

    private var candidateCount: some View {
        Text(task.candidateCount.formatted(.number))
            .font(TrueKeepTheme.Font.metric)
            .foregroundStyle(TrueKeepTheme.ink)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var confidenceBadge: some View {
        Text(task.confidenceLabel)
            .font(TrueKeepTheme.Font.statusLabel)
            .foregroundStyle(TrueKeepTheme.greenStrong)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(TrueKeepTheme.greenSoft)
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        CleanupResultsView(state: .sample(), onReviewTask: { _ in })
    }
}
