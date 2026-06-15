import SwiftUI

struct ReviewGroupView: View {
    @Binding var state: CleanupFlowState
    var onAddedToReviewBin: () -> Void

    var body: some View {
        let group = state.currentReviewGroup
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                VStack(spacing: 3) {
                    Text(group.title)
                        .font(TrueKeepTheme.Font.sectionTitle)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(group.subtitle)
                        .font(TrueKeepTheme.Font.caption)
                        .foregroundStyle(TrueKeepTheme.muted)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(group.candidates) { candidate in
                        Button {
                            state.toggleReviewCandidate(candidate)
                        } label: {
                            ThumbnailView(
                                style: candidate.thumbnail,
                                assetID: candidate.thumbnailAssetID,
                                isSelected: state.selectedCandidateIDs.contains(candidate.id),
                                isRecommendedKeep: candidate.recommendedKeep,
                                videoLabel: candidateVideoLabel(candidate)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: candidate.recommendedKeep ? 178 : 104)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .gridCellColumns(candidate.recommendedKeep ? 3 : 1)
                        .disabled(candidate.recommendedKeep)
                        .accessibilityIdentifier(TrueKeepAccessibility.reviewCandidate(id: candidate.id))
                        .accessibilityLabel(candidateAccessibilityLabel(candidate))
                        .accessibilityHint(candidate.recommendedKeep ? "推荐保留，不能加入删除选择" : "切换是否加入复核箱")
                        .accessibilityAddTraits(state.selectedCandidateIDs.contains(candidate.id) ? .isSelected : [])
                    }
                }

                HStack {
                    Text(groupCountText(group))
                    Spacer()
                    Text("预计释放 \(group.estimatedBytes.formattedStorage)")
                }
                .font(TrueKeepTheme.Font.caption)
                .foregroundStyle(TrueKeepTheme.muted)

                SafetyNotice(title: "为什么标记这组？", message: group.explanation)

            }
            .padding(20)
            .padding(.bottom, 12)
        }
        .safeAreaInset(edge: .bottom) {
            reviewActionsFooter
        }
        .navigationTitle(group.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .trueKeepScreenBackground()
    }

    private var reviewActionsFooter: some View {
        VStack(spacing: 10) {
            PrimaryActionButton(title: state.currentReviewSelectionCount == 0 ? "选择项目后加入复核箱" : "加入复核箱（\(state.currentReviewSelectionCount)）") {
                state.addCurrentSelectionToReviewBin()
                onAddedToReviewBin()
            }
            .disabled(state.currentReviewSelectionCount == 0)
            .opacity(state.currentReviewSelectionCount == 0 ? 0.55 : 1)
            .accessibilityIdentifier(TrueKeepAccessibility.Control.addToReviewBin.id)

            SecondaryActionButton(title: "复核本组全部") {
                state.selectAllCandidatesInCurrentGroup()
            }
            .accessibilityIdentifier(TrueKeepAccessibility.Control.reviewAllInGroup.id)

            if state.canMoveToPreviousReviewGroup || state.canMoveToNextReviewGroup {
                HStack {
                    InlineTextActionButton(title: "上一组", minWidth: 64) {
                        state.moveToPreviousReviewGroup()
                    }
                    .disabled(!state.canMoveToPreviousReviewGroup)
                    .opacity(state.canMoveToPreviousReviewGroup ? 1 : 0.45)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.previousReviewGroup.id)

                    Spacer()

                    InlineTextActionButton(title: "下一组", minWidth: 64) {
                        state.moveToNextReviewGroup()
                    }
                    .disabled(!state.canMoveToNextReviewGroup)
                    .opacity(state.canMoveToNextReviewGroup ? 1 : 0.45)
                    .accessibilityIdentifier(TrueKeepAccessibility.Control.nextReviewGroup.id)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(TrueKeepTheme.page.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(TrueKeepTheme.line)
                .frame(height: 1)
        }
    }

    private func groupCountText(_ group: CleanupGroup) -> String {
        switch group.category {
        case .largeVideos:
            return "\(group.candidates.count) 个视频"
        case .similar, .screenshots, .accidental, .blurry:
            return "\(group.candidates.count) 张照片"
        }
    }

    private func candidateVideoLabel(_ candidate: CleanupCandidate) -> String? {
        candidate.category == .largeVideos ? candidate.estimatedBytes.formattedStorage : nil
    }

    private func candidateAccessibilityLabel(_ candidate: CleanupCandidate) -> String {
        if candidate.recommendedKeep {
            return "推荐保留，\(candidate.category.title)，\(candidate.reason)"
        }
        if state.selectedCandidateIDs.contains(candidate.id) {
            return "已选择删除，\(candidate.category.title)，\(candidate.reason)"
        }
        return "未选择删除，\(candidate.category.title)，\(candidate.reason)"
    }
}

#Preview {
    NavigationStack {
        ReviewGroupView(state: .constant(.sample()), onAddedToReviewBin: {})
    }
}
