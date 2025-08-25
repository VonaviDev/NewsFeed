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
    static var baseAPI: URL = {
        guard let url = URL(string: "https://webapi.autodoc.ru") else {
            fatalError("Invalid API base URL")
        }
        return url
    }()
    
    /// Адрес для web‑ссылок
    static var baseWeb: URL = {
        guard let url = URL(string: "https://www.autodoc.ru/") else {
            fatalError("Invalid web base URL")
        }
        return url
    }()
}

extension NewsEndpoint {
    var url: URL {
        switch self {
        case .page(let page, let pageSize):
            var u = APIConfig.baseAPI
            u.append(path: "/api/news/\(page)/\(pageSize)")
            return u
        }
    }
}
