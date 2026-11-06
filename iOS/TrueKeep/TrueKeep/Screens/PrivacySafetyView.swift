import SwiftUI

enum PrivacySafetyTopic: String, CaseIterable, Identifiable, Hashable {
    case confirmedKeeps = "confirmed-keeps"
    case howItWorks = "how-it-works"
    case privacyDetails = "privacy-details"
    case helpSupport = "help-support"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .confirmedKeeps:
            "已确认保留"
        case .howItWorks:
            "留真如何工作"
        case .privacyDetails:
            "数据与隐私细节"
        case .helpSupport:
            "帮助与支持"
        }
    }

    var detailTitle: String {
        switch self {
        case .confirmedKeeps:
            "已确认保留"
        case .howItWorks:
            "留真如何工作"
        case .privacyDetails:
            "数据与隐私细节"
        case .helpSupport:
            "帮助与支持"
        }
    }

    var detailBody: String {
        switch self {
        case .confirmedKeeps:
            "这里保存你明确确认要保留的照片记录。记录只包含本机 Photos 资源 ID，不保存照片或缩略图；取消后，照片可能在下次扫描中再次出现。"
        case .howItWorks:
            "留真会在本机读取可访问的照片和视频元数据及缩略图，先找出可解释的候选项目，再让你逐项复核。当前真实扫描覆盖截图、大视频，以及低置信度的相似、误拍和模糊视觉候选。"
        case .privacyDetails:
            "照片和视频不会上传到服务器。应用不需要账号，不加入广告 SDK，不做跨 App 追踪。缩略图只通过系统 Photos 框架读取并使用内存缓存，不会把你的照片或视频另存到应用目录。"
        case .helpSupport:
            "如果扫描结果不完整，请检查是否只授予了 有限照片访问。删除前请确认 iCloud 照片 状态；删除后不要立即清空 “最近删除”，这样仍有恢复窗口。"
        }
    }

    var accessibilityIdentifier: String {
        "truekeep.settings.topic.\(rawValue)"
    }
}

struct PrivacySafetyView: View {
    @ObservedObject var localModels: LocalPhotoModelController = .init()
    var confirmedKeepAssetIDs: Set<String> = []
    var onRemoveConfirmedKeep: (String) -> Void = { _ in }
    var onResetConfirmedKeeps: () -> Void = {}
    var onRestoreConfirmedKeeps: (Set<String>) -> Void = { _ in }

