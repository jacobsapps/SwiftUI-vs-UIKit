import UIKit
import SwiftyGif
import PerformanceShared

final class FeedViewController: UIViewController {
    private let viewModel: FeedViewModel
    private let assetStore: AssetStore
    private let collectionView: UICollectionView
    private let statsToolbarView = StatsToolbarView()
    private let navBarGradientView = GradientView(
        colors: [FeedSpec.NavigationBar.gradientTop, FeedSpec.NavigationBar.gradientBottom],
        startPoint: CGPoint(x: 0.5, y: 0.0),
        endPoint: CGPoint(x: 0.5, y: 1.0)
    )
    private var currentStatsItemID: Int?
    private var navBarGradientHeightConstraint: NSLayoutConstraint?

    init(viewModel: FeedViewModel, assetStore: AssetStore) {
        self.viewModel = viewModel
        self.assetStore = assetStore
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = FeedSpec.Layout.interItemSpacing
        layout.sectionInset = FeedSpec.Layout.sectionInset
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = FeedSpec.Background.topColor
        configureNavigationBar()

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = true
        collectionView.contentInset = FeedSpec.Layout.contentInsets
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: FeedCell.reuseIdentifier)
        collectionView.backgroundView = GradientView(
            colors: [FeedSpec.Background.topColor, FeedSpec.Background.bottomColor],
            startPoint: CGPoint(x: 0.5, y: 0.0),
            endPoint: CGPoint(x: 0.5, y: 1.0)
        )

        navBarGradientView.translatesAutoresizingMaskIntoConstraints = false
        navBarGradientView.isUserInteractionEnabled = false

        view.addSubview(collectionView)
        view.addSubview(navBarGradientView)
        view.addSubview(statsToolbarView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            navBarGradientView.topAnchor.constraint(equalTo: view.topAnchor),
            navBarGradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBarGradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            statsToolbarView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statsToolbarView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -FeedSpec.StatsToolbar.bottomInset),
            statsToolbarView.widthAnchor.constraint(equalToConstant: FeedSpec.StatsToolbar.size.width),
            statsToolbarView.heightAnchor.constraint(equalToConstant: FeedSpec.StatsToolbar.size.height)
        ])

        navBarGradientHeightConstraint = navBarGradientView.heightAnchor.constraint(equalToConstant: 0)
        navBarGradientHeightConstraint?.isActive = true

        viewModel.onItemsAppended = { [weak self] range in
            self?.insertItems(range: range)
        }
        viewModel.onItemUpdated = { [weak self] index in
            self?.collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
        }
        viewModel.loadInitialIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateToolbarStats(force: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let navBarHeight = navigationController?.navigationBar.frame.height ?? 44
        navBarGradientHeightConstraint?.constant = view.safeAreaInsets.top + navBarHeight
    }

    private func configureNavigationBar() {
        title = "UIKit Performance"
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .font: FeedSpec.NavigationBar.titleFont,
            .foregroundColor: FeedSpec.NavigationBar.titleColor
        ]
        appearance.largeTitleTextAttributes = [
            .font: FeedSpec.NavigationBar.largeTitleFont,
            .foregroundColor: FeedSpec.NavigationBar.titleColor
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
    }

    private func insertItems(range: Range<Int>) {
        let indexPaths = range.map { IndexPath(item: $0, section: 0) }
        guard !indexPaths.isEmpty else { return }
        collectionView.performBatchUpdates({
            collectionView.insertItems(at: indexPaths)
        }, completion: { [weak self] _ in
            self?.updateToolbarStats(force: true)
        })
    }

    private func updateToolbarStats(force: Bool = false) {
        guard let indexPath = collectionView.indexPathsForVisibleItems.min(by: { $0.item < $1.item }) else {
            return
        }
        let item = viewModel.visibleItems[indexPath.item]
        if !force, currentStatsItemID == item.id {
            return
        }
        currentStatsItemID = item.id
        statsToolbarView.update(cpu: item.stats.cpu, gpu: item.stats.gpu)
    }
}

