//
//  NewsDTO.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 20.08.2025.
//

import Foundation

struct NewsDTO: Codable {
    let id: Int?
    let title: String?
    let description: String?
    let publishedDate: String?
    let url: String?
    let fullUrl: String?
    let titleImageUrl: String?
    let categoryType: String?
}

struct NewsPageDTO: Codable {
    let news: [NewsDTO]?
    let totalCount: Int?
}
