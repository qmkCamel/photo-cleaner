import SwiftUI

extension CleanupFlowState {
    static func sample() -> CleanupFlowState {
        let similarGroup = CleanupGroup(
            id: "similar-family-12",
            category: .similar,
            title: "相似照片",
            subtitle: "第 12 组 / 67 组",
            groupIndex: 12,
            totalGroups: 67,
            explanation: "这些照片看起来非常相似。保留一张清晰表情更好的照片，可以减少重复。",
            candidates: [
                candidate("keep-01", .similar, .high, false, true, "这一张主体清晰，表情最好。", 0, .kidPortrait),
                candidate("similar-02", .similar, .high, true, false, "同一场景的重复照片。", 4_200_000, .park),
                candidate("similar-03", .similar, .high, true, false, "主体接近，但构图更弱。", 3_900_000, .familyBeach),
                candidate("similar-04", .similar, .medium, true, false, "同一组连拍里清晰度较低。", 4_300_000, .breakfast),
                candidate("similar-05", .similar, .medium, false, false, "表情不同，默认保留给你判断。", 3_800_000, .kidClose),
                candidate("similar-06", .similar, .low, false, false, "相似度较低，默认不选中。", 3_200_000, .kidsOutdoor),
                candidate("similar-07", .similar, .low, false, false, "可能有独立纪念价值。", 3_500_000, .garden)
            ]
        )

        let screenshotCandidates = [
            candidate("shot-01", .screenshots, .high, true, false, "旧截图。", 1_100_000, .screenshot),
            candidate("shot-02", .screenshots, .high, true, false, "临时聊天截图。", 1_000_000, .receipt),
            candidate("shot-03", .screenshots, .medium, true, false, "重复截图。", 1_300_000, .notes)
        ]

        let accidentalCandidates = [
            candidate("acc-01", .accidental, .medium, true, false, "地面和天花板误拍。", 2_100_000, .floor),
            candidate("acc-02", .accidental, .medium, true, false, "口袋误拍。", 2_000_000, .blur),
            candidate("acc-03", .accidental, .low, false, false, "主体不明确，默认不选。", 2_200_000, .wall)
        ]

        let blurryCandidates = [
            candidate("blur-01", .blurry, .low, false, false, "清晰度较低。", 2_400_000, .blur),
            candidate("blur-02", .blurry, .low, false, false, "手指遮挡。", 2_700_000, .finger),
            candidate("blur-03", .blurry, .low, false, false, "主体不完整。", 2_300_000, .table)
        ]

        let videoCandidates = [
            candidate("video-01", .largeVideos, .medium, true, false, "体积较大的短视频。", 650_000_000, .videoSunset),
            candidate("video-02", .largeVideos, .medium, true, false, "内容重复的大视频。", 740_000_000, .videoPark),
            candidate("video-03", .largeVideos, .low, false, false, "默认保留给你判断。", 520_000_000, .videoIndoor)
        ]

        let screenshotGroup = CleanupGroup(
            id: "screenshots-chat-03",
            category: .screenshots,
            title: "截图复核",
            subtitle: "第 3 组 / 18 组",
            groupIndex: 3,
            totalGroups: 18,
            explanation: "这些截图更像临时信息或重复记录。删除前请确认没有账号、订单或重要凭证。",
            candidates: screenshotCandidates
        )

        let accidentalGroup = CleanupGroup(
            id: "accidental-pocket-07",
            category: .accidental,
            title: "误拍复核",
            subtitle: "第 7 组 / 23 组",
            groupIndex: 7,
            totalGroups: 23,
            explanation: "这些照片主体不明确，可能来自口袋、地面或遮挡场景。低置信度项目默认留给你判断。",
            candidates: accidentalCandidates
        )

        let blurryGroup = CleanupGroup(
            id: "blurry-low-confidence-02",
            category: .blurry,
            title: "模糊复核",
            subtitle: "第 2 组 / 11 组",
            groupIndex: 2,
            totalGroups: 11,
            explanation: "这些照片清晰度或遮挡情况需要人工确认。默认不选中，避免误删有纪念价值的内容。",
            candidates: blurryCandidates
        )

        let videoGroup = CleanupGroup(
            id: "large-videos-01",
            category: .largeVideos,
            title: "大视频复核",
            subtitle: "第 1 组 / 4 组",
            groupIndex: 1,
            totalGroups: 4,
            explanation: "这些视频占用空间较大。删除前请确认内容是否已经备份或不再需要。",
            candidates: videoCandidates
        )

        let tasks = [
            CleanupTask(
                id: "similar",
                category: .similar,
                description: "67 组，建议保留最佳照片",
                candidateCount: 1_284,
                estimatedBytes: 3_900_000_000,
                confidenceLabel: "推荐复核",
                previewCandidates: Array(similarGroup.candidates.prefix(4))
            ),
            CleanupTask(
                id: "screenshots",
                category: .screenshots,
                description: "旧截图、重复截图和临时信息",
                candidateCount: 568,
                estimatedBytes: 870_000_000,
                confidenceLabel: "可快速清理",
                previewCandidates: screenshotCandidates
            ),
            CleanupTask(
                id: "accidental",
                category: .accidental,
                description: "口袋、地板、天花板等低价值照片",
                candidateCount: 342,
                estimatedBytes: 780_000_000,
                confidenceLabel: "谨慎复核",
                previewCandidates: accidentalCandidates
            ),
            CleanupTask(
                id: "blurry",
                category: .blurry,
                description: "低清晰度或手指遮挡",
                candidateCount: 213,
                estimatedBytes: 510_000_000,
                confidenceLabel: "低置信度",
                previewCandidates: blurryCandidates
            ),
            CleanupTask(
                id: "large-videos",
                category: .largeVideos,
                description: "大于 500 MB 的视频",
                candidateCount: 24,
                estimatedBytes: 2_700_000_000,
                confidenceLabel: "建议复核",
                previewCandidates: videoCandidates
            )
        ]

        return CleanupFlowState(
            tasks: tasks,
            reviewGroups: [similarGroup, screenshotGroup, accidentalGroup, blurryGroup, videoGroup],
            currentReviewGroupIndex: 0,
            selectedCandidateIDs: Set(similarGroup.candidates.filter(\.defaultSelectedForDeletion).map(\.id)),
            reviewBinItems: [],
            deletionSummary: nil,
            deletionErrorMessage: nil
        )
    }