extension FeedViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.visibleItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FeedCell.reuseIdentifier,
            for: indexPath
        ) as? FeedCell else {
            return UICollectionViewCell()
        }
        let item = viewModel.visibleItems[indexPath.item]
        cell.configure(with: item, assetStore: assetStore)
        cell.onStickerUpdated = { [weak self] itemID, stickerID, centerUnit, scale, rotation in
            self?.viewModel.updateSticker(
                itemID: itemID,
                stickerID: stickerID,
                centerUnit: centerUnit,
                scale: scale,
                rotation: rotation
            )
        }
        cell.onStickerDeleted = { [weak self] itemID, stickerID in
            self?.viewModel.deleteSticker(itemID: itemID, stickerID: stickerID)
        }
        return cell
    }
}

extension FeedViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let item = viewModel.visibleItems[indexPath.item]
        let width = collectionView.bounds.width - collectionView.contentInset.left - collectionView.contentInset.right
        return CGSize(width: width, height: item.height)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        viewModel.loadNextPageIfNeeded(currentIndex: indexPath.item)
        (cell as? FeedCell)?.setAnimationsRunning(true)
        updateToolbarStats()
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        (cell as? FeedCell)?.setAnimationsRunning(false)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateToolbarStats()
    }
}

final class FeedCell: UICollectionViewCell {
    static let reuseIdentifier = "FeedCell"

    var onStickerUpdated: ((Int, Int, CGPoint, CGFloat, CGFloat) -> Void)?
    var onStickerDeleted: ((Int, Int) -> Void)?

    private let shadowContainer = UIView()
    private let cardView = UIView()
    private let backgroundImageView = UIImageView()
    private let topGradientView = GradientView(
        colors: [
            UIColor.black.withAlphaComponent(FeedSpec.Cell.topGradientStartAlpha),
            UIColor.black.withAlphaComponent(FeedSpec.Cell.topGradientEndAlpha)
        ],
        startPoint: CGPoint(x: 0.5, y: 0.0),
        endPoint: CGPoint(x: 0.5, y: 1.0)
    )
    private let bottomGradientView = GradientView(
        colors: [
            UIColor.black.withAlphaComponent(FeedSpec.Cell.bottomGradientStartAlpha),
            UIColor.black.withAlphaComponent(FeedSpec.Cell.bottomGradientEndAlpha)
        ],
        startPoint: CGPoint(x: 0.5, y: 0.0),
        endPoint: CGPoint(x: 0.5, y: 1.0)
    )
    private let glowView = GlowView()
    private let deletionZoneView = DeletionZoneView()
    private let stickerContainerView = UIView()
    private let badgeStack = UIStackView()
    private let titleStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let borderLayer = CAShapeLayer()