    var body: some View {
        List {
            Section {
                sectionTitle("整理管理")
                topicLink(.confirmedKeeps)
            }
            Section {
                sectionTitle("帮助与隐私")
                topicLink(.howItWorks)
                topicLink(.privacyDetails)
                topicLink(.helpSupport)
            }
            Section {
                sectionTitle("进阶")
                NavigationLink {
                    LocalPhotoModelsView(controller: localModels)
                } label: {
                    LabeledContent("本地模型实验") {
                        Text(localModels.isEnabled ? "已开启" : "关闭")
                            .foregroundStyle(TrueKeepTheme.muted)
                    }
                }
                .accessibilityIdentifier("truekeep.settings.local-models")
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TrueKeep / 留真 · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")")
                    Text("本地分析，不上传照片，不自动删除。")
                        .font(TrueKeepTheme.Font.bodySmall)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(TrueKeepTheme.muted)
            }
        }
        .readableContent()
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PrivacySafetyTopic.self) { topic in
            if topic == .confirmedKeeps {
                ConfirmedKeepsView(
                    assetIDs: confirmedKeepAssetIDs,
                    onRemove: onRemoveConfirmedKeep,
                    onReset: onResetConfirmedKeeps,
                    onRestore: onRestoreConfirmedKeeps
                )
            } else {
                PrivacySafetyTopicDetailView(topic: topic)
            }
        }
        .trueKeepScreenBackground()
    }

    private func topicLink(_ topic: PrivacySafetyTopic) -> some View {
        NavigationLink(value: topic) {
            HStack {
                Text(topic.title).font(.body).fixedSize(horizontal: false, vertical: true)
                Spacer()
                if topic == .confirmedKeeps {
                    Text(confirmedKeepsCountText).font(.body).foregroundStyle(TrueKeepTheme.muted)
                }
            }
        }
        .accessibilityIdentifier(topic.accessibilityIdentifier)
        .accessibilityLabel(topic.title)
        .accessibilityValue(topic == .confirmedKeeps ? confirmedKeepsCountText : "")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(TrueKeepTheme.Font.sectionTitle)
            .foregroundStyle(TrueKeepTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var confirmedKeepsCountText: String {
        confirmedKeepAssetIDs.isEmpty ? "暂无" : "\(confirmedKeepAssetIDs.count) 项"
    }
}

private struct ConfirmedKeepsView: View {
    var assetIDs: Set<String>
    var onRemove: (String) -> Void
    var onReset: () -> Void
    var onRestore: (Set<String>) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.windowLayout) private var layout
    @State private var isEditing = false
    @State private var selectedIDs: Set<String> = []
    @State private var removedIDs: Set<String> = []
    @State private var showsResetConfirmation = false
    @State private var previewCandidate: CleanupCandidate?

    private var candidates: [CleanupCandidate] {
        assetIDs.sorted().enumerated().map { index, id in
            CleanupCandidate(id: id, category: .similar, confidence: .low,
                             defaultSelectedForDeletion: false, recommendedKeep: false, confirmedKeep: true,
                             reason: "已确认保留照片 \(index + 1)", estimatedBytes: 0, thumbnail: .kidPortrait, thumbnailAssetID: id)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("取消保留不会删除照片；照片可能在之后扫描中再次出现。")
                    .font(TrueKeepTheme.Font.caption).foregroundStyle(TrueKeepTheme.muted)
                if !removedIDs.isEmpty {
                    HStack {
                        Text("已取消 \(removedIDs.count) 项保留")
                        Spacer()
                        Button {
                            onRestore(removedIDs)
                            removedIDs = []
                        } label: {
                            Text("撤销").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).foregroundStyle(TrueKeepTheme.greenStrong)
                            .accessibilityIdentifier("keeps.undo")
                    }.font(TrueKeepTheme.Font.caption)
                }
                if assetIDs.isEmpty {
                    ContentUnavailableView("还没有已确认保留的照片", systemImage: "checkmark.shield",
                                           description: Text("打开照片预览，选择“确认保留，不再提醒”。"))
                } else {
                    AdaptivePhotoGrid {
                        ForEach(candidates) { candidate in
                            Button {
                                if isEditing {
                                    if !selectedIDs.insert(candidate.id).inserted { selectedIDs.remove(candidate.id) }
                                } else {
                                    previewCandidate = candidate
                                }
                            } label: {
                                ThumbnailView(style: .kidPortrait, assetID: candidate.id,
                                              isSelected: selectedIDs.contains(candidate.id),
                                              isConfirmedKeep: !isEditing, showsSelectionIndicator: isEditing)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(TrueKeepAccessibility.confirmedKeepItem(id: candidate.id))
                            .accessibilityLabel(candidate.reason)
                            .accessibilityValue(isEditing ? (selectedIDs.contains(candidate.id) ? "已选择" : "未选择") : "已确认保留")
                            .accessibilityHint(isEditing ? "切换取消保留的选择" : "只读预览")
                        }
                    }
                }
                if layout.usesInlineActions { keepActions }
            }.padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            if !layout.usesInlineActions { keepActions }
        }
        .navigationTitle("已确认保留")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !assetIDs.isEmpty {
                Button {
                    isEditing.toggle()
                    selectedIDs = []
                } label: {
                    Text(isEditing ? "完成" : "编辑").font(TrueKeepTheme.Font.caption)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                    .foregroundStyle(TrueKeepTheme.greenStrong)
                    .buttonStyle(.plain)
                    .dynamicTypeSize(dynamicTypeSize)
                    .accessibilityIdentifier("keeps.edit")
            }
        }
        .trueKeepScreenBackground()
        .alert("全部取消保留？", isPresented: $showsResetConfirmation) {
            Button("取消", role: .cancel) {}
            Button("全部取消保留", role: .destructive) { removeSelection() }
        } message: {
            Text("只移除保留记录，不会删除照片。照片可能在下次扫描再次成为候选。")
        }
        .fullScreenCover(item: $previewCandidate) { candidate in
            MediaReviewView(candidates: candidates, initialID: candidate.id)
        }
        .onChange(of: assetIDs) {
            selectedIDs.formIntersection(assetIDs)
            if assetIDs.isEmpty { isEditing = false }
        }
    }

    @ViewBuilder private var keepActions: some View {
            if isEditing && !assetIDs.isEmpty {
                VStack(spacing: 8) {
                    Button {
                        selectedIDs = selectedIDs == assetIDs ? [] : assetIDs
                    } label: {
                        Text(selectedIDs == assetIDs ? "取消全选" : "全选")
                            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(TrueKeepTheme.greenStrong)
                        .accessibilityIdentifier("keeps.select-all")
                    SecondaryActionButton(title: "取消所选保留（\(selectedIDs.count)）") {
                        if selectedIDs == assetIDs { showsResetConfirmation = true }
                        else { removeSelection() }
                    }
                    .disabled(selectedIDs.isEmpty)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.resetConfirmedKeeps.id)
                }.padding().background(TrueKeepTheme.page)
        }
    }

    private func removeSelection() {
        let ids = selectedIDs.intersection(assetIDs)
        guard !ids.isEmpty else { return }
        removedIDs = ids
        selectedIDs = []
        if ids == assetIDs { onReset() }
        else { for id in ids { onRemove(id) } }
    }
}

private struct PrivacySafetyTopicDetailView: View {
    var topic: PrivacySafetyTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(topic.detailTitle)
                    .font(TrueKeepTheme.Font.pageTitle)
                    .foregroundStyle(TrueKeepTheme.ink)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(topic.detailBody)
                    .font(TrueKeepTheme.Font.body)
                    .foregroundStyle(TrueKeepTheme.muted)
                    .lineSpacing(4)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                SafetyNotice(
                    title: "安全原则",
                    message: "本页说明仅反映当前实现。任何新增 SDK、网络上传或自动删除能力，都必须先更新产品说明和 App Store 隐私信息。"
                )
            }
            .padding(20)
            .readableContent()
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .trueKeepScreenBackground()
        .accessibilityIdentifier("\(topic.accessibilityIdentifier).detail")
    }
}

private struct SettingsRow: View {
    var title: String
    var detail: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(TrueKeepTheme.Font.bodySmall.weight(.medium))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let detail {
                Text(detail)
                    .font(TrueKeepTheme.Font.caption)
                    .foregroundStyle(TrueKeepTheme.muted)
            }
            Image(systemName: "chevron.right")
                .font(TrueKeepTheme.Font.iconCaption2)
                .foregroundStyle(TrueKeepTheme.muted)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(minHeight: 46)
        .background(TrueKeepTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(TrueKeepTheme.line))
    }
}

#Preview {
    NavigationStack {
        PrivacySafetyView()
    }
}