    private static func candidate(
        _ id: String,
        _ category: CleanupCategory,
        _ confidence: CandidateConfidence,
        _ defaultSelected: Bool,
        _ recommendedKeep: Bool,
        _ reason: String,
        _ bytes: Int64,
        _ thumbnail: ThumbnailStyle
    ) -> CleanupCandidate {
        CleanupCandidate(
            id: id,
            category: category,
            confidence: confidence,
            defaultSelectedForDeletion: defaultSelected,
            recommendedKeep: recommendedKeep,
            reason: reason,
            estimatedBytes: bytes,
            thumbnail: thumbnail
        )
    }
}

extension ThumbnailStyle {
    static let kidPortrait = ThumbnailStyle(symbolName: "person.crop.square", topColor: Color(red: 0.84, green: 0.91, blue: 0.80), bottomColor: Color(red: 0.51, green: 0.70, blue: 0.58))
    static let park = ThumbnailStyle(symbolName: "tree", topColor: Color(red: 0.70, green: 0.83, blue: 0.64), bottomColor: Color(red: 0.33, green: 0.53, blue: 0.37))
    static let familyBeach = ThumbnailStyle(symbolName: "figure.2.and.child.holdinghands", topColor: Color(red: 0.69, green: 0.84, blue: 0.93), bottomColor: Color(red: 0.83, green: 0.72, blue: 0.54))
    static let breakfast = ThumbnailStyle(symbolName: "fork.knife", topColor: Color(red: 0.94, green: 0.82, blue: 0.62), bottomColor: Color(red: 0.72, green: 0.47, blue: 0.32))
    static let kidClose = ThumbnailStyle(symbolName: "face.smiling", topColor: Color(red: 0.95, green: 0.78, blue: 0.67), bottomColor: Color(red: 0.76, green: 0.52, blue: 0.46))
    static let kidsOutdoor = ThumbnailStyle(symbolName: "figure.2", topColor: Color(red: 0.63, green: 0.78, blue: 0.94), bottomColor: Color(red: 0.34, green: 0.56, blue: 0.78))
    static let garden = ThumbnailStyle(symbolName: "leaf", topColor: Color(red: 0.79, green: 0.89, blue: 0.72), bottomColor: Color(red: 0.39, green: 0.61, blue: 0.40))
    static let screenshot = ThumbnailStyle(symbolName: "rectangle.split.3x1", topColor: Color(red: 0.93, green: 0.95, blue: 0.98), bottomColor: Color(red: 0.73, green: 0.78, blue: 0.85))
    static let receipt = ThumbnailStyle(symbolName: "doc.text", topColor: Color(red: 0.96, green: 0.94, blue: 0.90), bottomColor: Color(red: 0.80, green: 0.77, blue: 0.70))
    static let notes = ThumbnailStyle(symbolName: "text.alignleft", topColor: Color(red: 0.94, green: 0.97, blue: 0.99), bottomColor: Color(red: 0.78, green: 0.84, blue: 0.90))
    static let floor = ThumbnailStyle(symbolName: "square.grid.2x2", topColor: Color(red: 0.80, green: 0.75, blue: 0.68), bottomColor: Color(red: 0.58, green: 0.53, blue: 0.48))
    static let blur = ThumbnailStyle(symbolName: "camera.filters", topColor: Color(red: 0.78, green: 0.78, blue: 0.77), bottomColor: Color(red: 0.47, green: 0.48, blue: 0.48))
    static let wall = ThumbnailStyle(symbolName: "rectangle.dashed", topColor: Color(red: 0.90, green: 0.86, blue: 0.78), bottomColor: Color(red: 0.66, green: 0.61, blue: 0.55))
    static let finger = ThumbnailStyle(symbolName: "hand.raised", topColor: Color(red: 0.91, green: 0.69, blue: 0.62), bottomColor: Color(red: 0.61, green: 0.46, blue: 0.43))
    static let table = ThumbnailStyle(symbolName: "table.furniture", topColor: Color(red: 0.75, green: 0.68, blue: 0.58), bottomColor: Color(red: 0.47, green: 0.39, blue: 0.32))
    static let videoSunset = ThumbnailStyle(symbolName: "play.rectangle", topColor: Color(red: 0.93, green: 0.64, blue: 0.43), bottomColor: Color(red: 0.38, green: 0.45, blue: 0.63))
    static let videoPark = ThumbnailStyle(symbolName: "play.rectangle", topColor: Color(red: 0.68, green: 0.82, blue: 0.65), bottomColor: Color(red: 0.29, green: 0.51, blue: 0.37))
    static let videoIndoor = ThumbnailStyle(symbolName: "play.rectangle", topColor: Color(red: 0.83, green: 0.75, blue: 0.68), bottomColor: Color(red: 0.48, green: 0.44, blue: 0.41))
}