    private var assetStore: AssetStore?
    private var stickers: [Sticker] = []
    private var stickerViews: [Int: StickerView] = [:]
    private var activeInteractions = 0
    private var itemID: Int = 0
    private var itemHeight: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setAnimationsRunning(false)
        stickerViews.values.forEach {
            $0.cleanup()
            $0.removeFromSuperview()
        }
        stickerViews.removeAll()
        stickers.removeAll()
        assetStore = nil
        onStickerUpdated = nil
        onStickerDeleted = nil
        backgroundImageView.image = nil
    }

    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        setNeedsLayout()
    }

    func configure(with item: FeedItem, assetStore: AssetStore) {
        self.assetStore = assetStore
        self.itemID = item.id
        self.itemHeight = item.height
        self.stickers = item.stickers

        backgroundImageView.image = assetStore.wallpaperImage(index: item.wallpaperIndex)
        if !FeedSpec.Glow.palette.isEmpty {
            let index = (item.id - 1) % FeedSpec.Glow.palette.count
            glowView.configure(color: FeedSpec.Glow.palette[index])
        }
        titleLabel.text = item.title
        subtitleLabel.text = subtitleText(stickerCount: item.stickers.count)

        setupStickers()
        contentView.layoutIfNeeded()
        layoutStickers()
        setNeedsLayout()
    }

    func setAnimationsRunning(_ isRunning: Bool) {
        if isRunning {
            glowView.startAnimating()
        } else {
            glowView.stopAnimating()
        }
        stickerViews.values.forEach { $0.setAnimating(isRunning) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shadowContainer.layer.shadowPath = UIBezierPath(
            roundedRect: shadowContainer.bounds,
            cornerRadius: FeedSpec.Cell.cornerRadius
        ).cgPath

        let borderInset = FeedSpec.Cell.innerBorderInset
        let borderRect = cardView.bounds.insetBy(dx: borderInset, dy: borderInset)
        borderLayer.frame = cardView.bounds
        borderLayer.path = UIBezierPath(
            roundedRect: borderRect,
            cornerRadius: max(FeedSpec.Cell.cornerRadius - borderInset, 0)
        ).cgPath
        borderLayer.lineWidth = FeedSpec.Cell.innerBorderWidth
        borderLayer.strokeColor = FeedSpec.Cell.innerBorderColor.cgColor
        borderLayer.fillColor = UIColor.clear.cgColor

        layoutStickers()
    }

    private func setupViews() {
        contentView.backgroundColor = .clear

        shadowContainer.translatesAutoresizingMaskIntoConstraints = false
        cardView.translatesAutoresizingMaskIntoConstraints = false
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        topGradientView.translatesAutoresizingMaskIntoConstraints = false
        bottomGradientView.translatesAutoresizingMaskIntoConstraints = false
        glowView.translatesAutoresizingMaskIntoConstraints = false
        deletionZoneView.translatesAutoresizingMaskIntoConstraints = false
        stickerContainerView.translatesAutoresizingMaskIntoConstraints = false
        badgeStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.translatesAutoresizingMaskIntoConstraints = false

        shadowContainer.layer.shadowColor = FeedSpec.Cell.shadowColor.cgColor
        shadowContainer.layer.shadowOpacity = 1.0
        shadowContainer.layer.shadowRadius = FeedSpec.Cell.shadowRadius
        shadowContainer.layer.shadowOffset = FeedSpec.Cell.shadowOffset

        cardView.layer.cornerRadius = FeedSpec.Cell.cornerRadius
        cardView.clipsToBounds = true

        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true

        topGradientView.isUserInteractionEnabled = false
        bottomGradientView.isUserInteractionEnabled = false
        glowView.isUserInteractionEnabled = false

        stickerContainerView.isUserInteractionEnabled = true
        stickerContainerView.backgroundColor = .clear

        badgeStack.axis = .horizontal
        badgeStack.alignment = .leading
        badgeStack.spacing = FeedSpec.Badge.spacing
        badgeStack.addArrangedSubview(makeBadgeLabel(text: "FEED"))
        badgeStack.addArrangedSubview(makeBadgeLabel(text: "LIVE"))

        titleStack.axis = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = FeedSpec.Title.spacing
        titleLabel.font = FeedSpec.Title.titleFont
        titleLabel.textColor = FeedSpec.Title.titleColor
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = FeedSpec.Title.subtitleFont
        subtitleLabel.textColor = FeedSpec.Title.subtitleColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(subtitleLabel)

        contentView.addSubview(shadowContainer)
        shadowContainer.addSubview(cardView)
        cardView.addSubview(backgroundImageView)
        cardView.addSubview(topGradientView)
        cardView.addSubview(bottomGradientView)
        cardView.addSubview(glowView)
        cardView.addSubview(deletionZoneView)
        cardView.addSubview(stickerContainerView)
        cardView.addSubview(badgeStack)
        cardView.addSubview(titleStack)

        let topGradientHeight = topGradientView.heightAnchor.constraint(
            equalTo: cardView.heightAnchor,
            multiplier: FeedSpec.Cell.topGradientHeightFactor
        )
        let bottomGradientHeight = bottomGradientView.heightAnchor.constraint(
            equalToConstant: FeedSpec.Cell.bottomGradientHeight
        )
        bottomGradientHeight.priority = .defaultHigh
        let bottomGradientMaxHeight = bottomGradientView.heightAnchor.constraint(
            lessThanOrEqualTo: cardView.heightAnchor
        )

        NSLayoutConstraint.activate([
            shadowContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            shadowContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            shadowContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            shadowContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            cardView.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor),

            backgroundImageView.topAnchor.constraint(equalTo: cardView.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            topGradientView.topAnchor.constraint(equalTo: cardView.topAnchor),
            topGradientView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            topGradientView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            topGradientHeight,

            bottomGradientView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            bottomGradientView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            bottomGradientView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            bottomGradientHeight,
            bottomGradientMaxHeight,

            glowView.topAnchor.constraint(equalTo: cardView.topAnchor),
            glowView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            glowView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            glowView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            deletionZoneView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            deletionZoneView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            deletionZoneView.widthAnchor.constraint(equalToConstant: FeedSpec.DeletionZone.size),
            deletionZoneView.heightAnchor.constraint(equalToConstant: FeedSpec.DeletionZone.size),

            stickerContainerView.topAnchor.constraint(equalTo: cardView.topAnchor),
            stickerContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            stickerContainerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            stickerContainerView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            badgeStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: FeedSpec.Badge.inset.top),
            badgeStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: FeedSpec.Badge.inset.left),

            titleStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: FeedSpec.Title.inset.left),
            titleStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -FeedSpec.Title.inset.bottom),
            titleStack.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor,
                                               constant: -FeedSpec.Title.inset.right)
        ])

        borderLayer.zPosition = 1000
        cardView.layer.addSublayer(borderLayer)
    }

    private func makeBadgeLabel(text: String) -> PaddedLabel {
        let label = PaddedLabel()
        label.text = text
        label.font = FeedSpec.Badge.font
        label.textColor = FeedSpec.Badge.textColor
        label.backgroundColor = FeedSpec.Badge.backgroundColor
        label.layer.cornerRadius = FeedSpec.Badge.cornerRadius
        label.layer.borderWidth = FeedSpec.Badge.borderWidth
        label.layer.borderColor = FeedSpec.Badge.borderColor.cgColor
        label.clipsToBounds = true
        label.textAlignment = .center
        label.textInsets = UIEdgeInsets(top: 4, left: FeedSpec.Badge.horizontalPadding, bottom: 4,
                                        right: FeedSpec.Badge.horizontalPadding)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.heightAnchor.constraint(equalToConstant: FeedSpec.Badge.height)
        ])
        return label
    }

    private func subtitleText(stickerCount: Int) -> String {
        String(format: "ID %04d \u{2022} %d stickers \u{2022} %dpt", itemID, stickerCount, Int(itemHeight))
    }

    private func setupStickers() {
        stickerViews.values.forEach {
            $0.cleanup()
            $0.removeFromSuperview()
        }
        stickerViews.removeAll()
        for sticker in stickers {
            let stickerView = StickerView(stickerID: sticker.id, baseSize: sticker.baseSize)
            if let data = assetStore?.gifData(index: sticker.gifIndex) {
                stickerView.setGIFData(data)
            }
            stickerView.applyTransform(scale: sticker.scale, rotation: sticker.rotation)
            stickerView.onInteractionBegan = { [weak self] view in
                self?.handleInteractionBegan(for: view)
            }
            stickerView.onInteractionChanged = { [weak self] view in
                self?.handleInteractionChanged(for: view)
            }
            stickerView.onInteractionEnded = { [weak self] view in
                self?.handleInteractionEnded(for: view)
            }
            stickerContainerView.addSubview(stickerView)
            stickerViews[sticker.id] = stickerView
        }
    }

    private func layoutStickers() {
        let safeRect = cardView.bounds.inset(by: FeedSpec.Sticker.safeInsets)
        guard safeRect.width > 0, safeRect.height > 0 else { return }
        for sticker in stickers {
            guard let view = stickerViews[sticker.id] else { continue }
            let center = CGPoint(
                x: safeRect.minX + sticker.centerUnit.x * safeRect.width,
                y: safeRect.minY + sticker.centerUnit.y * safeRect.height
            )
            view.center = center
        }
    }

    private func handleInteractionBegan(for stickerView: StickerView) {
        activeInteractions += 1
        deletionZoneView.setVisible(true, animated: true)
        stickerContainerView.bringSubviewToFront(stickerView)
        updateDeletionState(for: stickerView)
    }

    private func handleInteractionChanged(for stickerView: StickerView) {
        updateDeletionState(for: stickerView)
    }

    private func handleInteractionEnded(for stickerView: StickerView) {
        activeInteractions = max(activeInteractions - 1, 0)
        let isInZone = deletionZoneView.frame.contains(stickerView.center)
        if isInZone {
            deleteSticker(stickerView)
        } else {
            updateSticker(stickerView)
        }
        if activeInteractions == 0 {
            deletionZoneView.setVisible(false, animated: true)
            deletionZoneView.setHighlighted(false)
        }
    }

    private func updateDeletionState(for stickerView: StickerView) {
        let isInside = deletionZoneView.frame.contains(stickerView.center)
        deletionZoneView.setHighlighted(isInside)
        stickerView.setHighlighted(isInside)
    }

    private func updateSticker(_ stickerView: StickerView) {
        guard let index = stickers.firstIndex(where: { $0.id == stickerView.stickerID }) else { return }
        let safeRect = cardView.bounds.inset(by: FeedSpec.Sticker.safeInsets)
        guard safeRect.width > 0, safeRect.height > 0 else { return }

        let unitX = (stickerView.center.x - safeRect.minX) / safeRect.width
        let unitY = (stickerView.center.y - safeRect.minY) / safeRect.height
        let centerUnit = CGPoint(
            x: min(max(unitX, 0), 1),
            y: min(max(unitY, 0), 1)
        )
        let scale = stickerView.currentScale
        let rotation = stickerView.currentRotationDegrees

        stickers[index].centerUnit = centerUnit
        stickers[index].scale = scale
        stickers[index].rotation = rotation

        onStickerUpdated?(itemID, stickerView.stickerID, centerUnit, scale, rotation)
    }

    private func deleteSticker(_ stickerView: StickerView) {
        let stickerID = stickerView.stickerID
        stickers.removeAll { $0.id == stickerID }
        stickerView.cleanup()
        stickerView.removeFromSuperview()
        stickerViews.removeValue(forKey: stickerID)
        subtitleLabel.text = subtitleText(stickerCount: stickers.count)
        onStickerDeleted?(itemID, stickerID)
    }
}

