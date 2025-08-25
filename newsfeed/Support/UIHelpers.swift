//
//  UIHelpers.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 20.08.2025.
//

import UIKit

enum UIHelpers {
    static let dateDMRuFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "d MMMM"
        return df
    }()

    static func dateDMRu(_ date: Date?) -> String? {
        guard let date else { return nil }
        return dateDMRuFormatter.string(from: date)
    }
}
