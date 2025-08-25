//
//  FeedState.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 24.08.2025.
//

import Foundation

/// Состояние экрана новостей
enum FeedState: Equatable {

    case idle

    /// Для отображения спиннера:
    case loading(isFirstPage: Bool)

    case loaded(items: [NewsItem], canLoadMore: Bool)

    /// Ошибка при запросе
    case error(message: String, canRetry: Bool)
}