final class StickerView: UIView, UIGestureRecognizerDelegate {
    let stickerID: Int
    private static let gifManager = SwiftyGifManager(memoryLimit: 60)
    private let gifImageView = UIImageView()
    private(set) var baseSize: CGSize
    private(set) var gestureTransform = CGAffineTransform.identity
    private weak var parentScrollView: UIScrollView?
    private let panGesture = UIPanGestureRecognizer()
    private let pinchGesture = UIPinchGestureRecognizer()
    private let rotateGesture = UIRotationGestureRecognizer()

    var onInteractionBegan: ((StickerView) -> Void)?
    var onInteractionChanged: ((StickerView) -> Void)?
    var onInteractionEnded: ((StickerView) -> Void)?

    private var highlightScale: CGFloat = 1.0
    private var activeGestures = 0

    init(stickerID: Int, baseSize: CGSize) {
        self.stickerID = stickerID
        self.baseSize = baseSize
        super.init(frame: CGRect(origin: .zero, size: baseSize))
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setGIFData(_ data: Data) {
        if let image = try? UIImage(imageData: data) {
            gifImageView.setImage(image, manager: Self.gifManager, loopCount: -1)
        }
    }

    func setAnimating(_ isRunning: Bool) {
        if isRunning {
            gifImageView.startAnimatingGif()
        } else {
            gifImageView.stopAnimatingGif()
        }
    }

    func cleanup() {
        gifImageView.stopAnimatingGif()
        Self.gifManager.deleteImageView(gifImageView)
        gifImageView.image = nil
    }

    func applyTransform(scale: CGFloat, rotation: CGFloat) {
        let rotationRadians = rotation * .pi / 180
        gestureTransform = CGAffineTransform.identity
            .rotated(by: rotationRadians)
            .scaledBy(x: scale, y: scale)
        updateTransform()
    }

    func setHighlighted(_ highlighted: Bool) {
        highlightScale = highlighted ? 0.9 : 1.0
        alpha = highlighted ? 0.8 : 1.0
        updateTransform()
    }

    var currentScale: CGFloat {
        sqrt(gestureTransform.a * gestureTransform.a + gestureTransform.c * gestureTransform.c)
    }

    var currentRotationDegrees: CGFloat {
        atan2(gestureTransform.b, gestureTransform.a) * 180 / .pi
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gifImageView.frame = bounds
        gifImageView.layer.cornerRadius = FeedSpec.Sticker.cornerRadius
        gifImageView.clipsToBounds = true

        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: FeedSpec.Sticker.cornerRadius).cgPath
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let scrollView = nearestScrollView(), scrollView !== parentScrollView else { return }
        parentScrollView = scrollView
        scrollView.panGestureRecognizer.require(toFail: panGesture)
        scrollView.panGestureRecognizer.require(toFail: pinchGesture)
        scrollView.panGestureRecognizer.require(toFail: rotateGesture)
    }

