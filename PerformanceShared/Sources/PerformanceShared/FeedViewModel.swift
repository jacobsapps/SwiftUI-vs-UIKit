import UIKit
import Observation

@MainActor
@Observable
public final class FeedViewModel {
    private let catalog: ResourceCatalog
    private let totalItems = 1000
    private let pageSize = 30
    private let prefetchThreshold = 8

    public private(set) var allItems: [FeedItem] = []
    public private(set) var visibleItems: [FeedItem] = []
    private var isLoading = false

    @ObservationIgnored public var onItemsAppended: ((Range<Int>) -> Void)?
    @ObservationIgnored public var onItemUpdated: ((Int) -> Void)?

    public init(catalog: ResourceCatalog) {
        self.catalog = catalog
        self.allItems = Self.buildItems(total: totalItems, catalog: catalog)
    }

    public func loadInitialIfNeeded() {
        guard visibleItems.isEmpty else { return }
        appendNextPage()
    }

    public func loadNextPageIfNeeded(currentIndex: Int) {
        guard !isLoading else { return }
        guard visibleItems.count < allItems.count else { return }
        let remaining = visibleItems.count - currentIndex - 1
        if remaining <= prefetchThreshold {
            appendNextPage()
        }
    }

    public func updateSticker(itemID: Int, stickerID: Int, centerUnit: CGPoint, scale: CGFloat, rotation: CGFloat) {
        guard let index = visibleItems.firstIndex(where: { $0.id == itemID }) else { return }
        var item = visibleItems[index]
        guard let stickerIndex = item.stickers.firstIndex(where: { $0.id == stickerID }) else { return }
        item.stickers[stickerIndex].centerUnit = centerUnit
        item.stickers[stickerIndex].scale = scale
        item.stickers[stickerIndex].rotation = rotation
        visibleItems[index] = item
    }

    public func deleteSticker(itemID: Int, stickerID: Int) {
        guard let index = visibleItems.firstIndex(where: { $0.id == itemID }) else { return }
        var item = visibleItems[index]
        item.stickers.removeAll { $0.id == stickerID }
        visibleItems[index] = item
        onItemUpdated?(index)
    }

    private func appendNextPage() {
        guard !isLoading else { return }
        isLoading = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                guard let self else { return }
                let start = self.visibleItems.count
                let end = min(start + self.pageSize, self.allItems.count)
                guard start < end else {
                    self.isLoading = false
                    return
                }
                self.visibleItems.append(contentsOf: self.allItems[start..<end])
                self.isLoading = false
                self.onItemsAppended?(start..<end)
            }
        }
    }

    private static func buildItems(total: Int, catalog: ResourceCatalog) -> [FeedItem] {
        let wallpaperCount = max(catalog.wallpaperCount, 1)
        let gifCount = catalog.gifCount
        return (1...total).map { id in
            var rng = DeterministicRandom(itemID: id)
            let wallpaperIndex = ((id - 1) % wallpaperCount) + 1
            let height = 150 + ((id * 37) % 101)
            let stickerCount = gifCount == 0 ? 0 : (3 + Int(rng.nextFloat() * 4))
            let stats = Stats(cpu: Int(rng.nextFloat() * 101), gpu: Int(rng.nextFloat() * 101))
            let badges = ["FEED", "LIVE"]
            var stickers: [Sticker] = []
            stickers.reserveCapacity(stickerCount)
            for index in 0..<stickerCount {
                let gifIndex = Int(rng.nextFloat() * Float(gifCount)) + 1
                let baseSize = 44 + CGFloat(rng.nextFloat()) * 86
                let rotation = (CGFloat(rng.nextFloat()) * 24) - 12
                let scale = 0.75 + CGFloat(rng.nextFloat()) * 0.60
                let centerUnit = CGPoint(
                    x: 0.10 + CGFloat(rng.nextFloat()) * 0.80,
                    y: 0.10 + CGFloat(rng.nextFloat()) * 0.80
                )
                stickers.append(Sticker(
                    id: index + 1,
                    gifIndex: gifIndex,
                    baseSize: CGSize(width: baseSize, height: baseSize),
                    centerUnit: centerUnit,
                    rotation: rotation,
                    scale: scale
                ))
            }
            return FeedItem(
                id: id,
                wallpaperIndex: wallpaperIndex,
                height: CGFloat(height),
                badges: badges,
                stats: stats,
                stickers: stickers
            )
        }
    }
}
