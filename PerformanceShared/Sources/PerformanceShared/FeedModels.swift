import UIKit

public struct FeedItem: Hashable {
    public let id: Int
    public let wallpaperIndex: Int
    public let height: CGFloat
    public let badges: [String]
    public let stats: Stats
    public var stickers: [Sticker]

    public var title: String {
        String(format: "Wallpaper %04d", id)
    }

    public var subtitle: String {
        String(format: "ID %04d \u{2022} %d stickers \u{2022} %dpt", id, stickers.count, Int(height))
    }

    public init(id: Int, wallpaperIndex: Int, height: CGFloat, badges: [String], stats: Stats, stickers: [Sticker]) {
        self.id = id
        self.wallpaperIndex = wallpaperIndex
        self.height = height
        self.badges = badges
        self.stats = stats
        self.stickers = stickers
    }
}

public struct Stats: Hashable {
    public let cpu: Int
    public let gpu: Int

    public init(cpu: Int, gpu: Int) {
        self.cpu = cpu
        self.gpu = gpu
    }
}

public struct Sticker: Hashable {
    public let id: Int
    public let gifIndex: Int
    public let baseSize: CGSize
    public var centerUnit: CGPoint
    public var rotation: CGFloat
    public var scale: CGFloat

    public init(id: Int, gifIndex: Int, baseSize: CGSize, centerUnit: CGPoint, rotation: CGFloat, scale: CGFloat) {
        self.id = id
        self.gifIndex = gifIndex
        self.baseSize = baseSize
        self.centerUnit = centerUnit
        self.rotation = rotation
        self.scale = scale
    }
}

public struct DeterministicRandom {
    private var seed: UInt32

    public init(itemID: Int) {
        let initial = UInt32(truncatingIfNeeded: itemID)
        seed = initial &* 1_664_525 &+ 1_013_904_223
    }

    public mutating func nextFloat() -> Float {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Float(seed % 10_000) / 10_000.0
    }
}