    private func setupView() {
        isUserInteractionEnabled = true
        backgroundColor = .clear
        layer.shadowColor = FeedSpec.Sticker.shadowColor.cgColor
        layer.shadowOpacity = 1.0
        layer.shadowRadius = FeedSpec.Sticker.shadowRadius
        layer.shadowOffset = FeedSpec.Sticker.shadowOffset
        layer.borderWidth = FeedSpec.Sticker.borderWidth
        layer.borderColor = FeedSpec.Sticker.borderColor.cgColor
        layer.cornerRadius = FeedSpec.Sticker.cornerRadius

        gifImageView.contentMode = .scaleAspectFit
        addSubview(gifImageView)

        panGesture.addTarget(self, action: #selector(handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = self

        pinchGesture.addTarget(self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self

        rotateGesture.addTarget(self, action: #selector(handleRotation(_:)))
        rotateGesture.delegate = self

        addGestureRecognizer(panGesture)
        addGestureRecognizer(pinchGesture)
        addGestureRecognizer(rotateGesture)
    }

    private func nearestScrollView() -> UIScrollView? {
        var view = superview
        while let current = view {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            view = current.superview
        }
        return nil
    }

    private func updateTransform() {
        transform = gestureTransform.scaledBy(x: highlightScale, y: highlightScale)
    }

    private func beginInteractionIfNeeded() {
        if activeGestures == 0 {
            onInteractionBegan?(self)
        }
        activeGestures += 1
    }

    private func endInteractionIfNeeded() {
        activeGestures = max(activeGestures - 1, 0)
        if activeGestures == 0 {
            onInteractionEnded?(self)
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            beginInteractionIfNeeded()
        case .changed:
            let translation = recognizer.translation(in: superview)
            center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
            recognizer.setTranslation(.zero, in: superview)
            onInteractionChanged?(self)
        case .ended, .cancelled:
            endInteractionIfNeeded()
        default:
            break
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            beginInteractionIfNeeded()
        case .changed:
            gestureTransform = gestureTransform.scaledBy(x: recognizer.scale, y: recognizer.scale)
            recognizer.scale = 1.0
            updateTransform()
            onInteractionChanged?(self)
        case .ended, .cancelled:
            endInteractionIfNeeded()
        default:
            break
        }
    }

    @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        switch recognizer.state {
        case .began:
            beginInteractionIfNeeded()
        case .changed:
            gestureTransform = gestureTransform.rotated(by: recognizer.rotation)
            recognizer.rotation = 0
            updateTransform()
            onInteractionChanged?(self)
        case .ended, .cancelled:
            endInteractionIfNeeded()
        default:
            break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let scrollView = parentScrollView,
           otherGestureRecognizer === scrollView.panGestureRecognizer {
            return false
        }
        return true
    }
}

final class GlowView: UIView {
    private let tailLayers: [CAGradientLayer]
    private let dotLayers: [CALayer]
    private let animationKey = "glow.path"
    private var glowColor: UIColor = FeedSpec.Glow.palette.first ?? .systemCyan

    override init(frame: CGRect) {
        let firstTail = CAGradientLayer()
        let secondTail = CAGradientLayer()
        let firstDot = CALayer()
        let secondDot = CALayer()
        tailLayers = [firstTail, secondTail]
        dotLayers = [firstDot, secondDot]
        super.init(frame: frame)
        isUserInteractionEnabled = false
        tailLayers.forEach { layer.addSublayer($0) }
        dotLayers.forEach { layer.addSublayer($0) }
        configureLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configureLayers()
    }

    func configure(color: UIColor) {
        glowColor = color
        updateColors()
    }

    func startAnimating() {
        guard tailLayers.first?.animation(forKey: animationKey) == nil else { return }
        let path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: FeedSpec.Glow.pathInset, dy: FeedSpec.Glow.pathInset),
            cornerRadius: max(FeedSpec.Cell.cornerRadius - FeedSpec.Glow.pathInset, 0)
        ).cgPath

        let baseTime = CACurrentMediaTime()
        let offset = FeedSpec.Glow.duration / 2.0

        for (index, tailLayer) in tailLayers.enumerated() {
            let animation = makeAnimation(path: path, beginTime: baseTime + (index == 0 ? 0 : offset))
            tailLayer.add(animation, forKey: animationKey)
        }
    }

    func stopAnimating() {
        tailLayers.forEach { $0.removeAnimation(forKey: animationKey) }
        dotLayers.forEach { $0.removeAnimation(forKey: animationKey) }
    }

    private func makeAnimation(path: CGPath, beginTime: CFTimeInterval) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "position")
        animation.path = path
        animation.duration = FeedSpec.Glow.duration
        animation.repeatCount = .infinity
        animation.calculationMode = .paced
        animation.rotationMode = .rotateAuto
        animation.isRemovedOnCompletion = false
        animation.beginTime = beginTime
        return animation
    }

    private func configureLayers() {
        for tailLayer in tailLayers {
            tailLayer.frame = CGRect(x: 0, y: 0, width: FeedSpec.Glow.tailLength, height: FeedSpec.Glow.tailWidth)
            tailLayer.cornerRadius = FeedSpec.Glow.tailWidth / 2
            tailLayer.anchorPoint = CGPoint(x: 1, y: 0.5)
            tailLayer.startPoint = CGPoint(x: 0, y: 0.5)
            tailLayer.endPoint = CGPoint(x: 1, y: 0.5)
        }

        for dotLayer in dotLayers {
            dotLayer.isHidden = true
        }

        updateColors()
    }

    private func updateColors() {
        let headColor = glowColor.withAlphaComponent(FeedSpec.Glow.headAlpha)
        let tailColor = glowColor.withAlphaComponent(FeedSpec.Glow.tailAlpha)
        for tailLayer in tailLayers {
            tailLayer.colors = [tailColor.cgColor, headColor.cgColor]
        }
    }
}

