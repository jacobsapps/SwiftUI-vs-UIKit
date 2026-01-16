import SwiftUI
import PerformanceShared

struct FeedCellView: View {
    let item: FeedItem
    let assetStore: AssetStore
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let onStickerUpdated: (Int, Int, CGPoint, CGFloat, CGFloat) -> Void
    let onStickerDeleted: (Int, Int) -> Void
    let onStickerGestureBegan: () -> Void
    let onStickerGestureEnded: () -> Void

    @State private var isVisible = false
    @State private var isDraggingSticker = false
    @State private var isInDeleteZone = false

    var body: some View {
        let size = CGSize(width: cellWidth, height: cellHeight)
        let safeRect = stickerSafeRect(in: size)
        let deleteZone = deletionZone(in: size)

        ZStack {
            if let image = assetStore.wallpaperImage(index: item.wallpaperIndex) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .allowsHitTesting(false)
            } else {
                Color.black
                    .allowsHitTesting(false)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(FeedSpec.Cell.topGradientStartAlpha),
                    Color.black.opacity(FeedSpec.Cell.topGradientEndAlpha)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: size.height * FeedSpec.Cell.topGradientHeightFactor)
            .frame(maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    Color.black.opacity(FeedSpec.Cell.bottomGradientStartAlpha),
                    Color.black.opacity(FeedSpec.Cell.bottomGradientEndAlpha)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: min(FeedSpec.Cell.bottomGradientHeight, size.height))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)

            GlowRingView(color: glowColor, isAnimating: isVisible)
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)

            if isDraggingSticker {
                DeletionZoneOverlay(isHighlighted: isInDeleteZone)
                    .frame(width: deleteZone.width, height: deleteZone.height)
                    .position(x: deleteZone.midX, y: deleteZone.midY)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            ZStack {
                ForEach(item.stickers, id: \.id) { sticker in
                    StickerNodeView(
                        itemID: item.id,
                        sticker: sticker,
                        assetStore: assetStore,
                        safeRect: safeRect,
                        deleteZone: deleteZone,
                        isAnimating: isVisible,
                        onInteractionBegan: { center in
                            onStickerGestureBegan()
                            isDraggingSticker = true
                            isInDeleteZone = deleteZone.contains(center)
                        },
                        onInteractionChanged: { center in
                            isInDeleteZone = deleteZone.contains(center)
                        },
                        onInteractionEnded: { update in
                            isDraggingSticker = false
                            isInDeleteZone = false
                            onStickerGestureEnded()
                            if update.isInDeleteZone {
                                onStickerDeleted(item.id, sticker.id)
                            } else {
                                onStickerUpdated(item.id, sticker.id, update.centerUnit, update.scale, update.rotation)
                            }
                        }
                    )
                }
            }

            VStack(alignment: .leading, spacing: FeedSpec.Title.spacing) {
                Text(item.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(FeedSpec.Title.titleColor))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(FeedSpec.Title.subtitleColor))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, FeedSpec.Title.inset.left)
            .padding(.bottom, FeedSpec.Title.inset.bottom)
            .padding(.trailing, FeedSpec.Title.inset.right)
            .allowsHitTesting(false)

            HStack(spacing: FeedSpec.Badge.spacing) {
                BadgeView(text: "FEED")
                BadgeView(text: "LIVE")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, FeedSpec.Badge.inset.left)
            .padding(.top, FeedSpec.Badge.inset.top)
            .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: FeedSpec.Cell.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: max(FeedSpec.Cell.cornerRadius - FeedSpec.Cell.innerBorderInset, 0))
                .inset(by: FeedSpec.Cell.innerBorderInset)
                .stroke(Color(FeedSpec.Cell.innerBorderColor), lineWidth: FeedSpec.Cell.innerBorderWidth)
        )
        .shadow(
            color: Color(FeedSpec.Cell.shadowColor),
            radius: FeedSpec.Cell.shadowRadius,
            x: FeedSpec.Cell.shadowOffset.width,
            y: FeedSpec.Cell.shadowOffset.height
        )
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private var glowColor: UIColor {
        let palette = FeedSpec.Glow.palette
        guard !palette.isEmpty else { return .systemCyan }
        let index = (item.id - 1) % palette.count
        return palette[index]
    }

    private func stickerSafeRect(in size: CGSize) -> CGRect {
        let insets = FeedSpec.Sticker.safeInsets
        let width = max(0, size.width - insets.left - insets.right)
        let height = max(0, size.height - insets.top - insets.bottom)
        return CGRect(x: insets.left, y: insets.top, width: width, height: height)
    }

    private func deletionZone(in size: CGSize) -> CGRect {
        let side = FeedSpec.DeletionZone.size
        return CGRect(x: size.width - side, y: size.height - side, width: side, height: side)
    }
}

private struct BadgeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color(FeedSpec.Badge.textColor))
            .padding(.horizontal, FeedSpec.Badge.horizontalPadding)
            .frame(height: FeedSpec.Badge.height)
            .background(Color(FeedSpec.Badge.backgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: FeedSpec.Badge.cornerRadius)
                    .stroke(Color(FeedSpec.Badge.borderColor), lineWidth: FeedSpec.Badge.borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: FeedSpec.Badge.cornerRadius))
    }
}

private struct DeletionZoneOverlay: View {
    let isHighlighted: Bool

    var body: some View {
        let color = isHighlighted ? FeedSpec.DeletionZone.highlightColor : FeedSpec.DeletionZone.baseColor
        LinearGradient(
            colors: [Color(color), Color.clear],
            startPoint: .bottomTrailing,
            endPoint: .topLeading
        )
        .transition(.opacity)
    }
}
