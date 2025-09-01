//
//  NewsRepository.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 20.08.2025.
//

import Foundation

struct NewsPage {
    let items: [NewsItem]
    let totalCount: Int
}

protocol NewsRepositoryProtocol: AnyObject {
    func fetchPage(page: Int, pageSize: Int) async throws -> NewsPage
}

final class NewsRepository: NewsRepositoryProtocol {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchPage(page: Int, pageSize: Int) async throws -> NewsPage {
        guard let url = NewsEndpoint.page(page, pageSize: pageSize).url else {
            throw URLError(.badURL)
        }
        let dto: NewsPageDTO = try await client.get(url)
        let items = (dto.news ?? []).compactMap { Self.map($0) }
        let total = dto.totalCount ?? 0
        return NewsPage(items: items, totalCount: total)
    }

    // MARK: - Mapping

    private static let isoWithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoNoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let rfc3339: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return f
    }()

    private static func parseDate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        if let d = isoWithFractional.date(from: s) { return d }
        if let d = isoNoFractional.date(from: s) { return d }
        if let d = rfc3339.date(from: s) { return d }
        return nil
    }

    private static func map(_ d: NewsDTO) -> NewsItem? {
        let published = parseDate(d.publishedDate)

        let url = d.url.flatMap {
            URL(string: $0, relativeTo: APIConfig.baseWeb)?.absoluteURL
        }
        let fullUrl = d.fullUrl.flatMap {
            URL(string: $0, relativeTo: APIConfig.baseWeb)?.absoluteURL
        }
        let imageURL = d.titleImageUrl.flatMap {
            URL(string: $0, relativeTo: APIConfig.baseWeb)?.absoluteURL
        }

        return NewsItem(
            id: d.id,
            title: d.title,
            description: d.description,
            publishedAt: published,
            url: url ?? APIConfig.baseWeb,
            fullUrl: fullUrl,
            imageURL: imageURL,
            category: normalized(d.categoryType)
        )
    }

    private static func normalized(_ s: String?) -> String? {
        guard let s else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
