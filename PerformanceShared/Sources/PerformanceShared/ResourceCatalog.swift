import UIKit

public struct ResourceCatalog {
    public let wallpaperURLs: [URL]
    public let gifURLs: [URL]

    public var wallpaperCount: Int { wallpaperURLs.count }
    public var gifCount: Int { gifURLs.count }

    public func wallpaperURL(for index: Int) -> URL? {
        guard index > 0, index <= wallpaperURLs.count else { return nil }
        return wallpaperURLs[index - 1]
    }

    public func gifURL(for index: Int) -> URL? {
        guard index > 0, index <= gifURLs.count else { return nil }
        return gifURLs[index - 1]
    }

    public static func load() -> ResourceCatalog {
        let wallpapers = Self.loadURLs(subdirectory: "wallpapers")
        let gifs = Self.loadURLs(subdirectory: "gifs")
            .filter { $0.pathExtension.lowercased() == "gif" }
        return ResourceCatalog(
            wallpaperURLs: Self.sortNumerically(wallpapers),
            gifURLs: Self.sortNumerically(gifs)
        )
    }

    private static func loadURLs(subdirectory: String) -> [URL] {
        guard let baseURL = Bundle.main.resourceURL?.appendingPathComponent(subdirectory) else {
            return []
        }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.filter { !$0.hasDirectoryPath }
    }

    private static func sortNumerically(_ urls: [URL]) -> [URL] {
        urls.sorted { lhs, rhs in
            let lhsNumber = Int(lhs.deletingPathExtension().lastPathComponent) ?? 0
            let rhsNumber = Int(rhs.deletingPathExtension().lastPathComponent) ?? 0
            if lhsNumber != rhsNumber {
                return lhsNumber < rhsNumber
            }
            return lhs.lastPathComponent < rhs.lastPathComponent
        }
    }
}

public final class AssetStore {
    private let catalog: ResourceCatalog
    private let wallpaperCache = NSCache<NSNumber, UIImage>()
    private let gifCache = NSCache<NSNumber, NSData>()

    public init(catalog: ResourceCatalog) {
        self.catalog = catalog
        wallpaperCache.totalCostLimit = FeedSpec.Cache.wallpaperCostLimit
        wallpaperCache.countLimit = FeedSpec.Cache.wallpaperCountLimit
    }

    public func wallpaperImage(index: Int) -> UIImage? {
        let key = NSNumber(value: index)
        if let cached = wallpaperCache.object(forKey: key) {
            return cached
        }
        guard let url = catalog.wallpaperURL(for: index) else { return nil }
        let image = UIImage(contentsOfFile: url.path)
        if let image {
            wallpaperCache.setObject(image, forKey: key, cost: image.memoryCost)
        }
        return image
    }

    public func gifData(index: Int) -> Data? {
        let key = NSNumber(value: index)
        if let cached = gifCache.object(forKey: key) {
            return cached as Data
        }
        guard let url = catalog.gifURL(for: index) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        gifCache.setObject(data as NSData, forKey: key)
        return data
    }
}

private extension UIImage {
    var memoryCost: Int {
        if let cgImage {
            return cgImage.width * cgImage.height * 4
        }
        let width = Int(size.width * scale)
        let height = Int(size.height * scale)
        return width * height * 4
    }
}
