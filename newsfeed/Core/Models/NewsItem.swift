//
//  NewsItem.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 20.08.2025.
//

import Foundation

struct NewsItem: Hashable {
    let id: Int?
    let title: String?
    let description: String?
    let publishedAt: Date?
    let url: URL?
    let fullUrl: URL?
    let imageURL: URL?
    let category: String?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(url)
    }
    static func == (lhs: NewsItem, rhs: NewsItem) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.url == rhs.url
    }
}
