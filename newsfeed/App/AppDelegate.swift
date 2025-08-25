//
//  AppDelegate.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 23.08.2025.
//

import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]?
    ) -> Bool {
        configureURLCache()
        return true
    }
}

// MARK: - Private
extension AppDelegate {
    /// Параметры кэша
    fileprivate func configureURLCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,  // 50 мб на память
            diskCapacity: 100 * 1024 * 1024,  // 100 мб на диск
            diskPath: "AutodocURLCache"
        )
    }
}
