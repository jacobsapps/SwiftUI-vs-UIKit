import SwiftUI
import PerformanceShared

struct FeedRootView: View {
    @State private var viewModel: FeedViewModel
    @State private var topStats: Stats = Stats(cpu: 0, gpu: 0)
    @State private var topItemID: Int?
    @State private var activeStickerGestures = 0

    private let assetStore: AssetStore

    init() {
        let catalog = ResourceCatalog.load()
        let assetStore = AssetStore(catalog: catalog)
        self.assetStore = assetStore
        _viewModel = State(initialValue: FeedViewModel(catalog: catalog))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(FeedSpec.Background.topColor), Color(FeedSpec.Background.bottomColor)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                GeometryReader { proxy in
                    let cellWidth = max(0, proxy.size.width - FeedSpec.Layout.contentInsets.left - FeedSpec.Layout.contentInsets.right)

                    ScrollView {
                        LazyVStack(spacing: FeedSpec.Layout.interItemSpacing) {
                            ForEach(Array(viewModel.visibleItems.enumerated()), id: \.element.id) { index, item in
                                FeedCellView(
                                    item: item,
                                    assetStore: assetStore,
                                    cellWidth: cellWidth,
                                    cellHeight: item.height,
                                    onStickerUpdated: { itemID, stickerID, centerUnit, scale, rotation in
                                        viewModel.updateSticker(
                                            itemID: itemID,
                                            stickerID: stickerID,
                                            centerUnit: centerUnit,
                                            scale: scale,
                                            rotation: rotation
                                        )
                                    },
                                    onStickerDeleted: { itemID, stickerID in
                                        viewModel.deleteSticker(itemID: itemID, stickerID: stickerID)
                                    },
                                    onStickerGestureBegan: {
                                        activeStickerGestures += 1
                                    },
                                    onStickerGestureEnded: {
                                        activeStickerGestures = max(activeStickerGestures - 1, 0)
                                    }
                                )
                                .frame(width: cellWidth, height: item.height)
                                .background(VisibleItemReporter(itemID: item.id))
                                .onAppear {
                                    viewModel.loadNextPageIfNeeded(currentIndex: index)
                                }
                            }
                        }
                        .padding(.top, FeedSpec.Layout.contentInsets.top)
                        .padding(.bottom, FeedSpec.Layout.contentInsets.bottom)
                        .padding(.leading, FeedSpec.Layout.contentInsets.left)
                        .padding(.trailing, FeedSpec.Layout.contentInsets.right)
                    }
                    .coordinateSpace(name: "feedScroll")
                    .scrollIndicators(.visible)
                    .scrollDisabled(activeStickerGestures > 0)
                    .onPreferenceChange(VisibleItemPreferenceKey.self) { values in
                        updateTopStats(from: values)
                    }
                }
            }
            .overlay(alignment: .top) {
                NavigationBarGradientView()
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                StatsToolbarView(cpu: topStats.cpu, gpu: topStats.gpu)
                    .padding(.bottom, FeedSpec.StatsToolbar.bottomInset)
            }
            .navigationTitle("SwiftUI Performance")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.clear, for: .navigationBar)
            .task {
                viewModel.loadInitialIfNeeded()
            }
        }
    }

    private func updateTopStats(from values: [Int: CGFloat]) {
        guard !values.isEmpty else { return }
        let visible = values.filter { $0.value >= 0 }
        let candidate = (visible.isEmpty ? values : visible).min(by: { $0.value < $1.value })
        guard let itemID = candidate?.key else { return }
        guard itemID != topItemID else { return }
        if let item = viewModel.visibleItems.first(where: { $0.id == itemID }) {
            topItemID = itemID
            topStats = item.stats
        }
    }
}

private struct VisibleItemReporter: View {
    let itemID: Int

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: VisibleItemPreferenceKey.self,
                value: [itemID: proxy.frame(in: .named("feedScroll")).minY]
            )
        }
    }
}

private struct VisibleItemPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct NavigationBarGradientView: View {
    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [Color(FeedSpec.NavigationBar.gradientTop), Color(FeedSpec.NavigationBar.gradientBottom)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: proxy.safeAreaInsets.top + 88)
            .frame(maxWidth: .infinity, alignment: .top)
            .ignoresSafeArea()
        }
    }
}
