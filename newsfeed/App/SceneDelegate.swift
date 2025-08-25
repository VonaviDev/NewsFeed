//
//  SceneDelegate.swift
//  newsfeed
//
//  Created by Stanislav Ivanov on 23.08.2025.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let ws = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: ws)
        window.rootViewController = makeRootController()
        window.makeKeyAndVisible()
        self.window = window
    }
    
    enum ControllerFactory {
        @MainActor static func makeFeedController() -> UIViewController {
            let api = APIClient()
            let repo = NewsRepository(client: api)
            let vm = FeedViewModel(repository: repo)
            let feedVC = FeedViewController(viewModel: vm)
            
            let nav = UINavigationController(rootViewController: feedVC)
            nav.navigationBar.prefersLargeTitles = true
            return nav
        }
    }

    private func makeRootController() -> UIViewController {
        return ControllerFactory.makeFeedController()
    }
}
