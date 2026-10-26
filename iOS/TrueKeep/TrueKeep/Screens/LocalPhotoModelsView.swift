import LocalPhotoModels
import SwiftUI

struct LocalPhotoModelsView: View {
    @ObservedObject var controller: LocalPhotoModelController
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var confirmsDownload = false
    @State private var confirmsRemoval = false

    var body: some View {
        Form {
            Section {
                Toggle("启用本地模型实验", isOn: Binding(get: { controller.isEnabled }, set: { controller.setEnabled($0) }))
                    .accessibilityIdentifier("truekeep.models.enabled")
                Text("分析结果可能有误，不会自动选择或删除照片。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("模型") {
                modelPicker
                LabeledContent("格式", value: "MLX · 4-bit")
                LabeledContent("下载大小", value: controller.selectedModel.downloadBytes.formattedStorage)
                LabeledContent("版本", value: String(controller.selectedModel.revision.prefix(8)))
                LabeledContent("状态", value: controller.installed.contains(controller.selectedModel) ? "已下载" : "未下载")
                Link("模型来源与文件", destination: controller.selectedModel.sourceURL)
                Link("模型许可", destination: controller.selectedModel.licenseURL)
            }
            Section {
                if !controller.deviceSupported {
                    Text("当前设备内存不足，暂不开放此模型实验。")
                        .foregroundStyle(TrueKeepTheme.danger)
                }
                if controller.isBusy {
                    LocalModelProgressView(controller: controller)
                } else if controller.installed.contains(controller.selectedModel) {
                    Button(role: .destructive) { confirmsRemoval = true } label: {
                        Label("移除模型", systemImage: "trash")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("truekeep.models.remove")
                } else {
                    Button { confirmsDownload = true } label: {
                        Label("下载模型", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .disabled(!controller.isEnabled || !controller.deviceSupported)
                    .accessibilityIdentifier("truekeep.models.download")
                }
                if let error = controller.errorMessage {
                    Text(error).foregroundStyle(TrueKeepTheme.danger)
                        .accessibilityIdentifier("truekeep.models.error")
                }
                Text("仅下载模型文件时联网。照片分析在本机进行，照片不会上传。模型文件不参与 iCloud 备份。")
                    .font(.footnote).foregroundStyle(.secondary)
                if controller.isFixture { Text("UI 测试模式：未加载真实权重").font(.footnote) }
            }
        }
        .navigationTitle("本地模型实验")
        .navigationBarTitleDisplayMode(.inline)
        .task { await controller.refresh() }
        .alert("下载 \(controller.selectedModel.title)？", isPresented: $confirmsDownload) {
            Button("取消", role: .cancel) {}
            Button("下载") { controller.download() }
        } message: {
            Text("将从 Hugging Face 下载约 \(controller.selectedModel.downloadBytes.formattedStorage) 的模型文件，可能使用移动数据。照片不会上传。")
        }
        .alert("移除本地模型？", isPresented: $confirmsRemoval) {
            Button("取消", role: .cancel) {}
            Button("移除", role: .destructive) { controller.remove() }
        } message: { Text("仅移除模型文件，不影响照片。下次使用需要重新下载。") }
    }

    private var modelPicker: some View {
        Menu {
            ForEach(LocalPhotoModel.allCases) { model in
                Button { controller.select(model) } label: {
                    if model == controller.selectedModel { Label(model.title, systemImage: "checkmark") }
                    else { Text(model.title) }
                }
            }
        } label: {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Text("当前模型").foregroundStyle(.primary)
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                HStack {
                    Text(controller.selectedModel.title).lineLimit(1).minimumScaleFactor(0.4)
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("当前模型，\(controller.selectedModel.title)")
        .accessibilityIdentifier("truekeep.models.picker")
        .disabled(controller.isBusy)
    }
}

struct LocalModelProgressView: View {
    @ObservedObject var controller: LocalPhotoModelController
    var body: some View {
        HStack(spacing: 12) {
            if case .downloading(let value) = controller.progress {
                ProgressView(value: value).frame(width: 60)
            } else { ProgressView() }
            Text(controller.statusText).font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { controller.cancel() } label: {
                Image(systemName: "xmark.circle").frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("取消模型任务")
            .accessibilityIdentifier("truekeep.models.cancel")
            .help("取消模型任务")
            .disabled(controller.isCancelling)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("truekeep.models.progress")
    }
}

struct LocalPhotoAnalysisSection: View {
    @ObservedObject var controller: LocalPhotoModelController
    let group: CleanupGroup
    let isDeleting: Bool

    private var assetIDs: [String] {
        Array(group.candidates.compactMap { controller.isFixture ? $0.id : $0.thumbnailAssetID }.prefix(4))
    }
    private var inputIdentity: String { ([group.id] + assetIDs).joined(separator: "|") }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            HStack {
                Text("本地观察 · 实验").font(TrueKeepTheme.Font.cardTitle)
                Spacer()
                Text(controller.selectedModel.title).font(.caption).foregroundStyle(.secondary)
            }
            if controller.operation == .analyze {
                LocalModelProgressView(controller: controller)
            } else {
                Button {
                    controller.analyze(groupID: group.id, assetIDs: assetIDs)
                } label: {
                    Label("分析前 \(assetIDs.count) 张照片", systemImage: "sparkle.magnifyingglass")
                        .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .disabled(controller.isBusy || isDeleting || assetIDs.isEmpty)
                .accessibilityIdentifier("truekeep.models.analyze")
            }
            if let error = controller.errorMessage {
                Text(error).font(.footnote).foregroundStyle(TrueKeepTheme.danger)
                    .accessibilityIdentifier("truekeep.models.analysis-error")
            }
            if let report = controller.report, controller.reportGroupID == group.id {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(report.photos.enumerated()), id: \.element.id) { index, photo in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("照片 \(index + 1) · \(photo.observation.subject)").font(.subheadline.bold())
                            ForEach(Array(photo.observation.observations.enumerated()), id: \.offset) { _, text in
                                Text(text).font(.footnote)
                            }
                            if photo.observation.uncertain { Text("无法可靠判断").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    Text("\(report.model.title) · \(String(report.model.revision.prefix(8))) · \(report.elapsedSeconds, specifier: "%.1f") 秒")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("truekeep.models.result")
            }
            Text(controller.isFixture ? "UI 测试输出，非真实模型推理" : "模型观察可能有误，不代表照片的保留价值。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .task { await controller.refresh() }
        .onChange(of: inputIdentity) { _, _ in controller.invalidateAnalysis() }
        .onChange(of: isDeleting) { _, deleting in if deleting { controller.invalidateAnalysis() } }
        .onDisappear { controller.invalidateAnalysis() }
    }
}
