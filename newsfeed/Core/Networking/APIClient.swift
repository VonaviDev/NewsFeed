//
//  APIClient.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 20.08.2025.
//

import Foundation

protocol APIClientProtocol: AnyObject {
    func get<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T
}

final class APIClient: APIClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session

        let d = JSONDecoder()
        self.decoder = d
    }

    func get<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.cachePolicy = .useProtocolCachePolicy
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(T.self, from: data)
    }
    
    func get<T: Decodable>(_ url: URL) async throws -> T {
        try await get(T.self, from: url)
    }
}
