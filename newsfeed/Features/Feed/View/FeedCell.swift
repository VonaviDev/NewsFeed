//
//  FeedCell.swift
//  newsfeed
//

import UIKit

extension UIColor {
    fileprivate static var autodocBurgundy: UIColor {
        UIColor(named: "AutodocBurgundy") ?? UIColor(red: 0.48, green: 0.00, blue: 0.15, alpha: 1.0)
    }
}

final class FeedCell: UICollectionViewCell {
    static let reuseID = "FeedCell"

    // MARK: UI
    private let imageView: UIImageView = {
        let v = UIImageView()
        v.contentMode = .scaleAspectFill
        v.clipsToBounds = true
        v.backgroundColor = .secondarySystemBackground
        v.image = UIImage(named: "placeholder")
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        v.setContentHuggingPriority(.defaultLow, for: .vertical)
        return v
    }()
    private let activity: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .medium)
        a.hidesWhenStopped = true
        return a
    }()
    private let titleLabel: UILabel = {
        let v = UILabel()
        v.font = .boldSystemFont(ofSize: 17)
        v.numberOfLines = 2
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return v
    }()
    private let dateLabel: UILabel = {
        let v = UILabel()
        v.font = .systemFont(ofSize: 13)
        v.textColor = .secondaryLabel
        v.numberOfLines = 1
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return v
    }()
    private let descLabel: UILabel = {
        let v = UILabel()
        v.font = .systemFont(ofSize: 15)
        v.numberOfLines = 3
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return v
    }()
    private let showMoreButton: UIButton = {
        let v = UIButton(type: .system)
        v.setTitle("Читать полностью", for: .normal)
        v.setTitleColor(.autodocBurgundy, for: .normal)
        v.titleLabel?.font = .boldSystemFont(ofSize: 15)
        v.contentHorizontalAlignment = .leading
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return v
    }()
    private let categoryChip: UILabel = {
        let v = UILabel()
        v.font = .systemFont(ofSize: 12, weight: .semibold)
        v.textColor = .label
        v.backgroundColor = .clear
        v.layer.cornerRadius = 12
        v.layer.masksToBounds = true
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.separator.cgColor
        v.isHidden = true
        v.setContentCompressionResistancePriority(.required, for: .vertical)
        return v
    }()
    private let pageControl: UIPageControl = {
        let v = UIPageControl()
        v.hidesForSinglePage = true
        return v
    }()
    private let menuButton: UIButton = {
        let v = UIButton(type: .system)
        v.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        return v
    }()

    // MARK: State
    private var currentImageTask: Task<Void, Never>?
    private var currentImageURL: URL?
    private weak var imageLoader: ImageLoading?
    private var didRequestImage = false
    private var retryCount = 0
    private let maxRetryCount = 2

    var onShowMore: (() -> Void)?
    var onMenu: (() -> Void)?

    // MARK: Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        showMoreButton.addTarget(self, action: #selector(tapShowMore), for: .touchUpInside)
        menuButton.addTarget(self, action: #selector(tapMenu), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { nil }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentImageTask?.cancel()
        currentImageTask = nil
        currentImageURL = nil
        didRequestImage = false
        retryCount = 0
        imageView.image = UIImage(named: "placeholder")
        pageControl.numberOfPages = 1
        pageControl.currentPage = 0
        onShowMore = nil
        onMenu = nil
        activity.stopAnimating()
    }

    func configure(with item: NewsItem, imageLoader: ImageLoading) {
        self.imageLoader = imageLoader

        titleLabel.text = (item.title?.isEmpty == false) ? item.title : "Без названия"
        descLabel.text  = (item.description?.isEmpty == false) ? item.description : "Без описания"
        dateLabel.text  = item.publishedAt.flatMap(UIHelpers.dateDMRu)

        if let cat = item.category, !cat.isEmpty {
            categoryChip.isHidden = false
            categoryChip.text = "  \(cat)  "
        } else {
            categoryChip.isHidden = true
            categoryChip.text = nil
        }

        pageControl.numberOfPages = 1
        pageControl.currentPage = 0

        currentImageURL = item.imageURL
        setNeedsLayout()
    }

    func triggerImageLoadIfNeeded() {
        guard !didRequestImage, let url = currentImageURL, let loader = imageLoader else { return }
        guard imageView.bounds.width > 0 else { return }

        didRequestImage = true
        activity.startAnimating()

        let expectedURL = url
        let w = imageView.bounds.width
        let targetSize = CGSize(width: w, height: w * (2.0 / 3.0))

        currentImageTask = Task { [weak self] in
            guard let self else { return }
            do {
                let img = try await loader.image(for: expectedURL, targetSize: targetSize, scale: UIScreen.main.scale)
                guard !Task.isCancelled else { return }
                guard self.currentImageURL == expectedURL else {
                    await MainActor.run { self.activity.stopAnimating() }
                    return
                }
                await MainActor.run {
                    UIView.transition(with: self.imageView, duration: 0.2, options: .transitionCrossDissolve) {
                        self.imageView.image = img
                    }
                    self.activity.stopAnimating()
                }
            } catch {
                await MainActor.run { self.activity.stopAnimating() }
                
                if self.retryCount < self.maxRetryCount {
                    self.retryCount += 1
                    self.didRequestImage = false
                }
            }
        }
    }

    // MARK: Layout
    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .systemBackground

        // Изображение (ratio 2:3)
        let imageWrap = UIView()
        imageWrap.translatesAutoresizingMaskIntoConstraints = false
        imageWrap.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageWrap.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        imageWrap.addSubview(imageView)
        imageWrap.addSubview(activity)
        imageWrap.addSubview(pageControl)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        activity.translatesAutoresizingMaskIntoConstraints = false
        pageControl.translatesAutoresizingMaskIntoConstraints = false

        let ratio = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 2.0/3.0)
        ratio.priority = .required

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: imageWrap.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageWrap.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageWrap.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageWrap.bottomAnchor),
            ratio,

            activity.centerXAnchor.constraint(equalTo: imageWrap.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: imageWrap.centerYAnchor),

            pageControl.bottomAnchor.constraint(equalTo: imageWrap.bottomAnchor, constant: -6),
            pageControl.centerXAnchor.constraint(equalTo: imageWrap.centerXAnchor),
        ])

        // Заголовок
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .top
        header.distribution = .fill
        header.spacing = 8

        let titleWrap = UIStackView(arrangedSubviews: [titleLabel, dateLabel])
        titleWrap.axis = .vertical
        titleWrap.spacing = 4

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        header.addArrangedSubview(titleWrap)
        header.addArrangedSubview(spacer)
        header.addArrangedSubview(menuButton)

        // Контент
        let contentStack = UIStackView(arrangedSubviews: [header, descLabel, showMoreButton])
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = .init(top: 12, leading: 16, bottom: 12, trailing: 16)
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])

        // Категория
        let categoryContainer = UIView()
        categoryContainer.translatesAutoresizingMaskIntoConstraints = false
        categoryContainer.addSubview(categoryChip)
        categoryChip.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            categoryChip.topAnchor.constraint(equalTo: categoryContainer.topAnchor, constant: 12),
            categoryChip.leadingAnchor.constraint(equalTo: categoryContainer.leadingAnchor, constant: 16),
            categoryChip.trailingAnchor.constraint(lessThanOrEqualTo: categoryContainer.trailingAnchor, constant: -16),
            categoryChip.bottomAnchor.constraint(lessThanOrEqualTo: categoryContainer.bottomAnchor, constant: -12),
            categoryChip.heightAnchor.constraint(greaterThanOrEqualToConstant: 24),
        ])

        // Общее
        let main = UIStackView(arrangedSubviews: [imageWrap, contentContainer, categoryContainer])
        main.axis = .vertical
        main.spacing = 0
        main.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(main)
        NSLayoutConstraint.activate([
            main.topAnchor.constraint(equalTo: contentView.topAnchor),
            main.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            main.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            main.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        triggerImageLoadIfNeeded()
    }

    // Для 1 колонки
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        setNeedsLayout()
        layoutIfNeeded()
        let size = contentView.systemLayoutSizeFitting(
            CGSize(width: layoutAttributes.size.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let attrs = super.preferredLayoutAttributesFitting(layoutAttributes)
        attrs.size = CGSize(width: layoutAttributes.size.width, height: ceil(size.height))
        return attrs
    }

    @objc private func tapShowMore() { onShowMore?() }
    @objc private func tapMenu()     { onMenu?() }
}
