//
//  FeedViewModel.swift
//  newsfeed
//

import Combine
import Foundation

@MainActor
final class FeedViewModel {

    // MARK: - DI
    private let repository: NewsRepositoryProtocol

    // MARK: - Пагинация
    private(set) var items: [NewsItem] = []
    private var totalCount: Int = .max
    private var page: Int = 0
    private let pageSize: Int = 15
    private var lastLoadThreshold = 0

    private var isLoadingPage = false
    private var hasMore: Bool { items.count < totalCount }

    private var loadTask: Task<Void, Never>?

    // MARK: - State
    @Published private(set) var state: FeedState = .idle

    init(repository: NewsRepositoryProtocol) {
        self.repository = repository
    }

    deinit {
        loadTask?.cancel()
    }

    // MARK: - Public

    func loadFirstPage() {
        cancelLoading()
        items.removeAll()
        totalCount = .max
        page = 0
        lastLoadThreshold = 0
        state = .loading(isFirstPage: true)

        // Задержка для плавности
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            guard !Task.isCancelled else { return }
            loadNextPage()
        }
    }

    func refresh() {
        loadFirstPage()
    }

    func loadNextPageIfNeeded(visibleIndex: Int) {
        guard !isLoadingPage, hasMore, visibleIndex > lastLoadThreshold else {
            return
        }
        lastLoadThreshold = visibleIndex + 5
        loadNextPage()
    }

    // MARK: - Private

    private func loadNextPage() {
        guard !isLoadingPage, hasMore else { return }
        isLoadingPage = true
        let next = page + 1

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let pageData = try await repository.fetchPage(
                    page: next,
                    pageSize: pageSize
                )

                guard !Task.isCancelled else { return }

                page = next
                totalCount = max(totalCount, pageData.totalCount)
                items.append(contentsOf: pageData.items)

                if pageData.items.isEmpty {
                    totalCount = items.count
                }

                state = .loaded(items: items, canLoadMore: hasMore)
                isLoadingPage = false

            } catch is CancellationError {
                isLoadingPage = false
            } catch {
                isLoadingPage = false
                state = .error(
                    message: "Не удалось загрузить новости.",
                    canRetry: true
                )
            }
        }
    }

    func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
        isLoadingPage = false
    }
}
