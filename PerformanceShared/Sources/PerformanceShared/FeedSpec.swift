import UIKit

public enum FeedSpec {
    public enum Layout {
        public static let contentInsets = UIEdgeInsets(top: 12, left: 8, bottom: 24, right: 8)
        public static let interItemSpacing: CGFloat = 12
        public static let sectionInset = UIEdgeInsets.zero
    }

    public enum Background {
        public static let topColor = UIColor(hex: 0x0B0B0B)
        public static let bottomColor = UIColor(hex: 0x141414)
    }

    public enum Cell {
        public static let cornerRadius: CGFloat = 18
        public static let shadowColor = UIColor.black.withAlphaComponent(0.35)
        public static let shadowRadius: CGFloat = 12
        public static let shadowOffset = CGSize(width: 0, height: 6)

        public static let topGradientStartAlpha: CGFloat = 0.25
        public static let topGradientEndAlpha: CGFloat = 0.0
        public static let topGradientHeightFactor: CGFloat = 0.25

        public static let bottomGradientStartAlpha: CGFloat = 0.0
        public static let bottomGradientEndAlpha: CGFloat = 0.75
        public static let bottomGradientHeight: CGFloat = 140

        public static let innerBorderInset: CGFloat = 1
        public static let innerBorderWidth: CGFloat = 1
        public static let innerBorderColor = UIColor.white.withAlphaComponent(0.10)
    }

    public enum Badge {
        public static let height: CGFloat = 24
        public static let horizontalPadding: CGFloat = 10
        public static let cornerRadius: CGFloat = 12
        public static let backgroundColor = UIColor.black.withAlphaComponent(0.35)
        public static let borderColor = UIColor.white.withAlphaComponent(0.18)
        public static let borderWidth: CGFloat = 1
        public static let textColor = UIColor.white.withAlphaComponent(0.95)
        public static let font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        public static let inset = UIEdgeInsets(top: 12, left: 12, bottom: 0, right: 0)
        public static let spacing: CGFloat = 6
    }

    public enum Stats {
        public static let font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        public static let textColor = UIColor.white.withAlphaComponent(0.85)
        public static let lineSpacing: CGFloat = 2
        public static let inset = UIEdgeInsets(top: 12, left: 0, bottom: 0, right: 12)
    }

    public enum Title {
        public static let titleFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        public static let titleColor = UIColor.white
        public static let subtitleFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        public static let subtitleColor = UIColor.white.withAlphaComponent(0.80)
        public static let spacing: CGFloat = 4
        public static let inset = UIEdgeInsets(top: 0, left: 12, bottom: 12, right: 12)
    }

    public enum Glow {
        public static let pathInset: CGFloat = 3
        public static let dotSize: CGFloat = 6
        public static let dotAlpha: CGFloat = 0.6
        public static let dotShadowRadius: CGFloat = 4
        public static let tailLength: CGFloat = 52
        public static let tailWidth: CGFloat = 6
        public static let headAlpha: CGFloat = 0.45
        public static let tailAlpha: CGFloat = 0.0
        public static let duration: CFTimeInterval = 6.0
        public static let palette: [UIColor] = [
            .systemRed,
            .systemOrange,
            .systemYellow,
            .systemGreen,
            .systemMint,
            .systemTeal,
            .systemCyan,
            .systemBlue,
            .systemIndigo,
            .systemPurple,
            .systemPink,
            .systemBrown,
            UIColor(hex: 0xFF6B6B),
            UIColor(hex: 0xFFD93D),
            UIColor(hex: 0x6BCB77),
            UIColor(hex: 0x4D96FF),
            UIColor(hex: 0x845EC2),
            UIColor(hex: 0xF9A826),
            UIColor(hex: 0x00C9A7),
            UIColor(hex: 0x2C73D2),
            UIColor(hex: 0xFF9671),
            UIColor(hex: 0xC34A36),
            UIColor(hex: 0x00A8CC),
            UIColor(hex: 0x9BDEAC)
        ]
    }

    public enum Sticker {
        public static let safeInsets = UIEdgeInsets(top: 52, left: 16, bottom: 72, right: 16)
        public static let shadowColor = UIColor.black.withAlphaComponent(0.25)
        public static let shadowRadius: CGFloat = 8
        public static let shadowOffset = CGSize(width: 0, height: 4)
        public static let borderColor = UIColor.white.withAlphaComponent(0.15)
        public static let borderWidth: CGFloat = 1
        public static let cornerRadius: CGFloat = 8
    }

    public enum DeletionZone {
        public static let size: CGFloat = 72
        public static let baseColor = UIColor(hex: 0xFF2D2D, alpha: 0.85)
        public static let highlightColor = UIColor(hex: 0xFF2D2D, alpha: 1.0)
        public static let borderColor = UIColor(hex: 0xFF2D2D, alpha: 0.9)
        public static let borderWidth: CGFloat = 1
    }

    public enum Cache {
        public static let wallpaperCostLimit = 300 * 1024 * 1024
        public static let wallpaperCountLimit = 120
    }

    public enum NavigationBar {
        public static let titleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
        public static let largeTitleFont = UIFont.systemFont(ofSize: 34, weight: .bold)
        public static let titleColor = UIColor.white.withAlphaComponent(0.95)
        public static let gradientTop = UIColor.black.withAlphaComponent(0.6)
        public static let gradientBottom = UIColor.black.withAlphaComponent(0.0)
    }

    public enum StatsToolbar {
        public static let size = CGSize(width: 220, height: 44)
        public static let cornerRadius: CGFloat = 22
        public static let backgroundColor = UIColor.black.withAlphaComponent(0.55)
        public static let borderColor = UIColor.white.withAlphaComponent(0.12)
        public static let borderWidth: CGFloat = 1
        public static let textColor = UIColor.white.withAlphaComponent(0.95)
        public static let font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        public static let bottomInset: CGFloat = 16
    }
}

public extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
