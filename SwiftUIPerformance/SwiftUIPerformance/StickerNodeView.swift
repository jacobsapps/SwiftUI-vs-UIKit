import SwiftUI
import SwiftyGif
import PerformanceShared

struct StickerUpdate {
    let centerUnit: CGPoint
    let scale: CGFloat
    let rotation: CGFloat
    let isInDeleteZone: Bool
}

struct StickerNodeView: View {
    let itemID: Int
    let sticker: Sticker
    let assetStore: AssetStore
    let safeRect: CGRect
    let deleteZone: CGRect
    let isAnimating: Bool
    let onInteractionBegan: (CGPoint) -> Void
    let onInteractionChanged: (CGPoint) -> Void
    let onInteractionEnded: (StickerUpdate) -> Void

    @State private var gifData: Data?
    @State private var currentCenter: CGPoint
    @State private var baseCenter: CGPoint
    @State private var currentScale: CGFloat
    @State private var baseScale: CGFloat
    @State private var currentRotation: Angle
    @State private var baseRotation: Angle

    @State private var isDragging = false
    @State private var isPinching = false
    @State private var isRotating = false
    @State private var activeGestures = 0

    init(itemID: Int,
         sticker: Sticker,
         assetStore: AssetStore,
         safeRect: CGRect,
         deleteZone: CGRect,
         isAnimating: Bool,
         onInteractionBegan: @escaping (CGPoint) -> Void,
         onInteractionChanged: @escaping (CGPoint) -> Void,
         onInteractionEnded: @escaping (StickerUpdate) -> Void) {
        self.itemID = itemID
        self.sticker = sticker
        self.assetStore = assetStore
        self.safeRect = safeRect
        self.deleteZone = deleteZone
        self.isAnimating = isAnimating
        self.onInteractionBegan = onInteractionBegan
        self.onInteractionChanged = onInteractionChanged
        self.onInteractionEnded = onInteractionEnded

        let center = CGPoint(
            x: safeRect.minX + sticker.centerUnit.x * safeRect.width,
            y: safeRect.minY + sticker.centerUnit.y * safeRect.height
        )
        _currentCenter = State(initialValue: center)
        _baseCenter = State(initialValue: center)
        _currentScale = State(initialValue: sticker.scale)
        _baseScale = State(initialValue: sticker.scale)
        _currentRotation = State(initialValue: Angle(degrees: sticker.rotation))
        _baseRotation = State(initialValue: Angle(degrees: sticker.rotation))
    }

    var body: some View {
        let isInDeleteZone = deleteZone.contains(currentCenter)
        let highlightScale: CGFloat = isInDeleteZone ? 0.9 : 1.0
        let highlightOpacity: CGFloat = isInDeleteZone ? 0.8 : 1.0

        SwiftyGifImageView(
            gifIndex: sticker.gifIndex,
            data: gifData,
            isAnimating: isAnimating
        )
        .contentShape(Rectangle())
        .frame(width: sticker.baseSize.width, height: sticker.baseSize.height)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: FeedSpec.Sticker.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FeedSpec.Sticker.cornerRadius)
                .stroke(Color(FeedSpec.Sticker.borderColor), lineWidth: FeedSpec.Sticker.borderWidth)
        )
        .shadow(
            color: Color(FeedSpec.Sticker.shadowColor),
            radius: FeedSpec.Sticker.shadowRadius,
            x: FeedSpec.Sticker.shadowOffset.width,
            y: FeedSpec.Sticker.shadowOffset.height
        )
        .scaleEffect(currentScale * highlightScale)
        .rotationEffect(currentRotation)
        .opacity(highlightOpacity)
        .position(currentCenter)
        .highPriorityGesture(dragGesture)
        .simultaneousGesture(magnificationGesture)
        .simultaneousGesture(rotationGesture)
        .onAppear {
            gifData = assetStore.gifData(index: sticker.gifIndex)
        }
        .onChange(of: sticker.centerUnit) { _, newValue in
            let center = CGPoint(
                x: safeRect.minX + newValue.x * safeRect.width,
                y: safeRect.minY + newValue.y * safeRect.height
            )
            currentCenter = center
            baseCenter = center
        }
        .onChange(of: sticker.scale) { _, newValue in
            currentScale = newValue
            baseScale = newValue
        }
        .onChange(of: sticker.rotation) { _, newValue in
            let angle = Angle(degrees: newValue)
            currentRotation = angle
            baseRotation = angle
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                beginGestureIfNeeded(isActive: &isDragging)
                currentCenter = CGPoint(
                    x: baseCenter.x + value.translation.width,
                    y: baseCenter.y + value.translation.height
                )
                onInteractionChanged(currentCenter)
            }
            .onEnded { _ in
                baseCenter = currentCenter
                endGestureIfNeeded(isActive: &isDragging)
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                beginGestureIfNeeded(isActive: &isPinching)
                currentScale = baseScale * value
                onInteractionChanged(currentCenter)
            }
            .onEnded { _ in
                baseScale = currentScale
                endGestureIfNeeded(isActive: &isPinching)
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                beginGestureIfNeeded(isActive: &isRotating)
                currentRotation = baseRotation + value
                onInteractionChanged(currentCenter)
            }
            .onEnded { _ in
                baseRotation = currentRotation
                endGestureIfNeeded(isActive: &isRotating)
            }
    }

    private func beginGestureIfNeeded(isActive: inout Bool) {
        if !isActive {
            isActive = true
            if activeGestures == 0 {
                onInteractionBegan(currentCenter)
            }
            activeGestures += 1
        }
    }

    private func endGestureIfNeeded(isActive: inout Bool) {
        if isActive {
            isActive = false
            activeGestures = max(activeGestures - 1, 0)
            if activeGestures == 0 {
                onInteractionEnded(makeUpdate())
            }
        }
    }

    private func makeUpdate() -> StickerUpdate {
        let unitX = (currentCenter.x - safeRect.minX) / max(safeRect.width, 1)
        let unitY = (currentCenter.y - safeRect.minY) / max(safeRect.height, 1)
        let clamped = CGPoint(x: min(max(unitX, 0), 1), y: min(max(unitY, 0), 1))
        return StickerUpdate(
            centerUnit: clamped,
            scale: currentScale,
            rotation: currentRotation.degrees,
            isInDeleteZone: deleteZone.contains(currentCenter)
        )
    }
}

private struct SwiftyGifImageView: UIViewRepresentable {
    let gifIndex: Int
    let data: Data?
    let isAnimating: Bool

    private static let manager = SwiftyGifManager(memoryLimit: 60)

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        let dataCount = data?.count
        if context.coordinator.gifIndex != gifIndex || context.coordinator.dataCount != dataCount {
            context.coordinator.gifIndex = gifIndex
            context.coordinator.dataCount = dataCount
            if let data, let image = try? UIImage(imageData: data) {
                uiView.setImage(image, manager: Self.manager, loopCount: -1)
            }
        }
        if isAnimating {
            uiView.startAnimatingGif()
        } else {
            uiView.stopAnimatingGif()
        }
    }

    final class Coordinator {
        var gifIndex: Int?
        var dataCount: Int?
    }
}
