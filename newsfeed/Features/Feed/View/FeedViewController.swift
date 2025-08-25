//
//  FeedViewController.swift
//  newsfeed
//

import Combine
import UIKit

final class FeedViewController: UIViewController,
    UICollectionViewDataSourcePrefetching,
    UICollectionViewDelegate, UIScrollViewDelegate
{
    // MARK: - DI
    private let viewModel: FeedViewModel
    private let imageLoader: ImageLoading

    // MARK: - UI
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, NewsItem>!
    private let refreshControl = UIRefreshControl()

    /// Спиннеры
    private let initialLoader: UIActivityIndicatorView = {
        let style: UIActivityIndicatorView.Style =
            UIDevice.current.userInterfaceIdiom == .pad ? .large : .large
        let v = UIActivityIndicatorView(style: style)
        v.hidesWhenStopped = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let bottomSpinner: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .medium)
        v.hidesWhenStopped = true
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    // MARK: - State
    private var cancellables = Set<AnyCancellable>()
    private var currentItems: [NewsItem] = []

    private let nextPageThreshold = 12
    private var preheatIndices = Set<Int>()
    private var lastPreheatOffsetY: CGFloat = .greatestFiniteMagnitude

    // MARK: - Init
    init(viewModel: FeedViewModel, imageLoader: ImageLoading = ImageLoader.shared) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
        title = "Новости"
    }
    required init?(coder: NSCoder) { nil }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupNav()
        setupCollection()
        setupLoaders()
        bind()
        viewModel.loadFirstPage()
    }

    private func setupNav() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }

    private func setupCollection() {
        collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: FeedLayout.make(
                containerWidth: view.bounds.width,
                trait: traitCollection
            )
        )
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.alwaysBounceVertical = true
        collectionView.contentInsetAdjustmentBehavior = .always
        collectionView.delegate = self
        collectionView.prefetchDataSource = self

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: FeedCell.reuseID)

        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        collectionView.refreshControl = refreshControl

        dataSource = UICollectionViewDiffableDataSource<Int, NewsItem>(collectionView: collectionView) { [weak self] cv, indexPath, item in
            guard let self else { return UICollectionViewCell() }
            guard let cell = cv.dequeueReusableCell(
                withReuseIdentifier: FeedCell.reuseID,
                for: indexPath
            ) as? FeedCell else {
                return UICollectionViewCell()
            }
            cell.configure(with: item, imageLoader: self.imageLoader)
            cell.onShowMore = { [weak self] in self?.openWeb(item.fullUrl ?? item.url) }
            cell.onMenu    = { [weak self, weak cell] in self?.presentMenu(for: item, from: cell) }
            return cell
        }
    }

    private func setupLoaders() {
        // центральный спиннер
        view.addSubview(initialLoader)
        NSLayoutConstraint.activate([
            initialLoader.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            initialLoader.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // нижний спиннер
        view.addSubview(bottomSpinner)
        NSLayoutConstraint.activate([
            bottomSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomSpinner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    private func bind() {
        viewModel.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }

                switch state {
                case .idle:
                    self.hideInitialLoader()
                    self.hideBottomLoader()

                case .loading(let isFirst):
                    if isFirst {
                        self.showInitialLoader()
                        self.hideBottomLoader()
                    } else {
                        self.hideInitialLoader()
                        self.showBottomLoader()
                    }

                case .loaded(let items, _):
                    self.hideInitialLoader()
                    self.hideBottomLoader()

                    self.currentItems = items
                    var snap = NSDiffableDataSourceSnapshot<Int, NewsItem>()
                    snap.appendSections([0])
                    snap.appendItems(items)
                    let animate = items.count < 1500 && !self.collectionView.isDecelerating
                    self.dataSource.apply(snap, animatingDifferences: animate)

                    self.refreshControl.endRefreshing()
                    self.forceLoadVisibleImages()
                    self.updatePreheat(always: true)

                case .error(let message, let canRetry):
                    self.hideInitialLoader()
                    self.hideBottomLoader()
                    self.refreshControl.endRefreshing()

                    let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
                    if canRetry {
                        alert.addAction(UIAlertAction(title: "Повторить", style: .default) { [weak self] _ in
                            self?.viewModel.refresh()
                        })
                    }
                    alert.addAction(UIAlertAction(title: "Ок", style: .cancel))
                    self.present(alert, animated: true)
                }
            }
            .store(in: &cancellables)
    }

    @objc private func refreshPulled() { viewModel.refresh() }

    // MARK: - Loaders UI
    private func showInitialLoader() {
        view.bringSubviewToFront(initialLoader)
        initialLoader.startAnimating()
        initialLoader.isHidden = false
    }
    private func hideInitialLoader() {
        initialLoader.stopAnimating()
        initialLoader.isHidden = true
    }
    private func showBottomLoader() {
        view.bringSubviewToFront(bottomSpinner)
        bottomSpinner.isHidden = false
        bottomSpinner.startAnimating()
    }
    private func hideBottomLoader() {
        bottomSpinner.stopAnimating()
        bottomSpinner.isHidden = true
    }

    // MARK: - Пагинация
    private func triggerPaginationIfNeeded(visibleIndex: Int) {
        guard !currentItems.isEmpty else { return }
        if visibleIndex >= currentItems.count - nextPageThreshold {
            viewModel.loadNextPageIfNeeded(visibleIndex: visibleIndex)
        }
    }

    private func triggerPaginationByOffset() {
        let y = collectionView.contentOffset.y
        let h = collectionView.bounds.height
        let contentH = collectionView.contentSize.height
        if y + h * 1.2 >= contentH {
            viewModel.loadNextPageIfNeeded(visibleIndex: currentItems.count - 1)
        }
    }

    private func forceLoadVisibleImages() {
        for case let cell as FeedCell in collectionView.visibleCells {
            cell.triggerImageLoadIfNeeded()
        }
    }

    private func updatePreheat(always: Bool) {
        guard !currentItems.isEmpty else { return }
        let visible = collectionView.indexPathsForVisibleItems.map(\.item)
        guard !visible.isEmpty else { return }

        let first = visible.min()!
        let last  = visible.max()!

        let ahead = 36
        let behind = 12
        let start = max(0, first - behind)
        let end   = min(currentItems.count - 1, last + ahead)

        let newSet = Set<Int>(start...end)

        if always {
            let urls = newSet.compactMap { currentItems[$0].imageURL }
            imageLoader.prefetch(urls: urls)
            preheatIndices = newSet
            return
        }

        let toAdd = newSet.subtracting(preheatIndices)
        let toRemove = preheatIndices.subtracting(newSet)

        if !toAdd.isEmpty {
            imageLoader.prefetch(urls: toAdd.sorted().compactMap { currentItems[$0].imageURL })
        }
        if !toRemove.isEmpty {
            imageLoader.cancelPrefetch(urls: toRemove.sorted().compactMap { currentItems[$0].imageURL })
        }

        preheatIndices = newSet
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            let newLayout = FeedLayout.make(containerWidth: size.width, trait: self.traitCollection)
            self.collectionView.setCollectionViewLayout(newLayout, animated: false)
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: { _ in
            self.forceLoadVisibleImages()
            self.updatePreheat(always: true)
        })
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        let newLayout = FeedLayout.make(containerWidth: view.bounds.width, trait: traitCollection)
        collectionView.setCollectionViewLayout(newLayout, animated: false)
        collectionView.collectionViewLayout.invalidateLayout()
        forceLoadVisibleImages()
        updatePreheat(always: true)
    }

    private func openWeb(_ url: URL?) {
        guard let url else { return }
        FeedRouter.openWeb(from: self, url: url)
    }

    private func presentMenu(for item: NewsItem, from sourceView: UIView?) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Поделиться", style: .default) { [weak self] _ in
            guard let self else { return }
            let toShare: [Any] = [item.fullUrl ?? item.url].compactMap { $0 }
            let ac = UIActivityViewController(activityItems: toShare, applicationActivities: nil)
            if let pop = ac.popoverPresentationController {
                pop.sourceView = sourceView ?? self.view
                pop.sourceRect = sourceView?.bounds ?? CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
            }
            self.present(ac, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Скопировать ссылку", style: .default) { _ in
            UIPasteboard.general.string = (item.fullUrl ?? item.url)?.absoluteString
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = sourceView ?? view
            pop.sourceRect = sourceView?.bounds ?? CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        if let maxIdx = indexPaths.map(\.item).max() {
            triggerPaginationIfNeeded(visibleIndex: maxIdx)
        }
        let urls = indexPaths.compactMap { idx -> URL? in
            guard currentItems.indices.contains(idx.item) else { return nil }
            return currentItems[idx.item].imageURL
        }
        imageLoader.prefetch(urls: urls)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let urls = indexPaths.compactMap { idx -> URL? in
            guard currentItems.indices.contains(idx.item) else { return nil }
            return currentItems[idx.item].imageURL
        }
        imageLoader.cancelPrefetch(urls: urls)
    }

    // MARK: - Делегаты
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        triggerPaginationIfNeeded(visibleIndex: indexPath.item)
        (cell as? FeedCell)?.triggerImageLoadIfNeeded()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        triggerPaginationByOffset()
        let y = scrollView.contentOffset.y
        let delta = abs(y - lastPreheatOffsetY)
        if delta > view.bounds.height / 3 {
            lastPreheatOffsetY = y
            updatePreheat(always: false)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            forceLoadVisibleImages()
            updatePreheat(always: true)
        }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        forceLoadVisibleImages()
        updatePreheat(always: true)
    }
}
