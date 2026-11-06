import SwiftUI

/// Inputs are the container's already-safe bounds, never UIScreen dimensions.
struct AdaptiveLayoutPolicy: Equatable {
    var size: CGSize
    var isRegular: Bool
    var isAccessibilitySize: Bool

    var usesSplitNavigation: Bool {
        isRegular && !isAccessibilitySize && size.width >= 720 && size.height >= 480
    }
    var usesInlineActions: Bool { size.height < 440 || isAccessibilitySize }

    static func columnCount(width: CGFloat, accessibility: Bool) -> Int {
        accessibility ? 1 : min(4, max(1, Int((max(0, width) + 12) / 168)))
    }

    /// Conservative first-release posture support: use one unobstructed pane.
    /// Regions are in physical local coordinates, including their system margins.
    static func unobstructedBounds(in bounds: CGRect, avoiding regions: [CGRect]) -> CGRect {
        regions.reduce(bounds) { available, region in
            let cut = available.intersection(region)
            guard !cut.isNull, cut.width > 0, cut.height > 0 else { return available }
            let candidates = [
                CGRect(x: available.minX, y: available.minY, width: available.width, height: cut.minY - available.minY),
                CGRect(x: available.minX, y: cut.maxY, width: available.width, height: available.maxY - cut.maxY),
                CGRect(x: available.minX, y: available.minY, width: cut.minX - available.minX, height: available.height),
                CGRect(x: cut.maxX, y: available.minY, width: available.maxX - cut.maxX, height: available.height)
            ]
            return candidates.max(by: { $0.width * $0.height < $1.width * $1.height }) ?? available
        }
    }
}

private struct WindowLayoutKey: EnvironmentKey {
    static let defaultValue = AdaptiveLayoutPolicy(size: CGSize(width: 390, height: 700), isRegular: false, isAccessibilitySize: false)
}
extension EnvironmentValues {
    var windowLayout: AdaptiveLayoutPolicy {
        get { self[WindowLayoutKey.self] }
        set { self[WindowLayoutKey.self] = newValue }
    }
}

struct AdaptiveWindow<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            let bounds = safeBounds(geometry)
            let policy = AdaptiveLayoutPolicy(size: bounds.size, isRegular: sizeClass == .regular, isAccessibilitySize: typeSize.isAccessibilitySize)
            content()
                .environment(\.windowLayout, policy)
                .frame(width: bounds.width, height: bounds.height)
                .position(x: bounds.midX, y: bounds.midY)
                .overlay(alignment: .topLeading) {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-TrueKeepUITestLayoutMetrics") {
                        Text("\(Int(bounds.width))x\(Int(bounds.height));\(policy.usesSplitNavigation ? "split" : "single");safe=\(Int(geometry.safeAreaInsets.leading)),\(Int(geometry.safeAreaInsets.trailing))")
                            .font(.caption2).accessibilityIdentifier("layout.metrics")
                            .allowsHitTesting(false)
                    }
                    #endif
                }
        }
    }

    private func safeBounds(_ geometry: GeometryProxy) -> CGRect {
        let bounds = CGRect(origin: .zero, size: geometry.size)
        if #available(iOS 27.1, *) {
            let regions = geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
                .filter(\.isActive).map { region in
                    CGRect(x: region.frame.minX - region.margins.leading,
                           y: region.frame.minY - region.margins.top,
                           width: region.frame.width + region.margins.leading + region.margins.trailing,
                           height: region.frame.height + region.margins.top + region.margins.bottom)
                }
            return AdaptiveLayoutPolicy.unobstructedBounds(in: bounds, avoiding: regions)
        }
        return bounds
    }
}

struct AdaptivePhotoGrid<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var width: CGFloat = 320
    @ViewBuilder var content: () -> Content

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: AdaptiveLayoutPolicy.columnCount(width: width, accessibility: typeSize.isAccessibilitySize)), spacing: 12) {
            content()
        }
        .frame(maxWidth: 1120)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .frame(maxWidth: .infinity)
    }
}

struct AdaptiveHomeNavigation<Sidebar: View, Detail: View>: View {
    @Environment(\.windowLayout) private var policy
    @Binding var preferredColumn: NavigationSplitViewColumn
    @ViewBuilder var sidebar: () -> Sidebar
    @ViewBuilder var detail: () -> Detail

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            sidebar().navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 280)
        } detail: {
            detail()
        }
        .navigationSplitViewStyle(.balanced)
        // One permanent native topology: changing size never swaps two view trees.
        .environment(\.horizontalSizeClass, policy.usesSplitNavigation ? .regular : .compact)
    }
}

extension View {
    func readableContent() -> some View {
        frame(maxWidth: 680).frame(maxWidth: .infinity)
    }
}

struct AdaptiveNativeToolbar: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(VerticalToolbarPriority())
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
private struct VerticalToolbarPriority: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var edge
    func body(content: Content) -> some View {
        content.toolbarVerticalCompressionBehavior(edge == nil ? .automatic : .prefersToolbarItems)
    }
}