final class DeletionZoneView: UIView {
    private let gradientLayer = CAGradientLayer()
    private var isHighlighted = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        alpha = 0.0
        layer.addSublayer(gradientLayer)
        configureLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    func setVisible(_ visible: Bool, animated: Bool) {
        let targetAlpha: CGFloat = visible ? 1.0 : 0.0
        if animated {
            UIView.animate(withDuration: 0.15) { [weak self] in
                self?.alpha = targetAlpha
            }
        } else {
            alpha = targetAlpha
        }
    }

    func setHighlighted(_ highlighted: Bool) {
        guard highlighted != isHighlighted else { return }
        isHighlighted = highlighted
        configureLayers()
    }

    private func configureLayers() {
        let color = isHighlighted ? FeedSpec.DeletionZone.highlightColor : FeedSpec.DeletionZone.baseColor
        gradientLayer.colors = [color.cgColor, UIColor.clear.cgColor]
        gradientLayer.startPoint = CGPoint(x: 1, y: 1)
        gradientLayer.endPoint = CGPoint(x: 0, y: 0)
    }
}

final class GradientView: UIView {
    private let colors: [UIColor]
    private let startPoint: CGPoint
    private let endPoint: CGPoint

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    init(colors: [UIColor], startPoint: CGPoint, endPoint: CGPoint) {
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
        super.init(frame: .zero)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        guard let gradientLayer = layer as? CAGradientLayer else { return }
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
    }
}

