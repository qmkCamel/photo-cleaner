import SwiftUI

enum TrueKeepTheme {
    static let page = Color(red: 0.961, green: 0.973, blue: 0.957)
    static let paper = Color.white
    static let ink = Color(red: 0.082, green: 0.098, blue: 0.090)
    static let muted = Color(red: 0.325, green: 0.365, blue: 0.346)
    static let quiet = Color(red: 0.541, green: 0.584, blue: 0.561)
    static let line = Color(red: 0.875, green: 0.898, blue: 0.878)
    static let green = Color(red: 0.184, green: 0.459, blue: 0.400)
    static let greenStrong = Color(red: 0.141, green: 0.392, blue: 0.341)
    static let greenSoft = Color(red: 0.902, green: 0.945, blue: 0.925)
    static let yellowSoft = Color(red: 1.000, green: 0.965, blue: 0.875)
    static let yellowLine = Color(red: 0.945, green: 0.867, blue: 0.698)
    static let danger = Color(red: 0.678, green: 0.204, blue: 0.290)
    static let tabScrollBottomPadding: CGFloat = 96

    enum Font {
        static let brand = SwiftUI.Font.callout.weight(.bold)
        static let heroTitle = SwiftUI.Font.title.weight(.bold)
        static let pageTitle = SwiftUI.Font.title2.weight(.bold)
        static let sheetTitle = SwiftUI.Font.title3.weight(.bold)
        static let sectionTitle = SwiftUI.Font.headline.weight(.semibold)
        static let cardTitle = SwiftUI.Font.callout.weight(.semibold)
        static let body = SwiftUI.Font.body
        static let bodySmall = SwiftUI.Font.subheadline
        static let button = SwiftUI.Font.callout.weight(.semibold)
        static let inlineAction = SwiftUI.Font.footnote.weight(.semibold)
        static let caption = SwiftUI.Font.caption
        static let captionStrong = SwiftUI.Font.caption.weight(.semibold)
        static let captionBold = SwiftUI.Font.caption.weight(.bold)
        static let caption2 = SwiftUI.Font.caption2
        static let caption2Strong = SwiftUI.Font.caption2.weight(.semibold)
        static let statusLabel = SwiftUI.Font.subheadline.weight(.semibold)
        static let metric = SwiftUI.Font.title3.weight(.bold)
        static let scanValue = SwiftUI.Font.largeTitle.weight(.bold)
        static let iconHero = SwiftUI.Font.largeTitle.weight(.light)
        static let iconLarge = SwiftUI.Font.title.weight(.medium)
        static let iconMedium = SwiftUI.Font.title3.weight(.medium)
        static let iconSmall = SwiftUI.Font.callout.weight(.semibold)
        static let iconCaption = SwiftUI.Font.caption.weight(.bold)
        static let iconCaption2 = SwiftUI.Font.caption2.weight(.semibold)
    }
}

extension View {
    func trueKeepScreenBackground() -> some View {
        background(TrueKeepTheme.page.ignoresSafeArea())
    }
}
