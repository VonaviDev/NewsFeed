//
//  Endpoints.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 20.08.2025.
//

import Foundation

enum NewsEndpoint {
    case page(_ page: Int, pageSize: Int)
}

struct APIConfig {
    /// Базовый адрес API
    static var baseAPI: URL? = {
        let url = URL(string: "https://webapi.autodoc.ru")
        return url
    }()
    
    /// Адрес для web‑ссылок
    static var baseWeb: URL? = {
        let url = URL(string: "https://www.autodoc.ru/")
        return url
    }()
}

extension NewsEndpoint {
    var url: URL? {
        switch self {
        case .page(let page, let pageSize):
            var url = APIConfig.baseAPI
            url?.append(path: "/api/news/\(page)/\(pageSize)")
            return url
        }
    }
}