final class StatsToolbarView: UIView {
    private let cpuLabel = UILabel()
    private let gpuLabel = UILabel()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(cpu: Int, gpu: Int) {
        cpuLabel.text = "CPU \(cpu)%"
        gpuLabel.text = "GPU \(gpu)%"
    }

    private func setupView() {
        backgroundColor = FeedSpec.StatsToolbar.backgroundColor
        layer.cornerRadius = FeedSpec.StatsToolbar.cornerRadius
        layer.borderColor = FeedSpec.StatsToolbar.borderColor.cgColor
        layer.borderWidth = FeedSpec.StatsToolbar.borderWidth

        cpuLabel.font = FeedSpec.StatsToolbar.font
        cpuLabel.textColor = FeedSpec.StatsToolbar.textColor
        gpuLabel.font = FeedSpec.StatsToolbar.font
        gpuLabel.textColor = FeedSpec.StatsToolbar.textColor

        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        stackView.addArrangedSubview(cpuLabel)
        stackView.addArrangedSubview(gpuLabel)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ])
    }
}

final class PaddedLabel: UILabel {
    var textInsets = UIEdgeInsets.zero {
        didSet {
            invalidateIntrinsicContentSize()
            setNeedsDisplay()
        }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + textInsets.left + textInsets.right,
            height: size.height + textInsets.top + textInsets.bottom
        )
    }
}
